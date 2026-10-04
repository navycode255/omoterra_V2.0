"""Opening stock and unknown buying costs (build plan M1.3, audit F02).

Decision D3: the finance owner gives a value to stock Omoterra held before
the system existed. An admin records it as **opening stock**: what, how
many, the value (per unit or in total), the date it is valued as of, the
evidence behind the value and who gave it. It is a receipt with a value and
**no payable**: it was paid for before records began, so no supplier is owed.
Sale lines then sell from it at that cost, so their margin is known.

A sale line's buying cost is `known`, `free` or `unknown`
(`sale_items.cost_state`). Unknown is not zero (rule R5): the line counts
for nothing in cost of goods and every period containing it is shown as
"Provisional: buying costs incomplete". An admin gives such a line a cost
later, with a reason, by linking it to opening stock, by entering an
evidenced cost, or by recording that it cost nothing (free). Each writes a
`financial_adjustments` row with the line before and after (decision D4).
Approval alone never turns an unknown cost into a known one (R7): only a
value does.

On hand = quantity - active sale lines - goods not recovered from a
cancelled or edited sale (current state; dated checks arrive with M2.2).
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import and_, func, select

from . import auth, contracts as c, models as m, paging, services as s
from .db import database
from .i18n import fail
from .paging import Paging, Spec

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def cost_state_for(unit_cost, free=False):
    """The state a line's cost is in: none is unknown, a positive cost is
    known, and 0 is free only when an admin approved it (`free`)."""
    if unit_cost is None:
        return 'unknown'
    if unit_cost > 0:
        return 'known'
    return 'free' if free else 'unknown'


# ---- stock ------------------------------------------------------------------

def stock(db, opening_id):
    """Quantity, sold (active sales), not recovered, on hand."""
    row = db.get(m.OpeningStock, opening_id)
    sold = db.scalar(select(func.coalesce(func.sum(m.SaleItem.quantity), 0)).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.SaleItem.opening_stock_id == opening_id, m.Sale.status == 'active')) or ZERO
    lost = db.scalar(select(func.coalesce(func.sum(m.OpeningStockMovement.quantity), 0)).where(
        m.OpeningStockMovement.opening_stock_id == opening_id, m.OpeningStockMovement.kind == 'not_recovered')) or ZERO
    quantity = row.quantity if row and row.cancelled_at is None else ZERO
    return {'quantity': quantity, 'sold': sold, 'not_recovered': lost, 'on_hand': quantity - sold - lost}


def take_opening_stock(db, opening_id, quantity, taken=ZERO):
    """Lock an opening stock entry and check `quantity` more can be sold
    from it (`taken`: already taken by earlier lines of the same request)."""
    row = db.scalar(select(m.OpeningStock).where(m.OpeningStock.id == opening_id,
        m.OpeningStock.cancelled_at.is_(None)).with_for_update())
    if not row:
        fail('err.opening_stock_not_found', 404)
    on_hand = stock(db, row.id)['on_hand'] - taken
    if quantity > on_hand:
        fail('err.not_enough_opening_stock', 422, available=s.quantity(max(on_hand, ZERO)))
    return row


def _operator(db, id):
    from .finance import _operator_name
    return _operator_name(db, id)


FIELDS = ('id', 'receipt_number', 'category', 'description', 'unit', 'quantity', 'unit_cost', 'amount', 'as_of',
          'evidence', 'valued_by', 'created_at', 'cancelled_at', 'cancel_reason')


def opening_view(db, row, detail=False):
    view = {**{k: getattr(row, k) for k in FIELDS}, **stock(db, row.id), 'kind': 'opening_stock',
            'label': 'Opening stock', 'recorded_by': _operator(db, row.recorded_by),
            'cancelled_by': _operator(db, row.cancelled_by)}
    view['value_on_hand'] = s.money(view['on_hand'] * row.unit_cost) if view['on_hand'] > 0 else ZERO
    if detail:
        lines = db.execute(select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
            .where(m.SaleItem.opening_stock_id == row.id).order_by(m.Sale.sold_on.desc(), m.Sale.sale_number)).all()
        view['sales'] = [{'sale_id': sale.id, 'sale_number': sale.sale_number, 'sold_on': sale.sold_on,
            'status': sale.status, 'quantity': item.quantity, 'unit': item.unit, 'revenue': item.subtotal,
            'cost': item.cost_total} for item, sale in lines]
        view['movements'] = [{k: getattr(move, k) for k in ('id', 'kind', 'quantity', 'occurred_on', 'unit_cost',
            'sale_id', 'reason', 'note', 'created_at')} for move in db.scalars(select(m.OpeningStockMovement)
            .where(m.OpeningStockMovement.opening_stock_id == row.id).order_by(m.OpeningStockMovement.created_at))]
        view['adjustments'] = [{k: getattr(a, k) for k in ('id', 'kind', 'reason', 'before', 'after', 'created_at')}
            | {'recorded_by': _operator(db, a.recorded_by)} for a in db.scalars(select(m.FinancialAdjustment)
            .where(m.FinancialAdjustment.entity_id == row.id).order_by(m.FinancialAdjustment.created_at))]
    return view


# ---- opening stock ------------------------------------------------------------

LIVE = m.OpeningStock.cancelled_at.is_(None)
OPENING = Spec(m.OpeningStock, (m.OpeningStock.as_of.desc(), m.OpeningStock.created_at.desc(), m.OpeningStock.id.desc()),
    lambda q: paging.matches(q, m.OpeningStock.receipt_number, m.OpeningStock.description, m.OpeningStock.category,
        m.OpeningStock.valued_by, m.OpeningStock.evidence),
    tabs={'active': LIVE, 'cancelled': m.OpeningStock.cancelled_at.is_not(None)})


@router.post('/opening-stock', status_code=201)
def record_opening_stock(data: c.OpeningStockInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                         db=Depends(database)):
    """Record stock held before the system at the value the finance owner
    gives it (D3). Admins only. Opens no supplier debt."""
    key, fingerprint, prior = s.replay(db, operator.id, 'opening-stock', idempotency_key, data.model_dump())
    if prior:
        return _result(opening_view(db, db.get(m.OpeningStock, prior), True), 201)
    from .finance import _whole
    _whole(data.unit, data.quantity)
    if data.unit_cost is not None:
        unit_cost, amount = data.unit_cost, s.money(data.quantity * data.unit_cost)
    else:
        unit_cost, amount = s.money(data.total_value / data.quantity), data.total_value
    if unit_cost <= 0:
        fail('err.opening_value_needed', 422)
    id = m.identifier()
    row = m.OpeningStock(id=id, receipt_number='OS-' + id.replace('-', '')[:8].upper(), category=data.category or '',
        description=data.description, unit=data.unit, quantity=data.quantity, unit_cost=unit_cost, amount=amount,
        as_of=data.as_of, evidence=data.evidence, valued_by=data.valued_by, recorded_by=operator.id)
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return _result(opening_view(db, row, True), 201)


@router.get('/opening-stock')
def opening_stock_list(params: Paging = Depends(), operator=Depends(auth.ops), db=Depends(database)):
    body = paging.page(db, OPENING, params, lambda row: opening_view(db, row))
    live = db.scalars(select(m.OpeningStock).where(LIVE)).all()
    on_hand = [opening_view(db, row) for row in live]
    body['summary'] = {'entries': len(live), 'value': sum((row.amount for row in live), ZERO),
        'value_on_hand': sum((row['value_on_hand'] for row in on_hand), ZERO),
        'with_stock': sum(1 for row in on_hand if row['on_hand'] > 0)}
    return _result(body)


@router.get('/opening-stock/available')
def opening_stock_available(operator=Depends(auth.ops), db=Depends(database)):
    """Opening stock with something on hand, for the sale form."""
    rows = db.scalars(select(m.OpeningStock).where(LIVE).order_by(m.OpeningStock.as_of, m.OpeningStock.created_at))
    return _result([view for view in (opening_view(db, row) for row in rows) if view['on_hand'] > 0])


@router.get('/opening-stock/{id}')
def opening_stock_detail(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.OpeningStock, id)
    if not row:
        fail('err.opening_stock_not_found', 404)
    return _result(opening_view(db, row, True))


@router.post('/opening-stock/{id}/cancel')
def cancel_opening_stock(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                         db=Depends(database)):
    """An entry made by mistake: cancelled with a reason, only while nothing
    has been sold from it (a sale cancelled since does not count)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'opening-stock-cancel', idempotency_key, {'id': id, **data.model_dump()})
    row = db.scalar(select(m.OpeningStock).where(m.OpeningStock.id == id).with_for_update())
    if not row:
        fail('err.opening_stock_not_found', 404)
    if not prior:
        if row.cancelled_at is not None:
            fail('err.opening_stock_already_cancelled')
        state = stock(db, row.id)
        if state['sold'] > 0 or state['not_recovered'] > 0:
            fail('err.opening_stock_has_sales')
        before = {k: _plain(getattr(row, k)) for k in ('quantity', 'unit_cost', 'amount', 'as_of', 'cancelled_at')}
        row.cancelled_at, row.cancelled_by, row.cancel_reason = m.now(), operator.id, data.reason
        db.flush()
        db.add(m.FinancialAdjustment(kind='opening_stock_cancelled', entity_type='opening_stock', entity_id=row.id,
            reason=data.reason, before=before, after={**before, 'cancelled_at': _plain(row.cancelled_at)},
            linked_ids={'receipt_number': row.receipt_number}, recorded_by=operator.id))
        db.flush()
        s.remember(db, key, fingerprint, row.id)
    return _result(opening_view(db, row, True))


