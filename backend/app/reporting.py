"""One reporting layer: the same population on every finance screen (build
plan M1.7, finding F01; definitions in docs/finance-metrics.md).

Every headline money figure on a finance page comes from here, and every one
is the sum of rows a person can open. A row says where it comes from:

    {'source': 'ledger' | 'marketplace', 'source_table': ..., 'source_id': ...,
     'key': 'table:id', 'date': ..., 'amount': ..., <context>}

`key` names the record the money is counted from. A figure never counts the
same key twice (`dedupe`), and each economic event is counted from one record
only:

- money out to a registered supplier is the transfer (`supplier_payments`),
  never its allocations; moving an allocation to credit or to another invoice
  moves no money (rules R3, R4); a refund is its own dated inflow;
- a buyer's app payment on delivery is its receipts (`payment_receipts`); a
  pay-now payment, which has no receipt rows, is the payment itself;
- what Omoterra owes for received goods is the receipt's payable
  (`ledger_debts`, source batch_receipt or lpo), never the delivery note too;
  their cost of goods is the sale line that sold them (`sale_items`);
- a marketplace order's cost is its settlements, so cost ties to the payable.

Recognition (decisions D2, D7; M2.5): a direct sale counts on its sale
date; an app order counts on the day it was delivered (Dar es Salaam time),
stored as `orders.recognized_on` when it is marked delivered. A delivered
order with no recognition date (history too ambiguous to backfill) is
*unresolved*: listed, and kept out of period revenue and cost (R5, R6). A
delivered order that is reopened or returned stays in the period it was
recognised in; its `order_recognition_reversals` row takes the same revenue
and cost out on the day of the reversal (recognition.py), so a period never
changes after the fact. An order not yet delivered is a *commitment*: app
orders and orders staff took for a buyer (`buyer_orders`), reported on their
own and never as revenue or as money owed to Omoterra. A staff order becomes
a direct sale dated its delivery day.

Cost states (M1.3, rule R5): a sale line's buying cost is known, free (a
known zero an admin approved) or unknown. An unknown line counts for nothing
in cost of goods and makes every period containing it `provisional`:
profit is shown as "Provisional: buying costs incomplete" with the sales and
revenue affected, never as a final, minimum or range figure.

App payouts (M2.7, payouts.py): what is owed on a settlement is its amount
less what settled it (debited attempts less refunds, less money possibly
paid twice that was resolved, plus supplier payout credit set off against
it; 7 October 2026). Money out is each debited
attempt on its debit day and a refund is money in on its own day; an attempt
sent but not confirmed is in flight (beside money out, never in it), and
money possibly paid twice is the disputed exposure, shown beside I owe.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import Date, Integer, String, Text, and_, case, cast, exists, func, literal, null, or_, select, union_all

from . import contracts as c, models as m, transfers as tr

ZERO = Decimal('0')
EAT = 'Africa/Dar_es_Salaam'
PROVISIONAL = 'Provisional: buying costs incomplete'
# App orders: recognised once delivered ('completed' is the same delivery,
# never counted again); cancelled or failed ones count for nothing.
RECOGNISED = ('delivered', 'completed')
DEAD = ('cancelled', 'payment_failed')
# App payouts are due this many days after the order is delivered (finance owner, 5 October 2026).
PAYOUT_DAYS = 7


# ---- rows -------------------------------------------------------------------

def _row(source, table, id, on, amount, **context):
    return {'source': source, 'source_table': table, 'source_id': id, 'key': f'{table}:{id}',
            'date': on, 'amount': amount, **context}


def dedupe(rows):
    """Each record counted once: the first row for a key is kept."""
    seen, out = set(), []
    for row in rows:
        if row['key'] not in seen:
            seen.add(row['key'])
            out.append(row)
    return out


def total(rows, field='amount'):
    return sum((row[field] for row in rows), ZERO)


def _split(rows):
    return {'total': total(rows), 'ledger': total(r for r in rows if r['source'] == 'ledger'),
            'marketplace': total(r for r in rows if r['source'] == 'marketplace'), 'count': len(rows)}


def _within(on, start, end):
    return on is not None and (start is None or on >= start) and (end is None or on <= end)


def local_day(column):
    """A UTC timestamp's calendar day in Dar es Salaam."""
    return cast(func.timezone(EAT, column), Date)


def local_day_of(value):
    """The Dar es Salaam calendar day of a stored timestamp."""
    return value.astimezone(ZoneInfo(EAT)).date() if value else None


def delivered_on():
    """The day an app order counts as a sale: its stored recognition date
    (M2.5), null while unresolved."""
    return m.Order.recognized_on


def _deposit_entries():
    """Signed entries of every deposit's money on staff buyer orders
    (7 October 2026): (deposit_id, order_id, amount). The deposit on its own
    order (unless voided), moves in and out, part refunds given back from an
    order, and the parts applied to an order's sale on delivery."""
    P, MV, AP = m.BuyerOrderPayment, m.BuyerOrderDepositMove, m.BuyerOrderDepositApplication
    return union_all(
        select(P.id.label('deposit_id'), P.buyer_order_id.label('order_id'), P.amount.label('amount'))
            .where(P.kind == 'deposit', P.voided_at.is_(None)),
        select(MV.deposit_id, MV.to_order_id, MV.amount),
        select(MV.deposit_id, MV.from_order_id, -MV.amount),
        select(P.refund_of, P.buyer_order_id, -P.amount).where(P.kind == 'refund'),
        select(AP.deposit_id, AP.buyer_order_id, -AP.amount)).subquery('deposit_entries')


def deposit_portions(db, order_ids=None, deposit_ids=None):
    """Deposit money held now, per deposit and order:
    {(deposit_id, order_id): amount}. A deposit is held where it was paid
    and where part of it was moved, less what was given back from, moved
    away from or applied on each order."""
    E = _deposit_entries()
    held = func.sum(E.c.amount)
    query = select(E.c.deposit_id, E.c.order_id, held).group_by(E.c.deposit_id, E.c.order_id).having(held > 0)
    if order_ids is not None:
        query = query.where(E.c.order_id.in_(list(order_ids)))
    if deposit_ids is not None:
        query = query.where(E.c.deposit_id.in_(list(deposit_ids)))
    return {(deposit, order): amount for deposit, order, amount in db.execute(query)}


def held_deposits(db, order_ids=None):
    """Deposits held on staff buyer orders: paid, not voided, not given back,
    not moved away and not yet applied to the order's sale; a part moved in
    from another order of the same buyer counts here. {buyer_order_id: amount}."""
    out = defaultdict(lambda: ZERO)
    for (_deposit, order), amount in deposit_portions(db, order_ids).items():
        out[order] += amount
    return dict(out)


def _buyers(db, orders):
    """An app order's buyer as staff know them: app account, or the CRM
    record of a managed request."""
    ids = {order.buyer_id for order in orders if order.buyer_id}
    users = {row.id: row for row in db.scalars(select(m.User).where(m.User.id.in_(ids)))} if ids else {}
    names = {}
    for order in orders:
        user = users.get(order.buyer_id)
        name = (user.name or user.phone) if user else ''
        if not name and order.sourcing_request_id:
            request = db.get(m.SourcingRequest, order.sourcing_request_id)
            profile = db.get(m.BuyerProfile, request.buyer_profile_id) if request and request.buyer_profile_id else None
            name = profile.business_name if profile else ''
        names[order.id] = name or 'App buyer'
    return names


def _supplier_names(db, ids):
    ids = set(ids)
    if not ids:
        return {}
    rows = db.execute(select(m.User.id, m.User.name, m.User.phone, m.SupplierProfile.legal_name)
        .outerjoin(m.SupplierProfile, m.SupplierProfile.user_id == m.User.id).where(m.User.id.in_(ids))).all()
    return {id: legal or name or phone for id, name, phone, legal in rows}


