"""Received lots and their dated movements (build plan M2.1, audit F09).

A lot is stock Omoterra physically holds, at one cost:

- a delivery note (`supplier_collections`), received from a supplier batch;
- an LPO line (`lpo_lines`), received on one or more LPO receipts;
- an opening stock entry (`opening_stock`), held before the system (D3).

A supplier's registered batch is their declaration, never a lot: it is
not Omoterra's stock and not guaranteed future supply.

Movements are read from the records that already hold each physical event
(rule R2), never copied into a second table, so no screen can disagree
with them. Every movement has a date, a signed quantity (`delta`) and the
record it comes from. On hand on any date is the sum of the deltas up to
and including that date; on hand now is the sum of all of them.

Kinds:

- received: accepted on a delivery note or LPO receipt, or opening stock;
- receipt_correction: a delivery note corrected because it was never
  delivered (dated the day it was corrected);
- sold: what a sale took, on the sale date: its active quantity plus any
  of it later returned by the buyer;
- buyer_return_accepted: back on hand, on the day it was accepted back;
- sale_cancelled_never_left: history only (delta 0): the goods never left;
- not_recovered: left with a sale and never recovered, on the sale date;
- mortality / lost: died, or lost another way (sick, stolen, spoiled,
  other), on the day recorded;
- returned_to_supplier: left for the supplier (the payable falls only by a
  supplier credit note);
- to_location / from_location: moved to a kitchen, and returned from it;
- count_adjustment: a physical count's difference from the records
  (`lot_adjustments`, admin, with evidence); opening stock losses are
  recorded there too.

Rule R8: a change is accepted only if on hand stays at or above zero at the
end of every day from the change onward (`first_negative`).

Every change that takes or restores stock runs through StockGuard (M2.2):
replayed by date, refused if any day would end below zero, and a record
dated more than LATE_ENTRY_DAYS back needs an admin and a reason.

Known limits (see the build plan):
- On LPO stock, a cancelled sale whose goods never left or were returned
  records no event; the sale simply stops counting. "Not recovered" is an
  LPO stock loss dated the day it was recorded.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import func, select

from . import auth, contracts as c, models as m, services as s
from .db import database
from .i18n import fail

router = APIRouter(prefix='/api/v1')

ZERO = Decimal('0')
LOT_TABLES = ('supplier_collections', 'lpo_lines', 'opening_stock')
# In this order on one day: a count comes last, after the day's events.
KINDS = ('received', 'receipt_correction', 'sold', 'buyer_return_accepted', 'sale_cancelled_never_left',
    'not_recovered', 'mortality', 'lost', 'returned_to_supplier', 'to_location', 'from_location', 'count_adjustment')
# Kinds counted as stock lost in Profit.
LOSS_KINDS = ('not_recovered', 'mortality', 'lost')


QUANTITY = Decimal('0.001')


def _move(table, lot_id, kind, on, delta, source_table, source_id, *, quantity=None, unit_cost=None,
          sale_id=None, note='', by=None, at=None):
    # Quantities as the database stores them (3 places), also for records
    # still in memory after a flush.
    delta = Decimal(delta).quantize(QUANTITY)
    return {'lot_table': table, 'lot_id': lot_id, 'kind': kind, 'date': on, 'delta': delta, 'at': at,
            'quantity': abs(delta) if quantity is None else Decimal(quantity).quantize(QUANTITY), 'unit_cost': unit_cost,
            'source_table': source_table, 'source_id': source_id, 'sale_id': sale_id, 'note': note, 'by': by}


def _within(column, ids):
    return [] if ids is None else [column.in_(list(ids))]


def _sales(db, column, ids):
    """Active sale lines taking from these lots: (lot id, sale, quantity)."""
    rows = db.execute(select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(column.is_not(None), m.Sale.status == 'active', *_within(column, ids))).all()
    return [(getattr(item, column.key), sale, item.quantity) for item, sale in rows]


def _sale_outcomes(db, sale_rows, outcomes, table, cost_of):
    """Sold movements (active quantity plus what the buyer later returned),
    and the outcome of what a sale no longer sells (never left, returned,
    not recovered). `outcomes`: (lot id, kind, quantity, occurred_on,
    sale_id, row id, note, by)."""
    sold = defaultdict(lambda: ZERO)
    sales = {}
    for lot_id, sale, quantity in sale_rows:
        sold[(lot_id, sale.id)] += quantity
        sales[sale.id] = sale
    missing = {o[4] for o in outcomes if o[4] and o[4] not in sales}
    if missing:
        sales.update({row.id: row for row in db.scalars(select(m.Sale).where(m.Sale.id.in_(missing)))})
    moves = []
    for lot_id, kind, quantity, occurred_on, sale_id, row_id, note, by, at in outcomes:
        sale = sales.get(sale_id)
        sold_on = sale.sold_on if sale else occurred_on
        source = f'{table}_movements' if table != 'supplier_collections' else 'collection_movements'
        if kind == 'buyer_return_accepted':
            if sale:
                sold[(lot_id, sale_id)] += quantity
            moves.append(_move(table, lot_id, kind, occurred_on, quantity, source, row_id, sale_id=sale_id,
                unit_cost=cost_of(lot_id), note=note, by=by, at=at))
        elif kind == 'not_recovered':
            moves.append(_move(table, lot_id, kind, sold_on, -quantity, source, row_id, sale_id=sale_id,
                unit_cost=cost_of(lot_id), note=note, by=by, at=at))
        elif kind == 'never_left':
            moves.append(_move(table, lot_id, 'sale_cancelled_never_left', occurred_on, ZERO, source, row_id,
                quantity=quantity, sale_id=sale_id, unit_cost=cost_of(lot_id), note=note, by=by, at=at))
    for (lot_id, sale_id), quantity in sold.items():
        sale = sales[sale_id]
        moves.append(_move(table, lot_id, 'sold', sale.sold_on, -quantity, 'sales', sale_id, sale_id=sale_id,
            unit_cost=cost_of(lot_id), note=sale.sale_number, at=sale.created_at))
    return moves


def _locations(db, column, ids, table, cost_of):
    allocations = db.scalars(select(m.LocationAllocation).where(column.is_not(None), *_within(column, ids))).all()
    if not allocations:
        return []
    lot_of = {row.id: getattr(row, column.key) for row in allocations}
    moves = [_move(table, lot_of[row.id], 'to_location', row.allocated_on, -row.quantity, 'location_allocations',
        row.id, unit_cost=row.unit_cost, note=row.description, by=row.created_by, at=row.created_at) for row in allocations]
    for event in db.scalars(select(m.LocationStockEvent).where(m.LocationStockEvent.allocation_id.in_(list(lot_of)),
            m.LocationStockEvent.kind == 'returned')):
        moves.append(_move(table, lot_of[event.allocation_id], 'from_location', event.occurred_on, event.quantity,
            'location_stock_events', event.id, unit_cost=cost_of(lot_of[event.allocation_id]), note=event.note,
            by=event.created_by, at=event.created_at))
    return moves


def _collections(db, ids=None):
    notes = {row.id: row for row in db.scalars(select(m.SupplierCollection).where(*_within(m.SupplierCollection.id, ids)))}
    if not notes:
        return []
    cost_of = lambda id: notes[id].unit_cost
    table = 'supplier_collections'
    events = db.scalars(select(m.CollectionMovement).where(m.CollectionMovement.collection_id.in_(list(notes)))).all()
    corrected = defaultdict(lambda: ZERO)
    moves, outcomes = [], []
    for row in events:
        if row.kind == 'receipt_correction':
            corrected[row.collection_id] += row.quantity
            moves.append(_move(table, row.collection_id, row.kind, row.occurred_on, -row.quantity,
                'collection_movements', row.id, unit_cost=row.unit_cost, note=row.reason, by=row.recorded_by, at=row.created_at))
        elif row.kind == 'returned_to_supplier':
            moves.append(_move(table, row.collection_id, row.kind, row.occurred_on, -row.quantity,
                'collection_movements', row.id, unit_cost=row.unit_cost, note=row.reason, by=row.recorded_by, at=row.created_at))
        elif row.kind == 'lost':
            if row.cancelled_at is None:
                moves.append(_move(table, row.collection_id, 'mortality' if row.loss_reason == 'died' else 'lost',
                    row.occurred_on, -row.quantity, 'collection_movements', row.id, unit_cost=row.unit_cost,
                    note=row.note or row.reason, by=row.recorded_by, at=row.created_at))
        else:
            outcomes.append((row.collection_id, row.kind, row.quantity, row.occurred_on, row.sale_id, row.id,
                row.note or row.reason, row.recorded_by, row.created_at))
    for note in notes.values():
        # A note corrected to zero is cancelled with its accepted quantity
        # left as it was; any other cancelled note never counted.
        received = (ZERO if note.cancelled_at else note.accepted_quantity) + corrected[note.id]
        if received > 0:
            moves.append(_move(table, note.id, 'received', note.received_on, received, 'supplier_collections', note.id,
                unit_cost=note.unit_cost, note=note.collection_number, by=note.confirmed_by or note.recorded_by,
                at=note.created_at))
    moves += _sale_outcomes(db, _sales(db, m.SaleItem.supplier_collection_id, notes), outcomes, table, cost_of)
    moves += _locations(db, m.LocationAllocation.supplier_collection_id, notes, table, cost_of)
    return moves


def _lpo_lines(db, ids=None):
    receipts = db.execute(select(m.LpoReceiptLine, m.LpoReceipt).join(m.LpoReceipt, m.LpoReceipt.id == m.LpoReceiptLine.receipt_id)
        .where(m.LpoReceipt.cancelled_at.is_(None), *_within(m.LpoReceiptLine.lpo_line_id, ids))).all()
    # Every line ever received on, cancelled receipts included (a sale or
    # loss may still name it).
    wanted = select(m.LpoReceiptLine.lpo_line_id) if ids is None else list(ids)
    lines = {row.id: row for row in db.scalars(select(m.LpoLine).where(m.LpoLine.id.in_(wanted)))}
    if not lines:
        return []
    table = 'lpo_lines'
    cost_of = lambda id: lines[id].unit_price
    moves = [_move(table, line.lpo_line_id, 'received', receipt.received_on, line.accepted_quantity, 'lpo_receipts',
        receipt.id, unit_cost=line.unit_price, note=receipt.notes, by=receipt.recorded_by, at=receipt.created_at)
        for line, receipt in receipts if line.accepted_quantity > 0]
    for loss in db.scalars(select(m.StockLoss).where(m.StockLoss.lpo_line_id.in_(list(lines)), m.StockLoss.cancelled_at.is_(None))):
        moves.append(_move(table, loss.lpo_line_id, 'mortality' if loss.reason == 'died' else 'lost', loss.lost_on,
            -loss.quantity, 'stock_losses', loss.id, unit_cost=loss.unit_cost, note=loss.note, by=loss.recorded_by,
            at=loss.created_at))
    moves += _sale_outcomes(db, _sales(db, m.SaleItem.lpo_line_id, lines), [], table, cost_of)
    moves += _locations(db, m.LocationAllocation.lpo_line_id, lines, table, cost_of)
    return moves


def _opening(db, ids=None):
    entries = {row.id: row for row in db.scalars(select(m.OpeningStock).where(*_within(m.OpeningStock.id, ids)))}
    if not entries:
        return []
    table = 'opening_stock'
    cost_of = lambda id: entries[id].unit_cost
    moves = [_move(table, row.id, 'received', row.as_of, row.quantity, 'opening_stock', row.id,
        unit_cost=row.unit_cost, note=row.receipt_number, by=row.recorded_by, at=row.created_at)
        for row in entries.values() if row.cancelled_at is None]
    outcomes = [(row.opening_stock_id, row.kind, row.quantity, row.occurred_on, row.sale_id, row.id,
        row.note or row.reason, row.recorded_by, row.created_at) for row in db.scalars(select(m.OpeningStockMovement)
        .where(m.OpeningStockMovement.opening_stock_id.in_(list(entries))))]
    moves += _sale_outcomes(db, _sales(db, m.SaleItem.opening_stock_id, entries), outcomes, table, cost_of)
    return moves


def _adjustments(db, table, ids=None):
    rows = db.scalars(select(m.LotAdjustment).where(m.LotAdjustment.lot_table == table,
        m.LotAdjustment.cancelled_at.is_(None), *_within(m.LotAdjustment.lot_id, ids))).all()
    moves = []
    for row in rows:
        if row.kind == 'count':
            moves.append(_move(table, row.lot_id, 'count_adjustment', row.occurred_on, row.quantity, 'lot_adjustments',
                row.id, quantity=abs(row.quantity), unit_cost=row.unit_cost, note=row.reason, by=row.recorded_by,
                at=row.created_at))
        else:
            moves.append(_move(table, row.lot_id, 'mortality' if row.loss_reason == 'died' else 'lost', row.occurred_on,
                -row.quantity, 'lot_adjustments', row.id, unit_cost=row.unit_cost, note=row.reason, by=row.recorded_by,
                at=row.created_at))
    return moves


READERS = {'supplier_collections': _collections, 'lpo_lines': _lpo_lines, 'opening_stock': _opening}
ORDER = {kind: n for n, kind in enumerate(KINDS)}
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def movements(db, table=None, ids=None):
    """Every movement of the given lots (all lots when `table` is None),
    oldest first; on one day, receipts come before what leaves, then in
    the order they were recorded."""
    tables = LOT_TABLES if table is None else (table,)
    rows = [row for name in tables for row in (*READERS[name](db, ids), *_adjustments(db, name, ids))]
    return sorted(rows, key=lambda r: (r['date'], ORDER[r['kind']], r['at'] or EPOCH, r['source_id']))


def on_hand(moves, as_of=None):
    """On hand per lot ((table, id) -> quantity) after the given movements,
    counting only those dated on or before `as_of` when it is given."""
    out = defaultdict(lambda: ZERO)
    for row in moves:
        if as_of is None or row['date'] <= as_of:
            out[(row['lot_table'], row['lot_id'])] += row['delta']
    return dict(out)


def summary(moves, as_of=None):
    """One lot's figures from its movements: received, sold (net of buyer
    returns), lost, not recovered, returned to supplier, corrected, at
    kitchens, and on hand."""
    by = defaultdict(lambda: ZERO)
    for row in moves:
        if as_of is None or row['date'] <= as_of:
            by[row['kind']] += row['delta']
    return {
        'received': by['received'],
        'corrected': -by['receipt_correction'],
        'sold': -by['sold'] - by['buyer_return_accepted'],
        'returned_by_buyers': by['buyer_return_accepted'],
        'not_recovered': -by['not_recovered'],
        'died': -by['mortality'],
        'lost': -by['lost'],
        'returned_to_supplier': -by['returned_to_supplier'],
        'at_locations': -by['to_location'] - by['from_location'],
        'counted': by['count_adjustment'],
        'on_hand': sum(by.values(), ZERO),
    }


def first_negative(moves, since=None):
    """Rule R8: the first day (on or after `since`) on which a lot ends the
    day below zero, as (date, on hand), or None."""
    balance = defaultdict(lambda: ZERO)
    rows = sorted(moves, key=lambda r: r['date'])
    for n, row in enumerate(rows):
        key = (row['lot_table'], row['lot_id'])
        balance[key] += row['delta']
        day_ends = n + 1 == len(rows) or rows[n + 1]['date'] != row['date']
        if day_ends and (since is None or row['date'] >= since):
            negative = [value for value in balance.values() if value < 0]
            if negative:
                return row['date'], negative[0]
    return None


def _day_ends(moves):
    """Each day's closing balance: [(date, on hand at the end of it)]."""
    out, balance = [], ZERO
    for row in sorted(moves, key=lambda r: r['date']):
        balance += row['delta']
        if not out or out[-1][0] != row['date']:
            out.append((row['date'], balance))
        else:
            out[-1] = (row['date'], balance)
    return out


