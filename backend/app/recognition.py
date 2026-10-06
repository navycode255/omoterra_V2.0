"""Recognition date of app orders (build plan M2.5, audit F07, decision D7).

An app order counts as a sale on the Dar es Salaam business day it was
delivered: `orders.recognized_on`. Revenue and its cost (the order's payouts)
both use that day (reporting.py).

- Set when the order is marked delivered (services.advance).
- Reversed, never rewritten: a delivered order that is reopened (it was not
  really delivered) or returned by the buyer keeps counting in the period it
  was recognised in. An `order_recognition_reversals` row takes the same
  revenue and cost out again on the day of the reversal, so a period already
  reported never changes. A reopened order delivered again is recognised
  again on its new delivery day.
- History (migration 044 and `classify` below, the same rule): a delivered
  order is backfilled from its activity log only when that is unambiguous.
  Otherwise it stays unresolved (rule R6): kept out of every period, listed
  by the exception report and by this command, and dated only with evidence.

    python -m app.recognition --dry-run [--json]
    python -m app.recognition --apply ORDER_ID --on 2026-09-30 \\
        --evidence "Delivery note signed by the buyer" --by "Maternus Joshua"

The dry run changes nothing. --apply dates one unresolved order after you
confirm it by typing its id (or pass --confirm ORDER_ID).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, Header
from pydantic import Field, field_validator
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from . import auth, contracts as c, inventory as inv, models as m, services as s
from .db import database
from .i18n import fail

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')
RECOGNISED = ('delivered', 'completed')
DELIVERED = 'Delivered'
_TIMESTAMP = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}')


# ---- the rule ------------------------------------------------------------------

def _day(value):
    from .reporting import local_day_of
    if not isinstance(value, str) or not _TIMESTAMP.match(value):
        return None
    try:
        at = datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return None
    if at.tzinfo is None:
        return None
    return local_day_of(at)


def classify(order, today=None):
    """(day, reason) from an order's activity log: the day it was delivered,
    or None with why it cannot be told. Same rule as migration 044."""
    from .reporting import local_day_of
    today = today or c.business_today()
    entries = [e for e in (order.activity or []) if isinstance(e, dict) and e.get('label') == DELIVERED]
    if not entries:
        return None, 'no dated "Delivered" entry in its history'
    days = [_day(e.get('at')) for e in entries]
    if any(d is None for d in days):
        return None, 'a "Delivered" entry has no readable time'
    if len(set(days)) > 1:
        return None, 'conflicting "Delivered" entries on ' + ', '.join(sorted({d.isoformat() for d in days}))
    day = days[0]
    created = local_day_of(order.created_at)
    if created and day < created:
        return None, f'delivered {day} before the order was created ({created})'
    if day > today:
        return None, f'delivered {day}, a date in the future'
    return day, ''


def unresolved(db):
    """Delivered app orders with no recognition date, with the reason."""
    rows = db.scalars(select(m.Order).where(m.Order.internal_status.in_(RECOGNISED), m.Order.recognized_on.is_(None))
        .order_by(m.Order.created_at)).all()
    out = []
    for order in rows:
        day, reason = classify(order)
        out.append({'order_id': order.id, 'reference': order.id[:8].upper(), 'status': order.internal_status,
            'created_at': order.created_at, 'amount': order.total_amount,
            'reason': reason or f'history says {day}; not yet dated (run the backfill or --apply)',
            'suggested_on': day})
    return out


def recognise(order, on, note):
    order.recognized_on = on
    order.recognition_note = note


# ---- reversing a delivery --------------------------------------------------------

class ReverseDeliveryInput(c.Input):
    """`reopen`: the order was not really delivered and goes back on the way.
    `return`: the buyer sent the goods back; the order closes as cancelled
    and the goods go back to the supplier's listing (condition in `reason`)."""
    kind: Literal['reopen', 'return']
    reversed_on: date
    reason: str = Field(min_length=3, max_length=500)

    @field_validator('reversed_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)


def _redelivered_note(item_id):
    return f'Delivered again through Omoterra (order item {item_id})'


def _live_stock_sale(db, item):
    """The order item's unreversed stock sale (the first delivery, or a
    delivery after a reopen)."""
    reversed_ = select(m.StockSaleReversal.sale_id)
    return db.scalar(select(m.StockSale).where(
        or_(m.StockSale.order_item_id == item.id, m.StockSale.note == _redelivered_note(item.id)),
        m.StockSale.id.not_in(reversed_)).order_by(m.StockSale.created_at.desc()).limit(1))


def record_delivery_stock(db, listing, item, accepted):
    """The stock sale of a delivery. A second delivery of the same item (after
    a reopen) cannot reuse `order_item_id`, which is unique and append-only,
    so it names the item in its note instead."""
    first = db.scalar(select(m.StockSale.id).where(m.StockSale.order_item_id == item.id))
    db.add(m.StockSale(listing_id=listing.id, supplier_id=listing.supplier_id, source='omoterra', quantity=accepted,
        sold_at=m.now(), order_item_id=None if first else item.id, note=_redelivered_note(item.id) if first else ''))


def delivery_settlement(db, listing, item, accepted):
    """The payout of a delivery: new, or the one cancelled by a reopen made
    pending again (one payout per item and supplier)."""
    row = db.scalar(select(m.Settlement).where(m.Settlement.order_item_id == item.id,
        m.Settlement.supplier_id == listing.supplier_id))
    values = dict(farmer_asking_price_per_unit=item.asking_snapshot, supplier_payout_price_per_unit=item.payout_snapshot,
        commission_amount_per_unit=item.asking_snapshot - item.payout_snapshot, quantity=accepted,
        total_payable=s.money(accepted * item.payout_snapshot))
    if row is None:
        db.add(m.Settlement(supplier_id=listing.supplier_id, order_item_id=item.id, **values))
        return
    if row.status != 'cancelled':
        fail('err.order_payout_already_recorded')
    for key, value in values.items():
        setattr(row, key, value)
    row.status, row.paid_at, row.payment_reference = 'pending', None, None
    row.supplier_confirmation = row.supplier_confirmed_at = None


def reverse_delivery(db, order, data, operator):
    """Take a delivered order back (see the module notes). Refused once a
    payout of the order is paid (the supplier holds that money: settle it
    first), and a return is refused while the buyer has paid anything (no
    refund path for app orders yet)."""
    s.commerce_lock(db)
    if order.internal_status not in RECOGNISED:
        fail('err.order_not_delivered')
    if order.recognized_on is not None and data.reversed_on < order.recognized_on:
        fail('err.reversal_before_delivery', 422, day=order.recognized_on.isoformat())
    items = db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == order.id).with_for_update()).all()
    settlements = db.scalars(select(m.Settlement).where(m.Settlement.order_item_id.in_([i.id for i in items]),
        m.Settlement.status != 'cancelled').with_for_update()).all()
    # Money sent on a payout (an attempt initiated, or debited and not all
    # refunded) is with the supplier: settle it first (M2.7).
    from . import payouts
    sums = payouts.by_settlement(db, [row.id for row in settlements])
    if any(row.status == 'paid' or sums.get(row.id, {}).get('initiated', ZERO) > 0
           or sums.get(row.id, {}).get('debited', ZERO) > sums.get(row.id, {}).get('refunded', ZERO) for row in settlements):
        fail('err.reverse_delivery_payout_paid')
    if data.kind == 'return' and order.payment_status in ('paid', 'partial'):
        fail('err.recorded_payment_requires_manual_refund')
    reversal = m.OrderRecognitionReversal(order_id=order.id, kind=data.kind, recognized_on=order.recognized_on,
        reversed_on=data.reversed_on, revenue=order.total_amount,
        cost=sum((row.total_payable for row in settlements), ZERO), reason=data.reason, recorded_by=operator.id)
    db.add(reversal)
    db.flush()
    for row in settlements:
        row.status = 'cancelled'
    holds = {hold.listing_id: hold for hold in db.scalars(select(m.StockReservation)
        .where(m.StockReservation.order_id == order.id).with_for_update())}
    for item in items:
        listing = db.scalar(select(m.Listing).where(m.Listing.id == item.listing_id).with_for_update())
        inv.ensure_history(db, listing)
        sold = _live_stock_sale(db, item)
        if sold is not None:
            before = inv.balances(listing)
            listing.quantity_sold -= sold.quantity
            db.add(m.StockSaleReversal(sale_id=sold.id, supplier_id=listing.supplier_id,
                reason=f'Order {data.kind}: {data.reason}'[:500]))
            inv.movement(db, listing, 'sale_reversed', before, f'order-item:{item.id}:{data.kind}:{reversal.id}',
                data.reason)
            profile = db.get(m.SupplierProfile, listing.supplier_id)
            if profile and profile.completed_supplies_count > 0:
                profile.completed_supplies_count -= 1
        hold = holds.get(listing.id)
        if data.kind == 'reopen' and hold is not None:
            # Still on its way: the buyer's hold is live again until delivery.
            before = inv.balances(listing)
            listing.quantity_reserved += hold.quantity
            hold.status = 'confirmed'
            if listing.quantity_available < 0:
                fail('err.reopen_stock_no_longer_available')
            inv.movement(db, listing, 'hold_confirmed', before, f'hold:{hold.id}:reopened:{reversal.id}', data.reason)
        if listing.listing_status == 'sold_out' and listing.quantity_available > 0:
            listing.listing_status = ('live' if listing.confirmation_due_at and listing.confirmation_due_at > m.now()
                else 'needs_confirmation')
        if data.kind == 'reopen' and item.demand_allocation_id:
            allocation = db.get(m.DemandAllocation, item.demand_allocation_id)
            if allocation and allocation.status == 'delivered':
                allocation.status = 'in_transit'
    if data.kind == 'reopen' and order.sourcing_request_id:
        request = db.get(m.SourcingRequest, order.sourcing_request_id)
        if request and request.status == 'completed':
            request.status = 'fulfilling'
    recognise(order, None, '')
    order.internal_status = 'in_transit' if data.kind == 'reopen' else 'cancelled'
    label = 'Delivery reversed' if data.kind == 'reopen' else 'Returned by buyer'
    order.activity = [*order.activity, {'label': label, 'at': m.now().isoformat()}]
    db.flush()
    return reversal