def _ledger_row(debt, today):
    return _row('ledger', 'ledger_debts', debt.id, debt.incurred_on, debt.balance,
        party=debt.party_name, party_phone=debt.party_phone, party_kind=debt.party_kind,
        party_key=debt.buyer_profile_id or debt.supplier_id or f'{debt.party_kind}:{debt.party_name.casefold()}',
        buyer_profile_id=debt.buyer_profile_id, supplier_id=debt.supplier_id, description=debt.description,
        debt_source=debt.source, sale_id=debt.sale_id, due_on=debt.due_on,
        overdue=debt.due_on is not None and debt.due_on < today, href=f'/finance/debts/{debt.id}')


# ---- balances (metrics 1 to 5) ------------------------------------------------

def receivables(db):
    """Owed to Omoterra now (metric 1): open ledger receivables plus the
    unpaid balance of delivered app orders. Undelivered orders are
    commitments, never here. A delivered app order is due on its delivery
    day and overdue from the next day (finance owner, 5 October 2026)."""
    today = c.business_today()
    rows = [_ledger_row(debt, today) for debt in db.scalars(select(m.LedgerDebt).where(
        m.LedgerDebt.direction == 'receivable', m.LedgerDebt.status == 'open'))]
    market = db.execute(select(m.Payment, m.Order, delivered_on()).join(m.Order, m.Order.id == m.Payment.order_id)
        .where(m.Order.internal_status.in_(RECOGNISED), m.Payment.status.in_(('pending', 'partial')),
               m.Payment.amount > m.Payment.received_amount)).all()
    names = _buyers(db, [order for _payment, order, _on in market])
    for payment, order, on in market:
        rows.append(_row('marketplace', 'payments', payment.id, on, payment.amount - payment.received_amount,
            party=names[order.id], party_phone='', party_kind='buyer', party_key=order.buyer_id or f'order:{order.id}',
            buyer_profile_id=None, supplier_id=None, buyer_user_id=order.buyer_id, order_id=order.id,
            description=f'App order {order.id[:8].upper()}', due_on=on, overdue=on is not None and on < today,
            href=f'/orders/{order.id}'))
    rows = dedupe(rows)
    return {**_split(rows), 'overdue': total(r for r in rows if r['overdue']),
            'overdue_count': sum(1 for r in rows if r['overdue']), 'rows': rows}


def commitments(db):
    """Orders not delivered yet (and not cancelled): app orders and orders
    staff took for a buyer (M2.5). Ordered value, the part still unpaid and
    any money the buyer paid ahead (a customer deposit, held for them).
    Never revenue and never a receivable; no stock is taken for them."""
    rows = []
    staff = db.scalars(select(m.BuyerOrder).where(m.BuyerOrder.status == 'open')).all()
    held = held_deposits(db, [order.id for order in staff]) if staff else {}
    for order in staff:
        paid = held.get(order.id, ZERO)
        due = f', due {order.expected_on:%d %b}' if order.expected_on else ''
        rows.append(_row('ledger', 'buyer_orders', order.id, order.ordered_on, order.total_amount,
            party=order.buyer_name, party_phone=order.buyer_phone, party_kind='buyer',
            buyer_profile_id=order.buyer_profile_id, buyer_user_id=None, order_id=None, status='open',
            expected_on=order.expected_on, paid=paid, unpaid=order.total_amount - paid,
            description=f'Order {order.order_number} (not delivered{due})', href=f'/sales/orders/{order.id}'))
    orders = db.execute(select(m.Order, m.Payment).outerjoin(m.Payment, m.Payment.order_id == m.Order.id)
        .where(m.Order.internal_status.not_in((*RECOGNISED, *DEAD)))).all()
    names = _buyers(db, [order for order, _payment in orders])
    for order, payment in orders:
        paid = payment.received_amount if payment else ZERO
        rows.append(_row('marketplace', 'orders', order.id, local_day_of(order.created_at), order.total_amount,
            party=names[order.id], party_kind='buyer', buyer_user_id=order.buyer_id, order_id=order.id,
            status=order.internal_status, paid=paid, unpaid=order.total_amount - paid,
            description=f'App order {order.id[:8].upper()} ({order.internal_status.replace("_", " ")})',
            href=f'/orders/{order.id}'))
    rows = dedupe(rows)
    return {'total': total(rows), 'unpaid': total(rows, 'unpaid'), 'deposits': total(rows, 'paid'),
            'count': len(rows), 'ledger': total(r for r in rows if r['source'] == 'ledger'),
            'ledger_count': sum(1 for r in rows if r['source'] == 'ledger'),
            'marketplace': total(r for r in rows if r['source'] == 'marketplace'),
            'marketplace_count': sum(1 for r in rows if r['source'] == 'marketplace'), 'rows': rows}


def payables(db, supplier_ids=None):
    """Owed by Omoterra now (metric 2): open ledger payables (sale costs,
    delivery notes, LPO receipts, manual debts, expenses) plus what is still
    outstanding on app payouts (M2.7: the amount less debited attempts less
    refunds). Beside it, never netted: the disputed exposure on payouts
    (money possibly paid twice, M2.7), payouts sent but not yet confirmed as
    debited (in flight), and money suppliers hold from transfers as credit
    or not yet classified (unresolved)."""
    from . import payouts
    today = c.business_today()
    query = select(m.LedgerDebt).where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open')
    settlements = (select(m.Settlement, delivered_on()).join(m.OrderItem, m.OrderItem.id == m.Settlement.order_item_id)
        .join(m.Order, m.Order.id == m.OrderItem.order_id).where(m.Settlement.status == 'pending'))
    attempted = select(m.Settlement).where(m.Settlement.status != 'cancelled',
        m.Settlement.id.in_(select(m.SettlementTransfer.settlement_id)))
    if supplier_ids is not None:
        supplier_ids = list(supplier_ids)
        query = query.where(m.LedgerDebt.supplier_id.in_(supplier_ids))
        settlements = settlements.where(m.Settlement.supplier_id.in_(supplier_ids))
        attempted = attempted.where(m.Settlement.supplier_id.in_(supplier_ids))
    rows = [_ledger_row(debt, today) for debt in db.scalars(query)]
    pending = db.execute(settlements).all()
    names = _supplier_names(db, [row.supplier_id for row, _on in pending])
    owed = payouts.settlement_figures(db, [row for row, _on in pending])
    for row, delivered in pending:
        rows.append(_settlement_row(row, names, local_day_of(row.created_at), delivered, today,
            owed[row.id]['outstanding']))
    rows = dedupe(rows)
    held = tr.by_supplier(db, supplier_ids)
    payout_credit = payouts.credit_by_supplier(db, supplier_ids)
    money = payouts.settlement_figures(db, db.scalars(attempted).all()).values()
    exposed = [n['exposure'] for n in money if n['exposure'] > 0]
    flying = [n['in_flight'] for n in money if n['in_flight'] > 0]
    return {**_split(rows), 'overdue': total(r for r in rows if r['overdue']),
            'overdue_count': sum(1 for r in rows if r['overdue']),
            # M2.7: money possibly paid twice on app payouts, until refunded.
            'disputed': sum(exposed, ZERO), 'disputed_count': len(exposed),
            'payouts_in_flight': sum(flying, ZERO), 'payouts_in_flight_count': len(flying),
            'credit': sum((row['credit'] for row in held.values()), ZERO),
            # App payout money a supplier kept as credit (7 October 2026),
            # set off against their next payouts.
            'payout_credit': sum(payout_credit.values(), ZERO),
            'unresolved': sum((row['unresolved'] for row in held.values()), ZERO), 'rows': rows}


def _settlement_row(row, names, on, delivered=None, today=None, amount=None):
    """An app payout, due PAYOUT_DAYS after its order was delivered; an
    undelivered order's payout has no due date yet. `amount` is what is
    still outstanding on it (M2.7)."""
    due = delivered + timedelta(days=PAYOUT_DAYS) if delivered else None
    return _row('marketplace', 'settlements', row.id, on, row.total_payable if amount is None else amount,
        party=names.get(row.supplier_id, 'Supplier'), party_phone='', party_kind='supplier', party_key=row.supplier_id,
        buyer_profile_id=None, supplier_id=row.supplier_id, description='App order payout', due_on=due,
        overdue=due is not None and today is not None and due < today, order_item_id=row.order_item_id, href='/settlements')