def _closing(days, day):
    """The balance at the end of `day` from a list of day ends."""
    balance = ZERO
    for on, value in days:
        if on > day:
            break
        balance = value
    return balance


LATE_ENTRY_DAYS = 3


def late_entry(operator, on, reason):
    """A stock record dated more than LATE_ENTRY_DAYS ago needs an admin and
    a reason (M2.2). Returns the reason to log, or None when not late."""
    if on is None or (c.business_today() - on).days <= LATE_ENTRY_DAYS:
        return None
    reason = (reason or '').strip()
    if operator.role != 'admin' or len(reason) < 3:
        fail('err.late_entry_needs_admin', 422, days=LATE_ENTRY_DAYS)
    return reason


def log_late(db, reason, table, entity_id, on, operator):
    if reason:
        db.add(m.LateEntry(entity_table=table, entity_id=entity_id, entry_date=on, entered_on=c.business_today(),
            reason=reason, approved_by=operator.id))


class StockGuard:
    """Rule R8 with dates (build plan M2.2). Watch every lot a change
    touches before making it; `check()` then replays each lot's movements
    and refuses the change if any day ends below zero, or further below zero
    than it did before (old records that were already negative never block
    an unrelated change). The lot rows are locked by whoever takes the
    stock, so the replay runs inside the same locked transaction."""

    def __init__(self, db):
        self.db = db
        self.before = {}

    def watch(self, table, lot_id):
        if table in LOT_TABLES and lot_id and (table, lot_id) not in self.before:
            self.before[(table, lot_id)] = movements(self.db, table, [lot_id])
        return self

    def check(self):
        self.db.flush()
        for (table, lot_id), old in self.before.items():
            new = movements(self.db, table, [lot_id])
            old_days, new_days = _day_ends(old), _day_ends(new)
            received = min((r['date'] for r in new if r['kind'] == 'received'), default=None)
            for day in sorted({d for d, _ in old_days} | {d for d, _ in new_days}):
                after = _closing(new_days, day)
                if after < 0 and after < _closing(old_days, day):
                    number = lots(self.db, table, [lot_id]).get((table, lot_id), {}).get('number', '')
                    if received is None or day < received:
                        fail('err.stock_used_before_receipt', 422, lot=number,
                            received=received.isoformat() if received else '—')
                    fail('err.stock_would_go_negative_on', 422, lot=number, date=day.isoformat(),
                        on_hand=s.quantity(after))