def reversal_view(row):
    return {k: getattr(row, k) for k in ('id', 'order_id', 'kind', 'recognized_on', 'reversed_on', 'revenue', 'cost',
        'reason', 'created_at')}


@router.post('/orders/{id}/reverse-delivery')
def reverse(id: str, data: ReverseDeliveryInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
            db=Depends(database)):
    from .main import result
    key, fingerprint, prior = s.replay(db, operator.id, 'reverse-delivery', idempotency_key, {'id': id, **data.model_dump()})
    if prior:
        return result(reversal_view(db.get(m.OrderRecognitionReversal, prior)))
    order = db.scalar(select(m.Order).where(m.Order.id == id).with_for_update())
    if not order:
        fail('err.order_not_found', 404)
    row = reverse_delivery(db, order, data, operator)
    s.remember(db, key, fingerprint, row.id)
    return result(reversal_view(row))


# ---- command line ------------------------------------------------------------------

class RecognitionError(ValueError):
    pass


def dry_run(db):
    """Every delivered order: its stored day against what its history says."""
    orders = db.scalars(select(m.Order).where(m.Order.internal_status.in_(RECOGNISED)).order_by(m.Order.created_at)).all()
    reversed_ = set(db.scalars(select(m.OrderRecognitionReversal.order_id)))
    dated, differs = [], []
    for order in orders:
        if order.recognized_on is None:
            continue
        day, reason = classify(order)
        dated.append(order.id)
        # A reopened and redelivered order has two Delivered entries by design.
        if order.id not in reversed_ and day != order.recognized_on:
            differs.append({'order_id': order.id, 'stored': order.recognized_on, 'history': day, 'reason': reason})
    waiting = unresolved(db)
    return {'dated': len(dated), 'unresolved': waiting, 'unresolved_amount': sum((r['amount'] for r in waiting), ZERO),
            'differs': differs}