def _plain(value):
    from .finance import _plain as plain
    return plain(value)


# ---- unknown buying costs -------------------------------------------------------

UNKNOWN = and_(m.SaleItem.cost_state == 'unknown', m.Sale.status == 'active')


@router.get('/finance/unknown-costs')
def unknown_costs(q: str = Query('', max_length=100), page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=100),
                  start: Optional[date] = None, end: Optional[date] = None,
                  operator=Depends(auth.ops), db=Depends(database)):
    """Active sale lines whose buying cost is unknown (R5), oldest first:
    what keeps a period provisional, with the sales and revenue affected."""
    query = select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id).where(UNKNOWN)
    if start:
        query = query.where(m.Sale.sold_on >= start)
    if end:
        query = query.where(m.Sale.sold_on <= end)
    if q.strip():
        query = query.where(paging.matches(q.strip(), m.Sale.sale_number, m.Sale.buyer_name, m.SaleItem.description,
            m.SaleItem.category))
    rows = db.execute(query.order_by(m.Sale.sold_on, m.Sale.sale_number, m.SaleItem.position)).all()
    first = (page - 1) * page_size
    items = [{'sale_item_id': item.id, 'sale_id': sale.id, 'sale_number': sale.sale_number, 'sold_on': sale.sold_on,
        'buyer_name': sale.buyer_name, 'position': item.position, 'category': item.category,
        'description': item.description, 'unit': item.unit, 'quantity': item.quantity, 'revenue': item.subtotal,
        'supplier_name': item.supplier_name, 'href': f'/sales/{sale.id}'} for item, sale in rows[first:first + page_size]]
    return _result({'items': items, 'total': len(rows), 'page': page, 'page_size': page_size, 'actionable': len(rows),
        'summary': {'lines': len(rows), 'sales': len({sale.id for _item, sale in rows}),
                    'revenue': sum((item.subtotal for item, _sale in rows), ZERO)}})