def timeline(moves):
    """Movements with the running on-hand balance after each one."""
    balance, out = ZERO, []
    for row in moves:
        balance += row['delta']
        out.append({**row, 'on_hand': balance})
    return out


def lot_summary(db, table, lot_id, as_of=None):
    return summary(movements(db, table, [lot_id]), as_of)


# ---- lots and their views ------------------------------------------------------

def lots(db, table=None, ids=None):
    """What each lot is: (table, id) -> number, product, unit, unit cost,
    received date, supplier and where staff open it."""
    out = {}
    if table in (None, 'supplier_collections'):
        rows = db.execute(select(m.SupplierCollection, m.SupplierBatch).join(m.SupplierBatch,
            m.SupplierBatch.id == m.SupplierCollection.batch_id).where(*_within(m.SupplierCollection.id, ids))).all()
        names = _names(db, {note.supplier_id for note, _batch in rows})
        for note, batch in rows:
            out[('supplier_collections', note.id)] = {'number': note.collection_number, 'category': batch.category,
                'description': batch.category.replace('_', ' '), 'unit': c.UNITS.get(batch.category, 'unit'),
                'unit_cost': note.unit_cost, 'received_on': note.received_on, 'supplier_id': note.supplier_id,
                'supplier_name': names.get(note.supplier_id, 'Supplier'), 'batch_id': note.batch_id,
                'href': f'/supplier-collections/{note.id}'}
    if table in (None, 'lpo_lines'):
        wanted = select(m.LpoReceiptLine.lpo_line_id) if ids is None else list(ids)
        rows = db.execute(select(m.LpoLine, m.Lpo).join(m.Lpo, m.Lpo.id == m.LpoLine.lpo_id)
            .where(m.LpoLine.id.in_(wanted))).all()
        names = _names(db, {lpo.supplier_id for _line, lpo in rows})
        first = dict(db.execute(select(m.LpoReceiptLine.lpo_line_id, func.min(m.LpoReceipt.received_on))
            .join(m.LpoReceipt, m.LpoReceipt.id == m.LpoReceiptLine.receipt_id)
            .where(m.LpoReceiptLine.lpo_line_id.in_([line.id for line, _lpo in rows]))
            .group_by(m.LpoReceiptLine.lpo_line_id)).all()) if rows else {}
        for line, lpo in rows:
            out[('lpo_lines', line.id)] = {'number': f'{lpo.lpo_number} line {line.position}', 'category': line.category,
                'description': line.item, 'unit': line.unit, 'unit_cost': line.unit_price,
                'received_on': first.get(line.id), 'supplier_id': lpo.supplier_id,
                'supplier_name': names.get(lpo.supplier_id, 'Supplier'), 'batch_id': None, 'href': f'/lpos/{lpo.id}'}
    if table in (None, 'opening_stock'):
        for row in db.scalars(select(m.OpeningStock).where(*_within(m.OpeningStock.id, ids))):
            out[('opening_stock', row.id)] = {'number': row.receipt_number, 'category': row.category,
                'description': row.description or row.category.replace('_', ' '), 'unit': row.unit,
                'unit_cost': row.unit_cost, 'received_on': row.as_of, 'supplier_id': None,
                'supplier_name': 'Held before the system', 'batch_id': None,
                'href': f'/finance/opening-stock?q={row.receipt_number}'}
    return out