def apply(db, order_id, on, evidence, by):
    """Date one unresolved delivered order with evidence (rule R6)."""
    order = db.scalar(select(m.Order).where(m.Order.id == order_id).with_for_update())
    if order is None:
        raise RecognitionError(f'{order_id} not found.')
    if order.internal_status not in RECOGNISED:
        raise RecognitionError(f'{order_id} is not delivered ({order.internal_status}).')
    if order.recognized_on is not None:
        raise RecognitionError(f'{order_id} already counts on {order.recognized_on}.')
    if not evidence or len(evidence.strip()) < 3 or not by or len(by.strip()) < 2:
        raise RecognitionError('Give the evidence (--evidence) and who decided (--by).')
    if on > c.business_today():
        raise RecognitionError('The delivery day cannot be in the future.')
    recognise(order, on, f'{evidence.strip()} (dated by {by.strip()})'[:1000])
    db.flush()
    return order


def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    raise TypeError(type(value).__name__)


def to_text(report):
    out = ['App order recognition dates: dry run (nothing changed)', '',
           f"Delivered orders with a recognition date: {report['dated']}",
           f"Unresolved (kept out of every period): {len(report['unresolved'])}, "
           f"TZS {report['unresolved_amount']:,.0f}"]
    for r in report['unresolved']:
        out.append(f"  - {r['order_id']} ({r['reference']}, {r['status']}, created {r['created_at']:%Y-%m-%d}) "
                   f"TZS {r['amount']:,.0f}: {r['reason']}")
        out.append(f"    ->  python -m app.recognition --apply {r['order_id']} --on "
                   f"{(r['suggested_on'] or 'YYYY-MM-DD')} --evidence \"...\" --by \"...\"")
    if report['differs']:
        out += ['', f"Stored day differs from the history: {len(report['differs'])}"]
        out += [f"  - {r['order_id']}: stored {r['stored']}, history {r['history'] or '-'} {r['reason']}"
                for r in report['differs']]
    return '\n'.join(out)