def settlement_totals(db):
    """App payouts (metric 5, M2.7): still outstanding on unpaid ones, net
    paid to date (debited attempts less refunds, every attempt counted), the
    refunds, payouts in flight (sent, debit not confirmed: not money out)
    and the disputed exposure (money possibly paid twice)."""
    from . import payouts
    rows = db.scalars(select(m.Settlement).where(m.Settlement.status != 'cancelled')).all()
    money = payouts.settlement_figures(db, rows)
    pending = [row for row in rows if row.status == 'pending']
    exposed = [n for n in money.values() if n['exposure'] > 0]
    flying = [n for n in money.values() if n['in_flight'] > 0]
    return {'pending': sum((money[row.id]['outstanding'] for row in pending), ZERO), 'pending_count': len(pending),
            'paid': sum((n['net_paid'] for n in money.values()), ZERO),
            'paid_count': sum(1 for row in rows if row.status == 'paid'),
            'refunded': sum((n['refunded'] for n in money.values()), ZERO),
            'in_flight': sum((n['in_flight'] for n in flying), ZERO), 'in_flight_count': len(flying),
            'disputed': sum((n['exposure'] for n in exposed), ZERO), 'disputed_count': len(exposed),
            # Possibly paid twice and resolved (7 October 2026).
            'resolved': sum((n['resolved'] for n in money.values()), ZERO),
            'written_off': sum((n['written_off'] for n in money.values()), ZERO),
            'payout_credit': sum(payouts.credit_by_supplier(db).values(), ZERO)}


def supplier_totals(db, supplier_ids=None):
    """Per registered supplier, from their non-cancelled payables: bought,
    paid (allocated), owed, open invoices, due now (incl. overdue and
    undated), overdue; app payouts pending and paid beside them; credit and
    unresolved money on their transfers. The staff statement, Supplier
    payments, the Suppliers list and the portal all read these figures."""
    today = c.business_today()
    query = select(m.LedgerDebt).where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status != 'cancelled',
        m.LedgerDebt.supplier_id.is_not(None))
    settlements = select(m.Settlement).where(m.Settlement.status != 'cancelled')
    if supplier_ids is not None:
        supplier_ids = list(supplier_ids)
        query = query.where(m.LedgerDebt.supplier_id.in_(supplier_ids))
        settlements = settlements.where(m.Settlement.supplier_id.in_(supplier_ids))
    blank = lambda: {'bought': ZERO, 'paid': ZERO, 'owed': ZERO, 'open_invoices': 0, 'due_now': ZERO,
        'overdue': ZERO, 'earliest_due': None, 'undated': False, 'settlements_pending': ZERO,
        'settlements_paid': ZERO, 'credit': ZERO, 'unresolved': ZERO, 'payout_credit': ZERO}
    out = defaultdict(blank)
    for debt in db.scalars(query):
        row = out[debt.supplier_id]
        row['bought'] += debt.amount
        row['paid'] += debt.paid_amount
        if debt.status != 'open':
            continue
        row['owed'] += debt.balance
        row['open_invoices'] += 1
        if debt.due_on is None:
            row['undated'] = True
        elif row['earliest_due'] is None or debt.due_on < row['earliest_due']:
            row['earliest_due'] = debt.due_on
        if debt.due_on is None or debt.due_on <= today:
            row['due_now'] += debt.balance
        if debt.due_on is not None and debt.due_on < today:
            row['overdue'] += debt.balance
    # App payouts (M2.7): still outstanding, and net paid (debited less refunds).
    from . import payouts
    rows = db.scalars(settlements).all()
    for row, money in zip(rows, map(payouts.settlement_figures(db, rows).get, (r.id for r in rows))):
        if row.status == 'pending':
            out[row.supplier_id]['settlements_pending'] += money['outstanding']
        out[row.supplier_id]['settlements_paid'] += money['net_paid']
    for supplier_id, credit in payouts.credit_by_supplier(db, supplier_ids).items():
        out[supplier_id]['payout_credit'] = credit
    for supplier_id, held in tr.by_supplier(db, supplier_ids).items():
        out[supplier_id]['credit'] = held['credit']
        out[supplier_id]['unresolved'] = held['unresolved']
    return dict(out)


# ---- sales, cost and profit (metrics 6, 7, 13 to 16) ---------------------------

def _orders_recognised(db):
    """Delivered app orders with their delivery day (None: unresolved)."""
    return db.execute(select(m.Order, delivered_on()).where(m.Order.internal_status.in_(RECOGNISED))).all()


REVERSAL_WORDS = {'reopen': 'reopened', 'return': 'returned by the buyer'}


def _reversals(db, start, end):
    """Delivered app orders later reopened or returned (M2.5): each gives
    a row on the day it was recognised (the sale as it was counted then) and
    one taking it out on the day it was reversed, each only when that day is
    in the period. (reversal, order, buyer name, recognised, reversed)."""
    rows = db.execute(select(m.OrderRecognitionReversal, m.Order).join(m.Order,
        m.Order.id == m.OrderRecognitionReversal.order_id).where(m.OrderRecognitionReversal.recognized_on.is_not(None))
        .order_by(m.OrderRecognitionReversal.created_at)).all()
    names = _buyers(db, [order for _row_, order in rows])
    return [(row, order, names[order.id], _within(row.recognized_on, start, end), _within(row.reversed_on, start, end))
            for row, order in rows]


def revenue(db, start=None, end=None):
    """Sales in the period (metrics 6 and 7): active direct sales by sale
    date plus delivered app orders by delivery date. Delivered orders with
    no dated delivery are `unresolved`: listed, never in the period."""
    sales = select(m.Sale).where(m.Sale.status == 'active')
    if start:
        sales = sales.where(m.Sale.sold_on >= start)
    if end:
        sales = sales.where(m.Sale.sold_on <= end)
    rows = [_row('ledger', 'sales', sale.id, sale.sold_on, sale.total_amount, party=sale.buyer_name,
        buyer_profile_id=sale.buyer_profile_id, buyer_user_id=sale.buyer_user_id,
        description=sale.sale_number, href=f'/sales/{sale.id}') for sale in db.scalars(sales)]
    orders = _orders_recognised(db)
    names = _buyers(db, [order for order, _on in orders])
    unresolved = []
    for order, on in orders:
        row = _row('marketplace', 'orders', order.id, on, order.total_amount, party=names[order.id],
            buyer_profile_id=None, buyer_user_id=order.buyer_id, order_id=order.id,
            description=f'App order {order.id[:8].upper()}', href=f'/orders/{order.id}')
        if on is None:
            unresolved.append(row)
        elif _within(on, start, end):
            rows.append(row)
    for reversal, order, name, counted, reversed_ in _reversals(db, start, end):
        label, context = f'App order {order.id[:8].upper()}', dict(party=name, buyer_profile_id=None,
            buyer_user_id=order.buyer_id, order_id=order.id, href=f'/orders/{order.id}')
        if counted:
            rows.append(_row('marketplace', 'order_recognition_reversals', f'{reversal.id}:recognised',
                reversal.recognized_on, reversal.revenue, description=f'{label} (later {REVERSAL_WORDS[reversal.kind]})',
                **context))
        if reversed_:
            rows.append(_row('marketplace', 'order_recognition_reversals', reversal.id, reversal.reversed_on,
                -reversal.revenue, description=f'{label} {REVERSAL_WORDS[reversal.kind]}: {reversal.reason}',
                reversal=True, **context))
    rows = dedupe(rows)
    return {'total': total(rows), 'direct': total(r for r in rows if r['source'] == 'ledger'),
            'marketplace': total(r for r in rows if r['source'] == 'marketplace'),
            'direct_count': sum(1 for r in rows if r['source'] == 'ledger'),
            'marketplace_count': sum(1 for r in rows if r['source'] == 'marketplace' and not r.get('reversal')),
            'reversed_count': sum(1 for r in rows if r.get('reversal')),
            'count': sum(1 for r in rows if not r.get('reversal')),
            'unresolved': {'count': len(unresolved), 'amount': total(unresolved), 'rows': unresolved}, 'rows': rows}