def _names(db, ids):
    ids = [id for id in ids if id]
    if not ids:
        return {}
    rows = db.execute(select(m.User.id, m.User.name, m.SupplierProfile.legal_name)
        .outerjoin(m.SupplierProfile, m.SupplierProfile.user_id == m.User.id).where(m.User.id.in_(ids))).all()
    return {id: legal or name or 'Supplier' for id, name, legal in rows}


def stock_as_of(db, as_of=None, table=None):
    """Every lot that has received stock, with its figures as of the date
    (now when None) and the value on hand at its unit cost."""
    moves = movements(db, table)
    grouped = defaultdict(list)
    for row in moves:
        grouped[(row['lot_table'], row['lot_id'])].append(row)
    info = lots(db, table)
    rows = []
    for key, lot_moves in grouped.items():
        figures = summary(lot_moves, as_of)
        if figures['received'] <= 0 and figures['on_hand'] == 0:
            continue
        lot = info.get(key, {})
        rows.append({'lot_table': key[0], 'lot_id': key[1], **lot, **figures,
            'value_on_hand': s.money(figures['on_hand'] * (lot.get('unit_cost') or ZERO))})
    rows.sort(key=lambda r: (r.get('received_on') is None, r.get('received_on')), reverse=True)
    return {'as_of': as_of, 'rows': rows, 'on_hand_value': sum((r['value_on_hand'] for r in rows), ZERO),
            'lots_with_stock': sum(1 for r in rows if r['on_hand'] > 0)}