def main(argv=None, ask=input, bind=None):
    parser = argparse.ArgumentParser(description='Recognition dates of delivered app orders.')
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--dry-run', action='store_true', help='list unresolved orders; change nothing')
    action.add_argument('--apply', metavar='ORDER_ID', help='date one unresolved order')
    parser.add_argument('--on', help='the day it was delivered (YYYY-MM-DD)')
    parser.add_argument('--evidence', help='what shows it (delivery note, buyer confirmation, SMS)')
    parser.add_argument('--by', help='who decided, normally the finance owner')
    parser.add_argument('--confirm', help='the order id, to confirm without a prompt')
    parser.add_argument('--json', action='store_true', help='dry run as JSON')
    args = parser.parse_args(argv)
    if bind is None:
        from .db import engine as bind
    if args.dry_run:
        with bind.connect() as connection, connection.begin() as transaction:
            with Session(bind=connection) as db:
                report = dry_run(db)
            transaction.rollback()
        print(json.dumps(report, default=_plain, indent=2) if args.json else to_text(report))
        return 0
    try:
        on = date.fromisoformat(args.on or '')
    except ValueError:
        print('Refused: give the delivery day with --on YYYY-MM-DD.', file=sys.stderr)
        return 2
    try:
        with Session(bind) as db, db.begin():
            print(f'{args.apply}: counts as a sale on {on}. Evidence: {args.evidence}')
            given = args.confirm if args.confirm is not None else ask(
                f'Type the id {args.apply} to confirm (anything else cancels): ').strip()
            if given != args.apply:
                print('Cancelled; nothing changed.')
                db.rollback()
                return 1
            apply(db, args.apply, on, args.evidence, args.by)
        print('Recorded.')
        return 0
    except RecognitionError as error:
        print(f'Refused: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