def sales_summary(db, chosen, start=None, end=None, match=None):
    """Totals for the Sales page (metrics 7 to 10). `chosen` selects the
    direct sales the list shows (its dates, buyer and search, every status
    tab); `match` filters the delivered app orders in the same dates the
    same way. Sales total = direct + app orders, the population of revenue().

    - paid: money allocated to those sales' receivables, dated up to `end`;
    - buyer_owes: their receivables' open balances now;
    - supplier_owed: their own supplier-cost debts (source sale_cost) only.
      Stock from a delivery note or LPO is owed on the receipt (M2.4), and
      sale-linked expenses are `expenses_owed`, never "suppliers"."""
    direct, count = db.execute(select(func.coalesce(func.sum(m.Sale.total_amount), 0), func.count())
        .where(m.Sale.id.in_(chosen))).one()
    def owed(*conditions):
        debts = select(m.LedgerDebt).where(m.LedgerDebt.sale_id.in_(chosen), m.LedgerDebt.status != 'cancelled',
            *conditions).subquery()
        return db.execute(select(func.coalesce(func.sum(debts.c.amount - debts.c.paid_amount), 0),
            func.count(func.distinct(debts.c.sale_id)).filter(debts.c.amount > debts.c.paid_amount))).one()
    paid = select(func.coalesce(func.sum(m.LedgerPayment.amount), 0)).join(m.LedgerDebt,
        m.LedgerDebt.id == m.LedgerPayment.debt_id).where(m.LedgerDebt.sale_id.in_(chosen),
        m.LedgerDebt.direction == 'receivable', m.LedgerDebt.status != 'cancelled', m.LedgerPayment.reversed_at.is_(None))
    if end:
        paid = paid.where(m.LedgerPayment.paid_on <= end)
    buyer_owes, owing = owed(m.LedgerDebt.direction == 'receivable')
    supplier_owed, supplier_sales = owed(m.LedgerDebt.direction == 'payable', m.LedgerDebt.source == 'sale_cost')
    expenses_owed, expense_sales = owed(m.LedgerDebt.direction == 'payable', m.LedgerDebt.source == 'expense')
    market = [row for row in revenue(db, start, end)['rows'] if row['source'] == 'marketplace'
              and (match is None or match(row))]
    pending = commitments(db)
    # Rule R5: the active sales among them with an unknown buying cost.
    unknown = select(m.SaleItem.sale_id).join(m.Sale, m.Sale.id == m.SaleItem.sale_id).where(
        m.SaleItem.sale_id.in_(chosen), m.Sale.status == 'active', m.SaleItem.cost_state == 'unknown')
    lines = db.scalar(select(func.count()).select_from(unknown.subquery())) or 0
    affected, affected_revenue = db.execute(select(func.count(), func.coalesce(func.sum(m.Sale.total_amount), 0))
        .where(m.Sale.id.in_(unknown))).one()
    market_count = sum(1 for row in market if not row.get('reversal'))
    return {'sales_total': direct + total(market), 'direct_total': direct, 'sales_count': count,
            'unknown_cost': {'lines': lines, 'sales': affected, 'revenue': affected_revenue},
            'provisional': lines > 0,
            'marketplace_total': total(market), 'marketplace_count': market_count,
            'received': db.scalar(paid) or ZERO, 'buyer_owes': buyer_owes, 'buyer_owes_count': owing,
            'supplier_owed': supplier_owed, 'supplier_owed_count': supplier_sales,
            'expenses_owed': expenses_owed, 'expenses_owed_count': expense_sales,
            'commitments': {k: pending[k] for k in COMMITMENT_FIELDS}}


COMMITMENT_FIELDS = ('total', 'unpaid', 'deposits', 'count', 'ledger', 'ledger_count', 'marketplace', 'marketplace_count')


def cost_state(item):
    """What is known about a sale line's buying cost (M1.3): 'known',
    'free' (a known zero an admin approved) or 'unknown' (rule R5)."""
    return item.cost_state or 'unknown'


def cost_of_goods(db, start=None, end=None):
    """Cost of what was sold in the period (metric 15), dated like its
    revenue: direct sale lines at their cost (delivery-note and LPO lines at
    the receipt's cost), and delivered app orders at their settlements.
    An unknown-cost line counts for nothing here (never as a zero cost):
    `unknown` counts such lines, their sales and those sales' revenue, and
    the period is `provisional` whenever there is one (rule R5)."""
    items = select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id).where(m.Sale.status == 'active')
    if start:
        items = items.where(m.Sale.sold_on >= start)
    if end:
        items = items.where(m.Sale.sold_on <= end)
    rows, unknown_sales = [], {}
    for item, sale in db.execute(items):
        state = cost_state(item)
        if state == 'unknown':
            unknown_sales[sale.id] = sale.total_amount
        amount = ZERO if state == 'unknown' else item.cost_total or ZERO
        rows.append(_row('ledger', 'sale_items', item.id, sale.sold_on, amount,
            cost_state=state, sale_id=sale.id, party=item.supplier_name or '', supplier_id=item.supplier_id,
            supplier_collection_id=item.supplier_collection_id, lpo_line_id=item.lpo_line_id,
            opening_stock_id=item.opening_stock_id,
            description=f'{sale.sale_number}: {item.description or item.category.replace("_", " ")}',
            href=f'/sales/{sale.id}'))
    orders = {order.id: on for order, on in _orders_recognised(db) if _within(on, start, end)}
    if orders:
        settled = db.execute(select(m.Settlement, m.OrderItem.order_id).join(m.OrderItem,
            m.OrderItem.id == m.Settlement.order_item_id).where(m.OrderItem.order_id.in_(list(orders)),
            m.Settlement.status != 'cancelled')).all()
        names = _supplier_names(db, [row.supplier_id for row, _order in settled])
        for row, order_id in settled:
            rows.append({**_settlement_row(row, names, orders[order_id]), 'cost_state': 'known',
                'order_id': order_id, 'description': f'App order {order_id[:8].upper()} payout',
                'href': f'/orders/{order_id}'})
    # Reopened or returned orders (M2.5): cost counted on the day the order
    # was recognised and taken out on the day it was reversed, like revenue.
    for reversal, order, _name, counted, reversed_ in _reversals(db, start, end):
        if not reversal.cost:
            continue
        context = dict(cost_state='known', order_id=order.id, party='', supplier_id=None, href=f'/orders/{order.id}')
        label = f'App order {order.id[:8].upper()} payout'
        if counted:
            rows.append(_row('marketplace', 'order_recognition_reversals', f'{reversal.id}:recognised',
                reversal.recognized_on, reversal.cost, description=f'{label} (later {REVERSAL_WORDS[reversal.kind]})',
                **context))
        if reversed_:
            rows.append(_row('marketplace', 'order_recognition_reversals', reversal.id, reversal.reversed_on,
                -reversal.cost, description=f'{label} cancelled: order {REVERSAL_WORDS[reversal.kind]}', **context))
    rows = dedupe(rows)
    lines = sum(1 for r in rows if r['cost_state'] == 'unknown')
    return {'total': total(rows), 'direct': total(r for r in rows if r['source'] == 'ledger'),
            'marketplace': total(r for r in rows if r['source'] == 'marketplace'),
            'unknown': {'lines': lines, 'sales': len(unknown_sales), 'revenue': sum(unknown_sales.values(), ZERO)},
            # Rule R5: never final while any line's cost is unknown.
            'provisional': lines > 0, 'rows': rows}


EXPENSE = and_(m.LedgerDebt.source == 'expense', m.LedgerDebt.status != 'cancelled')