@router.get('/ops/lots')
def ops_lots(as_of: Optional[date] = None, table: Optional[str] = None, q: str = Query('', max_length=100),
             show: str = Query('on_hand', pattern='^(on_hand|all)$'), page: int = Query(1, ge=1),
             page_size: int = Query(10, ge=1, le=100), operator=Depends(auth.ops), db=Depends(database)):
    """Received lots with what is on hand as of a date (today by default),
    lots with stock first, 10 to a page; `show=all` includes empty lots."""
    if table is not None and table not in LOT_TABLES:
        fail('err.lot_not_found', 404)
    from .main import result
    stock = stock_as_of(db, as_of or c.business_today(), table)
    rows = stock['rows']
    if show == 'on_hand':
        rows = [r for r in rows if r['on_hand'] != 0]
    needle = q.strip().casefold()
    if needle:
        rows = [r for r in rows if needle in ' '.join(str(r.get(k) or '') for k in
            ('number', 'description', 'category', 'supplier_name')).casefold()]
    start = (page - 1) * page_size
    return result({'items': rows[start:start + page_size], 'total': len(rows), 'page': page, 'page_size': page_size,
        'actionable': 0, 'summary': {'as_of': stock['as_of'], 'on_hand_value': stock['on_hand_value'],
        'lots_with_stock': stock['lots_with_stock'],
        'on_hand': {unit: sum((r['on_hand'] for r in stock['rows'] if r.get('unit') == unit), ZERO)
            for unit in sorted({r.get('unit') for r in stock['rows'] if r['on_hand'] and r.get('unit')})}}})