@router.post('/sales/{sale_id}/items/{item_id}/cost')
def resolve_cost(sale_id: str, item_id: str, data: c.CostResolutionInput, idempotency_key: str = Header(),
                 operator=Depends(auth.ops_admin), db=Depends(database)):
    """Give an unknown-cost line its cost (admins, with a reason): from
    opening stock, an evidenced cost, or free. Opens no supplier debt.
    Writes a financial adjustment with the line before and after."""
    from .finance import ITEM_FIELDS, _receipt_line, _snapshot, sale_view
    key, fingerprint, prior = s.replay(db, operator.id, 'cost-resolution', idempotency_key,
        {'sale_id': sale_id, 'item_id': item_id, **data.model_dump()})
    sale = db.scalar(select(m.Sale).where(m.Sale.id == sale_id).with_for_update())
    if not sale:
        fail('err.sale_not_found', 404)
    if not prior:
        if sale.status != 'active':
            fail('err.cancelled_sale_cannot_be_edited')
        items = db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == sale.id).order_by(m.SaleItem.position)
            .with_for_update()).all()
        item = next((row for row in items if row.id == item_id), None)
        if item is None:
            fail('err.sale_item_not_found', 404)
        if item.cost_state != 'unknown':
            fail('err.cost_already_known')
        fields = (*ITEM_FIELDS, 'cost_state', 'opening_stock_id')
        before = {'item': _snapshot(item, fields), 'sale_cost_amount': str(sale.cost_amount)}
        linked = {'how': data.how, 'sale_id': sale.id, 'item_id': item.id}
        if data.how == 'opening_stock':
            if item.supplier_id or item.supplier_name or item.location_allocation_id:
                fail('err.opening_stock_cost_comes_from_entry')
            row = take_opening_stock(db, data.opening_stock_id, item.quantity)
            _receipt_line(item, row.unit, row.category)
            item.opening_stock_id, item.unit_cost = row.id, row.unit_cost
            linked['opening_stock_id'] = row.id
        elif data.how == 'cost':
            item.unit_cost = data.unit_cost
        else:
            item.unit_cost = Decimal('0.00')
        item.cost_total = s.money(item.quantity * item.unit_cost)
        item.cost_state = 'free' if data.how == 'free' else 'known'
        sale.cost_amount = sum((row.cost_total or ZERO for row in items if row.cost_state != 'unknown'), ZERO)
        db.flush()
        after = {'item': _snapshot(item, fields), 'sale_cost_amount': str(sale.cost_amount)}
        if data.evidence:
            linked['evidence'] = data.evidence
        db.add(m.FinancialAdjustment(kind='cost_resolved', entity_type='sale_item', entity_id=item.id, sale_id=sale.id,
            reason=data.reason, before=before, after=after, linked_ids=linked, recorded_by=operator.id))
        db.flush()
        s.remember(db, key, fingerprint, sale.id)
    return _result(sale_view(db, sale, True))