def expenses(db, start=None, end=None):
    """Operating expenses incurred in the period (accrual: paid or owed),
    by their date (metric 16)."""
    query = select(m.LedgerDebt).where(EXPENSE)
    if start:
        query = query.where(m.LedgerDebt.incurred_on >= start)
    if end:
        query = query.where(m.LedgerDebt.incurred_on <= end)
    rows = [_row('ledger', 'ledger_debts', debt.id, debt.incurred_on, debt.amount, category=debt.expense_category,
        party=debt.party_name, description=debt.description, href=f'/finance/debts/{debt.id}')
        for debt in db.scalars(query)]
    # Bank and wallet charges (M2.3), on the day they were charged.
    fees = select(m.AccountFee, m.MoneyAccount.name).join(m.MoneyAccount, m.MoneyAccount.id == m.AccountFee.account_id)
    if start:
        fees = fees.where(m.AccountFee.charged_on >= start)
    if end:
        fees = fees.where(m.AccountFee.charged_on <= end)
    rows += [_row('ledger', 'account_fees', fee.id, fee.charged_on, fee.amount, category='bank_charges', party=name,
        description=fee.description, href=f'/finance/accounts/{fee.account_id}') for fee, name in db.execute(fees)]
    # Money possibly paid twice on an app payout and written off (7 October
    # 2026): "Payout loss" on the resolution day. No money moves then: it
    # left on its debit day (rule R3).
    from .payouts import payout_losses
    rows += [_row('marketplace', 'settlement_resolutions', row.id, row.resolved_on, row.amount, category='payout_loss',
        party='', description=f'Payout loss, app order {order_id[:8].upper()}: {row.evidence}'[:200],
        settlement_id=row.settlement_id, href=f'/settlements/{row.settlement_id}')
        for row, order_id in payout_losses(db, start, end)]
    from .locations import depreciation_rows
    assets = list(db.scalars(select(m.BusinessAsset)))
    if assets:
        first = start or min(a.depreciation_start for a in assets)
        last = end or c.business_today()
        rows += [_row('ledger', 'business_assets', f"{r['asset_id']}:{r['date']}", r['date'], r['amount'], category='depreciation',
            description=r['description'], href=f"/locations/{r['location_id']}") for r in depreciation_rows(assets, first, last)]
    rows = dedupe(rows)
    return {'total': total(rows), 'count': len(rows), 'rows': rows}


def stock_lost(db, start=None, end=None):
    """Received stock lost before it was sold, at cost, by the day it was
    recorded: LPO stock losses and delivery-note losses (died, culled,
    stolen, spoiled, or not recovered from a cancelled or reduced sale),
    opening stock losses, and stock count differences (M2.1)."""
    lpo = select(m.StockLoss).where(m.StockLoss.cancelled_at.is_(None))
    notes = select(m.CollectionMovement).where(m.CollectionMovement.kind.in_(m.COLLECTION_LOSSES),
        m.CollectionMovement.cancelled_at.is_(None))
    if start:
        lpo, notes = lpo.where(m.StockLoss.lost_on >= start), notes.where(m.CollectionMovement.occurred_on >= start)
    if end:
        lpo, notes = lpo.where(m.StockLoss.lost_on <= end), notes.where(m.CollectionMovement.occurred_on <= end)
    from .services import money
    rows = [_row('ledger', 'stock_losses', row.id, row.lost_on, money(row.quantity * row.unit_cost),
        description=row.note or row.reason, href=None) for row in db.scalars(lpo)]
    rows += [_row('ledger', 'collection_movements', row.id, row.occurred_on, money(row.quantity * row.unit_cost),
        description=row.reason or row.kind.replace('_', ' '), href=f'/supplier-collections/{row.collection_id}')
        for row in db.scalars(notes)]
    opening = select(m.OpeningStockMovement).where(m.OpeningStockMovement.kind == 'not_recovered')
    if start:
        opening = opening.where(m.OpeningStockMovement.occurred_on >= start)
    if end:
        opening = opening.where(m.OpeningStockMovement.occurred_on <= end)
    rows += [_row('ledger', 'opening_stock_movements', row.id, row.occurred_on, money(row.quantity * row.unit_cost),
        description=row.reason or 'Opening stock not recovered', href='/finance/opening-stock')
        for row in db.scalars(opening)]
    location_losses = select(m.LocationStockEvent, m.LocationAllocation).join(m.LocationAllocation).where(m.LocationStockEvent.kind == 'lost')
    if start:
        location_losses = location_losses.where(m.LocationStockEvent.occurred_on >= start)
    if end:
        location_losses = location_losses.where(m.LocationStockEvent.occurred_on <= end)
    rows += [_row('ledger', 'location_stock_events', e.id, e.occurred_on, money(e.quantity * a.unit_cost),
        description=e.note, href=f'/locations/{a.location_id}') for e, a in db.execute(location_losses)]
    # M2.1: opening stock losses, and stock count differences (a shortage
    # adds to stock lost, a surplus found on a count reduces it).
    adjustments = select(m.LotAdjustment).where(m.LotAdjustment.cancelled_at.is_(None))
    if start:
        adjustments = adjustments.where(m.LotAdjustment.occurred_on >= start)
    if end:
        adjustments = adjustments.where(m.LotAdjustment.occurred_on <= end)
    rows += [_row('ledger', 'lot_adjustments', row.id, row.occurred_on,
        money((row.quantity if row.kind == 'lost' else -row.quantity) * row.unit_cost),
        description=('Stock count difference: ' if row.kind == 'count' else 'Opening stock lost: ') + row.reason,
        href=f'/stock/{row.lot_table}/{row.lot_id}') for row in db.scalars(adjustments)]
    rows = dedupe(rows)
    return {'total': total(rows), 'count': len(rows), 'rows': rows}


def profit(db, start, end):
    """Operating result for the days start..end (inclusive), day by day
    (metrics 13 and 14): revenue less cost of goods (gross), less expenses
    and stock lost. Every figure is the sum of its rows above."""
    sold, cost = revenue(db, start, end), cost_of_goods(db, start, end)
    spent, lost = expenses(db, start, end), stock_lost(db, start, end)
    days = {}
    for d in (start + timedelta(n) for n in range((end - start).days + 1)):
        days[d] = {'date': d, 'unknown_cost_lines': 0, **{key: ZERO for key in ('sales', 'stock_cost',
            'marketplace_sales', 'marketplace_cost', 'expenses', 'stock_lost')}}
    for row in sold['rows']:
        days[row['date']]['sales' if row['source'] == 'ledger' else 'marketplace_sales'] += row['amount']
    for row in cost['rows']:
        days[row['date']]['stock_cost' if row['source'] == 'ledger' else 'marketplace_cost'] += row['amount']
        days[row['date']]['unknown_cost_lines'] += row['cost_state'] == 'unknown'
    for row in spent['rows']:
        days[row['date']]['expenses'] += row['amount']
    for row in lost['rows']:
        days[row['date']]['stock_lost'] += row['amount']
    for row in days.values():
        row['revenue'] = row['sales'] + row['marketplace_sales']
        row['cost_of_goods'] = row['stock_cost'] + row['marketplace_cost']
        row['gross_profit'] = row['revenue'] - row['cost_of_goods']
        row['expenses_and_losses'] = row['expenses'] + row['stock_lost']
        row['net_profit'] = row['gross_profit'] - row['expenses_and_losses']
        row['provisional'] = row['unknown_cost_lines'] > 0
    totals = {key: sum((row[key] for row in days.values()), ZERO) for key in
        ('sales', 'stock_cost', 'marketplace_sales', 'marketplace_cost', 'revenue', 'cost_of_goods', 'gross_profit',
         'expenses', 'stock_lost', 'expenses_and_losses', 'net_profit')}
    categories = defaultdict(lambda: ZERO)
    for row in spent['rows']:
        categories[row['category']] += row['amount']
    return {'start': start, 'end': end, **totals,
        'sales_count': sold['direct_count'], 'marketplace_count': sold['marketplace_count'],
        'unresolved_marketplace': {k: sold['unresolved'][k] for k in ('count', 'amount')},
        # Rule R5: with any unknown cost the profit figures are not final.
        # Screens show PROVISIONAL with these counts instead of a result.
        'unknown_cost': cost['unknown'], 'provisional': cost['provisional'],
        'provisional_label': PROVISIONAL if cost['provisional'] else None,
        'expenses_by_category': sorted(({'category': k, 'amount': v} for k, v in categories.items()),
            key=lambda r: -r['amount']),
        'days': sorted(days.values(), key=lambda r: r['date'], reverse=True)}