@router.get('/ops/lots/{table}/{lot_id}')
def ops_lot(table: str, lot_id: str, as_of: Optional[date] = None, operator=Depends(auth.ops), db=Depends(database)):
    """One lot: what it is, its figures as of a date, and every movement
    with the on-hand balance after it."""
    from .main import result
    return result(lot_detail(db, table, lot_id, as_of))


def lot_detail(db, table, lot_id, as_of=None):
    info = lots(db, table, [lot_id]) if table in LOT_TABLES else {}
    if (table, lot_id) not in info:
        fail('err.lot_not_found', 404)
    moves = movements(db, table, [lot_id])
    sale_numbers = dict(db.execute(select(m.Sale.id, m.Sale.sale_number).where(
        m.Sale.id.in_({r['sale_id'] for r in moves if r['sale_id']}))).all()) if any(r['sale_id'] for r in moves) else {}
    people = dict(db.execute(select(m.Operator.id, m.Operator.name).where(
        m.Operator.id.in_({r['by'] for r in moves if r['by']}))).all()) if any(r['by'] for r in moves) else {}
    adjustments = {row.id: row for row in db.scalars(select(m.LotAdjustment).where(
        m.LotAdjustment.lot_table == table, m.LotAdjustment.lot_id == lot_id))}
    return {'lot_table': table, 'lot_id': lot_id, **info[(table, lot_id)],
        'as_of': as_of, **summary(moves, as_of),
        'movements': [{**{k: v for k, v in row.items() if k != 'by'}, 'recorded_by': people.get(row['by'], ''),
            'sale_number': sale_numbers.get(row['sale_id']),
            'counted_quantity': getattr(adjustments.get(row['source_id']), 'counted_quantity', None)
                if row['source_table'] == 'lot_adjustments' else None,
            'evidence': adjustments[row['source_id']].evidence if row['source_table'] == 'lot_adjustments' else None}
            for row in timeline(moves)],
        'cancelled_adjustments': [{'id': row.id, 'kind': row.kind, 'occurred_on': row.occurred_on,
            'quantity': row.quantity, 'reason': row.reason, 'cancel_reason': row.cancel_reason,
            'cancelled_at': row.cancelled_at} for row in adjustments.values() if row.cancelled_at]}


# ---- counts and opening stock losses -------------------------------------------

LOCKS = {'supplier_collections': m.SupplierCollection, 'lpo_lines': m.LpoLine, 'opening_stock': m.OpeningStock}


def _lock(db, table, lot_id):
    """Lock the lot's own record, so two changes to it run one after the
    other, and return its movements."""
    if table not in LOCKS or not db.scalar(select(LOCKS[table].id).where(LOCKS[table].id == lot_id).with_for_update()):
        fail('err.lot_not_found', 404)
    moves = movements(db, table, [lot_id])
    if not any(row['kind'] == 'received' for row in moves):
        fail('err.lot_not_found', 404)
    return moves


def _received_on(moves):
    return min(row['date'] for row in moves if row['kind'] == 'received')


def _never_negative(moves, since):
    """Rule R8: refuse a change that leaves the lot below zero on any day
    from `since` onward."""
    broken = first_negative(moves, since)
    if broken:
        fail('err.stock_would_go_negative', 422, date=broken[0].isoformat(), on_hand=s.quantity(broken[1]))


def _unit_cost(db, table, lot_id):
    return lots(db, table, [lot_id])[(table, lot_id)]['unit_cost']


@router.post('/ops/lots/{table}/{lot_id}/counts', status_code=201)
def record_count(table: str, lot_id: str, data: c.StockCountInput, idempotency_key: str = Header(),
                 operator=Depends(auth.ops_admin), db=Depends(database)):
    """Record a physical count: its difference from what the records expect
    on that day becomes a count adjustment (admin, reason, evidence)."""
    from .main import result
    key, fingerprint, prior = s.replay(db, operator.id, 'lot-count', idempotency_key,
        {'table': table, 'lot_id': lot_id, **data.model_dump()})
    if not prior:
        moves = _lock(db, table, lot_id)
        if data.counted_on < _received_on(moves):
            fail('err.count_before_receipt', 422)
        expected = on_hand(moves, data.counted_on).get((table, lot_id), ZERO)
        difference = data.counted_quantity - expected
        if difference == 0:
            fail('err.count_matches_records', 422, quantity=s.quantity(expected))
        row = m.LotAdjustment(lot_table=table, lot_id=lot_id, kind='count', occurred_on=data.counted_on,
            quantity=difference, counted_quantity=data.counted_quantity, expected_quantity=expected,
            unit_cost=_unit_cost(db, table, lot_id), reason=data.reason.strip(), evidence=data.evidence.strip(),
            recorded_by=operator.id)
        _never_negative([*moves, _move(table, lot_id, 'count_adjustment', data.counted_on, difference, 'lot_adjustments',
            'new')], data.counted_on)
        db.add(row)
        db.flush()
        s.remember(db, key, fingerprint, row.id)
    return result(lot_detail(db, table, lot_id), 201)