# ---- stock (M1 exit check) ---------------------------------------------------

def stock_on_hand(db):
    """Received stock still on hand, at its receipt cost: delivery notes,
    LPO lines and opening stock (at its opening value). A supplier's registered batch is their declaration and is
    never stock. Current state only (dated stock arrives with M2.1)."""
    from .batch_stock import collection_stock
    from .purchasing import line_stock
    rows = []
    for note in db.scalars(select(m.SupplierCollection).where(m.SupplierCollection.cancelled_at.is_(None))):
        left = collection_stock(db, note.id)['on_hand']
        if left > 0:
            rows.append(_row('ledger', 'supplier_collections', note.id, note.received_on, left * note.unit_cost,
                quantity=left, unit_cost=note.unit_cost, description=note.collection_number,
                href=f'/supplier-collections/{note.id}'))
    lines = db.scalars(select(m.LpoLine).where(m.LpoLine.id.in_(select(m.LpoReceiptLine.lpo_line_id)))).all()
    for line in lines:
        left = line_stock(db, line.id)['on_hand']
        if left > 0:
            rows.append(_row('ledger', 'lpo_lines', line.id, None, left * line.unit_price, quantity=left,
                unit_cost=line.unit_price, description=line.item, href=f'/lpos/{line.lpo_id}'))
    from .opening_stock import stock as opening_stock
    for entry in db.scalars(select(m.OpeningStock).where(m.OpeningStock.cancelled_at.is_(None))):
        left = opening_stock(db, entry.id)['on_hand']
        if left > 0:
            rows.append(_row('ledger', 'opening_stock', entry.id, entry.as_of, left * entry.unit_cost,
                quantity=left, unit_cost=entry.unit_cost, description=f'Opening stock {entry.receipt_number}',
                href=f'/finance/opening-stock?q={entry.receipt_number}'))
    from .locations import allocation_views, opening_return_stock
    allocations = list(db.scalars(select(m.LocationAllocation)))
    for allocation, balance in zip(allocations, allocation_views(db, allocations)):
        left = balance['on_hand']
        if left > 0:
            rows.append(_row('ledger', 'location_allocations', allocation.id, allocation.allocated_on, left * allocation.unit_cost,
                quantity=left, unit_cost=allocation.unit_cost, description=allocation.description, href=f'/locations/{allocation.location_id}'))
        if not allocation.lpo_line_id and not allocation.supplier_collection_id and not allocation.opening_source_id:
            returned = opening_return_stock(db, allocation)
            if returned > 0:
                rows.append(_row('ledger', 'location_opening_returns', allocation.id, allocation.allocated_on, returned * allocation.unit_cost,
                    quantity=returned, unit_cost=allocation.unit_cost, description='Returned opening stock · ' + allocation.description, href=f'/locations/{allocation.location_id}'))
    rows = dedupe(rows)
    return {'total': total(rows), 'quantity': total(rows, 'quantity'), 'rows': rows}


# ---- money moved (metrics 8, 11 and 12) ---------------------------------------

# Method names for app money, which records no real payment method yet.
APP_METHODS = ('pay_on_delivery', 'pay_now', 'app_payout')


def _cash_movements():
    """Every movement of money Omoterra recorded, one row each (rule R3):

    Ledger
    - payments in from buyers and others (receivable installments);
    - payments out with no transfer: to unregistered parties, expenses, and
      supplier payments from before transfers existed;
    - supplier transfers, once each at what really left (less entry errors),
      however many invoices they pay;
    - refunds from suppliers: separate dated inflows;
    - reversed installments, kept for the history. They count for nothing:
      a reversed supplier allocation moved to credit, so its money is still
      in its transfer's row (rule R4).

    Marketplace (app orders)
    - buyer receipts recorded on delivery (`payment_receipts`), and pay-now
      payments confirmed by the provider (which have no receipt rows): each
      payment is counted from one of the two, never both;
    - supplier payouts (M2.7): each debited payout attempt on its debit day
      (a resend is a second outflow), and each refund of one as money in on
      its own day. Initiated attempts (debit not confirmed) and failed ones
      are not money out.

    Staff buyer orders (M2.5)
    - deposits paid before delivery, and deposits given back, until the
      order is delivered and each held deposit becomes a sale payment.

    Accounts (M2.3)
    - bank and wallet charges (`account_fees`). Transfers between two
      Omoterra accounts are not here: they move no money in or out of the
      business, only between its accounts (accounts.py).

    `flow` is 'in' or 'out'; `kind` is payment, allocation (a reversed one),
    transfer, refund, buyer_payment (one customer payment over several debts),
    receipt or payout; `source` is ledger or marketplace."""
    P, D, T, E, U, S = m.LedgerPayment, m.LedgerDebt, m.SupplierPayment, m.TransferEvent, m.User, m.SupplierProfile
    text_ = lambda value: cast(literal(value), Text)
    nothing = lambda kind: cast(null(), kind)
    when = m.LedgerPayment.reversed_at.type
    supplier = func.coalesce(func.nullif(S.legal_name, ''), func.nullif(U.name, ''), U.phone)
    payments = (select(P.id.label('id'),
            case((P.supplier_payment_id.is_(None), text_('payment')), else_=text_('allocation')).label('kind'),
            case((D.direction == 'receivable', text_('in')), else_=text_('out')).label('flow'),
            P.paid_on.label('paid_on'), P.amount.label('amount'), P.method.label('method'),
            P.reference.label('reference'), P.note.label('note'), D.party_name.label('party_name'),
            D.description.label('description'), P.debt_id.label('debt_id'), D.sale_id.label('sale_id'),
            D.supplier_id.label('supplier_id'), P.supplier_payment_id.label('transfer_id'),
            cast(literal(1), Integer).label('invoices'), P.created_at.label('created_at'),
            P.recorded_by.label('recorded_by'), P.reversed_at.label('reversed_at'), P.reversed_by.label('reversed_by'),
            P.reverse_reason.label('reverse_reason'), text_('ledger').label('source'),
            text_('ledger_payments').label('source_table'), nothing(String(36)).label('order_id'))
        .join(D, D.id == P.debt_id)
        .where(or_(and_(P.supplier_payment_id.is_(None), P.buyer_payment_id.is_(None)), P.reversed_at.is_not(None))))
    corrected = (select(func.coalesce(func.sum(E.amount), 0)).where(E.supplier_payment_id == T.id,
        E.kind == 'entry_error').correlate(T).scalar_subquery())
    def first(column):
        """From the first invoice the transfer paid: what it was for."""
        return (select(column).select_from(P).join(D, D.id == P.debt_id).where(P.supplier_payment_id == T.id)
            .order_by(P.created_at).limit(1).correlate(T).scalar_subquery())
    invoices = (select(func.count(func.distinct(P.debt_id))).where(P.supplier_payment_id == T.id,
        P.reversed_at.is_(None)).correlate(T).scalar_subquery())
    transfers = (select(T.id, text_('transfer'), text_('out'), T.paid_on, (T.amount - corrected), T.method,
            T.reference, T.note, supplier,
            first(D.description), first(D.id), first(D.sale_id),
            T.supplier_id, T.id, invoices, T.created_at, T.recorded_by,
            nothing(when), nothing(String(36)), text_(''), text_('ledger'), text_('supplier_payments'),
            nothing(String(36)))
        .join(U, U.id == T.supplier_id).outerjoin(S, S.user_id == T.supplier_id)
        .where(T.amount - corrected > 0))
    refunds = (select(E.id, text_('refund'), text_('in'), E.occurred_on, E.amount, E.method, E.reference,
            E.reason, supplier, text_('Refund from supplier'), nothing(String(36)), nothing(String(36)),
            E.supplier_id, E.supplier_payment_id, cast(literal(0), Integer), E.created_at, E.recorded_by,
            nothing(when), nothing(String(36)), text_(''), text_('ledger'), text_('transfer_events'),
            nothing(String(36)))
        .join(U, U.id == E.supplier_id).outerjoin(S, S.user_id == E.supplier_id)
        .where(E.kind == 'refund'))
    # A customer payment over several debts (buyer_payments) is one row: what
    # its unreversed allocations still count. A reversed allocation shows as
    # its own reversed row above.
    BP = m.BuyerPayment
    still = (select(func.coalesce(func.sum(P.amount), 0)).where(P.buyer_payment_id == BP.id,
        P.reversed_at.is_(None)).correlate(BP).scalar_subquery())
    def first_debt(column):
        return (select(column).select_from(P).join(D, D.id == P.debt_id).where(P.buyer_payment_id == BP.id)
            .order_by(D.incurred_on, D.created_at).limit(1).correlate(BP).scalar_subquery())
    paid_debts = (select(func.count(func.distinct(P.debt_id))).where(P.buyer_payment_id == BP.id,
        P.reversed_at.is_(None)).correlate(BP).scalar_subquery())
    buyer_payments = (select(BP.id, text_('buyer_payment'), text_('in'), BP.paid_on, still, BP.method,
            BP.reference, BP.note, first_debt(D.party_name), first_debt(D.description), first_debt(D.id),
            first_debt(D.sale_id), nothing(String(36)), nothing(String(36)), paid_debts, BP.created_at,
            BP.recorded_by, nothing(when), nothing(String(36)), text_(''), text_('ledger'),
            text_('buyer_payments'), nothing(String(36)))
        .where(still > 0))
    R, PM, O, ST, OI = m.PaymentReceipt, m.Payment, m.Order, m.Settlement, m.OrderItem
    buyer = func.coalesce(func.nullif(U.name, ''), U.phone, text_('App buyer'))
    order_label = func.concat(text_('App order '), func.upper(func.substr(O.id, 1, 8)))
    receipts = (select(R.id, text_('receipt'), text_('in'), local_day(R.created_at), R.amount, PM.method,
            R.reference, text_(''), buyer, order_label, nothing(String(36)), nothing(String(36)),
            nothing(String(36)), nothing(String(36)), cast(literal(0), Integer), R.created_at, nothing(String(36)),
            nothing(when), nothing(String(36)), text_(''), text_('marketplace'), text_('payment_receipts'), O.id)
        .join(PM, PM.id == R.payment_id).join(O, O.id == PM.order_id).outerjoin(U, U.id == O.buyer_id))
    no_receipt = ~exists(select(R.id).where(R.payment_id == PM.id).correlate(PM))
    paid_now = (select(PM.id, text_('receipt'), text_('in'), local_day(PM.paid_at), PM.received_amount, PM.method,
            func.coalesce(PM.provider_transaction_id, text_('')), text_(''), buyer, order_label, nothing(String(36)),
            nothing(String(36)), nothing(String(36)), nothing(String(36)), cast(literal(0), Integer), PM.paid_at,
            nothing(String(36)), nothing(when), nothing(String(36)), text_(''), text_('marketplace'),
            text_('payments'), O.id)
        .join(O, O.id == PM.order_id).outerjoin(U, U.id == O.buyer_id)
        .where(PM.received_amount > 0, PM.paid_at.is_not(None), no_receipt))
    PT, PR = m.SettlementTransfer, m.SettlementRefund
    app_method = lambda column: func.coalesce(func.nullif(column, ''), text_('app_payout'))
    for_order = lambda label: func.concat(text_(label), func.upper(func.substr(OI.order_id, 1, 8)))
    payouts = (select(PT.id, text_('payout'), text_('out'), PT.debited_on, PT.amount, app_method(PT.method),
            PT.reference, case((PT.is_resend, func.concat(text_('Resend, attempt '), cast(PT.attempt_no, Text))),
                else_=text_('')), supplier, for_order('Payout for app order '),
            nothing(String(36)), nothing(String(36)), ST.supplier_id, nothing(String(36)), cast(literal(0), Integer),
            PT.created_at, func.coalesce(PT.debit_confirmed_by, PT.initiated_by), nothing(when), nothing(String(36)),
            text_(''), text_('marketplace'), text_('settlement_transfers'), OI.order_id)
        .join(ST, ST.id == PT.settlement_id).join(OI, OI.id == ST.order_item_id).join(U, U.id == ST.supplier_id)
        .outerjoin(S, S.user_id == ST.supplier_id).where(PT.state == 'debited'))
    payout_refunds = (select(PR.id, text_('payout_refund'), text_('in'), PR.refunded_on, PR.amount, app_method(PR.method),
            PR.reference, PR.evidence, supplier, for_order('Payout refund, app order '),
            nothing(String(36)), nothing(String(36)), ST.supplier_id, nothing(String(36)), cast(literal(0), Integer),
            PR.created_at, PR.recorded_by, nothing(when), nothing(String(36)), text_(''), text_('marketplace'),
            text_('settlement_refunds'), OI.order_id)
        .join(ST, ST.id == PR.settlement_id).join(OI, OI.id == ST.order_item_id).join(U, U.id == ST.supplier_id)
        .outerjoin(S, S.user_id == ST.supplier_id))
    # Bank and wallet charges (M2.3): money out of their account.
    F, A = m.AccountFee, m.MoneyAccount
    fees = (select(F.id, text_('fee'), text_('out'), F.charged_on, F.amount, text_('account_fee'), F.reference,
            text_(''), A.name, F.description, nothing(String(36)), nothing(String(36)), nothing(String(36)),
            nothing(String(36)), cast(literal(0), Integer), F.created_at, F.recorded_by, nothing(when),
            nothing(String(36)), text_(''), text_('ledger'), text_('account_fees'), nothing(String(36)))
        .join(A, A.id == F.account_id))
    # Deposits on orders staff took for a buyer (M2.5): money in when paid,
    # a deposit given back is money out. Once the order is delivered a held
    # deposit becomes a payment on its sale (same day, method, reference and
    # account) and is counted from that payment instead. A voided deposit
    # (entered in error) shows as reversed.
    # A deposit applied in parts (7 October 2026: part moved to another
    # order of the buyer, delivered separately) is counted from each payment
    # for its applied part and from the deposit for the rest.
    BOP, BO, AP = m.BuyerOrderPayment, m.BuyerOrder, m.BuyerOrderDepositApplication
    is_deposit = BOP.kind == 'deposit'
    applied = (select(func.coalesce(func.sum(AP.amount), 0)).where(AP.deposit_id == BOP.id).correlate(BOP)
        .scalar_subquery())
    remaining = case((is_deposit, BOP.amount - applied), else_=BOP.amount)
    deposits = (select(BOP.id, case((is_deposit, text_('deposit')), else_=text_('deposit_refund')),
            case((is_deposit, text_('in')), else_=text_('out')), BOP.paid_on, remaining, BOP.method, BOP.reference,
            BOP.note, BO.buyer_name, func.concat(case((is_deposit, text_('Deposit on order ')),
                else_=text_('Deposit given back, order ')), BO.order_number),
            nothing(String(36)), nothing(String(36)), nothing(String(36)), nothing(String(36)), cast(literal(0), Integer),
            BOP.created_at, BOP.recorded_by, BOP.voided_at, BOP.voided_by, BOP.void_reason, text_('ledger'),
            text_('buyer_order_payments'), nothing(String(36)))
        .join(BO, BO.id == BOP.buyer_order_id).where(BOP.applied_payment_id.is_(None), remaining > 0))
    return union_all(payments, transfers, refunds, buyer_payments, receipts, paid_now, payouts, payout_refunds, fees,
        deposits).subquery('cash_movements')