@router.post('/ops/lots/opening_stock/{lot_id}/losses', status_code=201)
def record_opening_loss(lot_id: str, data: c.DeliveryLossInput, idempotency_key: str = Header(),
                        operator=Depends(auth.ops), db=Depends(database)):
    """Opening stock that died or was lost: on hand drops from that day and
    its cost counts as stock lost."""
    from .main import result
    key, fingerprint, prior = s.replay(db, operator.id, 'opening-loss', idempotency_key,
        {'lot_id': lot_id, **data.model_dump()})
    if not prior:
        moves = _lock(db, 'opening_stock', lot_id)
        if data.lost_on < _received_on(moves):
            fail('err.loss_before_receipt', 422)
        late = late_entry(operator, data.lost_on, data.late_reason)
        _never_negative([*moves, _move('opening_stock', lot_id, 'lost', data.lost_on, -data.quantity, 'lot_adjustments',
            'new')], data.lost_on)
        row = m.LotAdjustment(lot_table='opening_stock', lot_id=lot_id, kind='lost', occurred_on=data.lost_on,
            quantity=data.quantity, loss_reason=data.reason, unit_cost=_unit_cost(db, 'opening_stock', lot_id),
            reason=data.note.strip(), recorded_by=operator.id)
        db.add(row)
        db.flush()
        log_late(db, late, 'lot_adjustments', row.id, data.lost_on, operator)
        s.remember(db, key, fingerprint, row.id)
    return result(lot_detail(db, 'opening_stock', lot_id), 201)


@router.post('/ops/lot-adjustments/{id}/cancel')
def cancel_adjustment(id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    """Cancel a count or loss recorded by mistake (admin, with a reason).
    The record stays, marked cancelled; refused if stock would go below
    zero on any day from it onward (R8)."""
    from .main import result
    row = db.scalar(select(m.LotAdjustment).where(m.LotAdjustment.id == id).with_for_update())
    if not row:
        fail('err.lot_adjustment_not_found', 404)
    if row.cancelled_at is None:
        moves = _lock(db, row.lot_table, row.lot_id)
        _never_negative([move for move in moves if move['source_id'] != row.id], row.occurred_on)
        row.cancelled_at, row.cancelled_by, row.cancel_reason = m.now(), operator.id, data.reason.strip()
        db.flush()
    return result(lot_detail(db, row.lot_table, row.lot_id))