CASH = _cash_movements()
COUNTED = CASH.c.reversed_at.is_(None)


def moved(db, *conditions):
    """Money in and out over the counted movements matching the conditions."""
    rows = db.execute(select(CASH.c.flow, func.coalesce(func.sum(CASH.c.amount), 0))
        .where(COUNTED, *conditions).group_by(CASH.c.flow)).all()
    totals = {flow: amount for flow, amount in rows}
    return totals.get('in', ZERO), totals.get('out', ZERO)


def disputed_out(db, *conditions):
    """Debited payout attempts inside the matching money out that the
    supplier says never arrived. They stay money out (rule R3: a debited
    outflow is never removed; money that comes back is a refund)."""
    disputed = select(m.SettlementTransfer.id).where(m.SettlementTransfer.supplier_confirmation == 'not_received')
    amount, count = db.execute(select(func.coalesce(func.sum(CASH.c.amount), 0), func.count())
        .where(COUNTED, CASH.c.source_table == 'settlement_transfers', CASH.c.id.in_(disputed), *conditions)).one()
    return {'amount': amount, 'count': count}


def payouts_in_flight(db):
    """Payout attempts sent but not yet confirmed as debited (M2.7): pending
    exposure, never money out until a statement or the provider confirms."""
    amount, count = db.execute(select(func.coalesce(func.sum(m.SettlementTransfer.amount), 0), func.count())
        .where(m.SettlementTransfer.state == 'initiated')).one()
    return {'amount': amount, 'count': count}


def cash_movements(db, start=None, end=None, *conditions):
    """Money in and out in the period, with the split by source and method
    (metric 12). Rows are the cash book (`CASH`)."""
    where = list(conditions)
    if start:
        where.append(CASH.c.paid_on >= start)
    if end:
        where.append(CASH.c.paid_on <= end)
    money_in, money_out = moved(db, *where)
    by = defaultdict(lambda: {'in': ZERO, 'out': ZERO})
    sources = defaultdict(lambda: {'in': ZERO, 'out': ZERO})
    for method, source, flow, amount in db.execute(select(CASH.c.method, CASH.c.source, CASH.c.flow,
            func.sum(CASH.c.amount)).where(COUNTED, *where).group_by(CASH.c.method, CASH.c.source, CASH.c.flow)):
        by[method][flow] += amount
        sources[source][flow] += amount
    return {'money_in': money_in, 'money_out': money_out, 'net': money_in - money_out,
            'by_method': [{'method': k, **v, 'net': v['in'] - v['out']} for k, v in sorted(by.items())],
            'by_source': {k: {**v, 'net': v['in'] - v['out']} for k, v in sources.items()}}


def recorded_net_cash(db):
    """Metric 11: every cash-method movement in minus every one out, since
    records began. Not a verified balance: no opening balance, count or
    account (M2.3); app money records no method, so it is not in here."""
    cash_in, cash_out = moved(db, CASH.c.method == 'cash')
    return cash_in - cash_out


# ---- trends (the overview's small charts) ------------------------------------

def balance_trends(db, today, days=30):
    """Owed to Omoterra and owed by Omoterra at the end of each of the last
    `days` days, oldest first, over the same population as receivables()
    and payables(): the last point is today's card. Cancelled debts and
    reversed payments are left out; a delivered app order whose delivery
    has no date counts as owed from before the window."""
    start = today - timedelta(days=days - 1)
    window = [start + timedelta(n) for n in range(days)]

    def ledger(direction):
        live = and_(m.LedgerDebt.direction == direction, m.LedgerDebt.status != 'cancelled')
        owed = dict(db.execute(select(m.LedgerDebt.incurred_on, func.sum(m.LedgerDebt.amount)).where(live)
            .group_by(m.LedgerDebt.incurred_on)).all())
        # A deposit paid before its order was delivered (M2.5) reduces the
        # sale's receivable from the day that receivable exists.
        on = func.greatest(m.LedgerPayment.paid_on, m.LedgerDebt.incurred_on)
        paid = dict(db.execute(select(on, func.sum(m.LedgerPayment.amount))
            .join(m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
            .where(live, m.LedgerPayment.reversed_at.is_(None)).group_by(on)).all())
        series, balance = [], (sum((v for d, v in owed.items() if d < start), ZERO)
            - sum((v for d, v in paid.items() if d < start), ZERO))
        for d in window:
            balance += owed.get(d, ZERO) - paid.get(d, ZERO)
            series.append(balance)
        return series

    received = defaultdict(list)
    for payment_id, on, amount in db.execute(select(m.PaymentReceipt.payment_id, local_day(m.PaymentReceipt.created_at),
            m.PaymentReceipt.amount)):
        received[payment_id].append((on, amount))
    for payment_id, on, amount in db.execute(select(m.Payment.id, local_day(m.Payment.paid_at), m.Payment.received_amount)
            .where(m.Payment.received_amount > 0, m.Payment.paid_at.is_not(None),
                   ~exists(select(m.PaymentReceipt.id).where(m.PaymentReceipt.payment_id == m.Payment.id)))):
        received[payment_id].append((on, amount))
    market = db.execute(select(m.Payment.id, m.Payment.amount, delivered_on()).join(m.Order, m.Order.id == m.Payment.order_id)
        .where(m.Order.internal_status.in_(RECOGNISED))).all()
    owed_to_me = ledger('receivable')
    for n, d in enumerate(window):
        for payment_id, amount, on in market:
            if on is None or on <= d:
                owed_to_me[n] += max(ZERO, amount - sum((a for day_, a in received[payment_id] if day_ <= d), ZERO))
    i_owe = ledger('payable')
    # App payouts (M2.7): owed from the day the settlement exists, less what
    # was debited (and not refunded) by each day.
    paid_by = defaultdict(list)
    for settlement_id, on, amount in db.execute(select(m.SettlementTransfer.settlement_id, m.SettlementTransfer.debited_on,
            m.SettlementTransfer.amount).where(m.SettlementTransfer.state == 'debited')):
        paid_by[settlement_id].append((on, amount))
    for settlement_id, on, amount in db.execute(select(m.SettlementRefund.settlement_id, m.SettlementRefund.refunded_on,
            -m.SettlementRefund.amount)):
        paid_by[settlement_id].append((on, amount))
    payouts = db.execute(select(m.Settlement.id, local_day(m.Settlement.created_at), m.Settlement.total_payable,
        m.Settlement.status, local_day(m.Settlement.paid_at)).where(m.Settlement.status != 'cancelled')).all()
    for settlement_id, _created, amount, status, paid_on in payouts:
        if status == 'paid' and not paid_by[settlement_id] and paid_on is not None:
            paid_by[settlement_id].append((paid_on, amount))  # marked paid before attempts existed
    payouts = [(settlement_id, created, amount) for settlement_id, created, amount, _status, _paid in payouts]
    for n, d in enumerate(window):
        for settlement_id, created, amount in payouts:
            if created <= d:
                i_owe[n] += max(ZERO, amount - sum((a for on, a in paid_by[settlement_id] if on <= d), ZERO))
    return {'owed_to_me': owed_to_me, 'i_owe': i_owe}


# ---- drilldown -----------------------------------------------------------------

METRICS = ('receivables', 'payables', 'commitments', 'revenue', 'cost_of_goods', 'expenses', 'stock_lost')


def rows_for(db, metric, start=None, end=None):
    """The rows behind one headline, newest first."""
    if metric == 'receivables':
        rows = receivables(db)['rows']
    elif metric == 'payables':
        rows = payables(db)['rows']
    elif metric == 'commitments':
        rows = commitments(db)['rows']
    else:
        rows = globals()[metric](db, start, end)['rows']
    return sorted(rows, key=lambda row: (row['date'] or date.min, row['key']), reverse=True)
