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

Recognition (decision D2): a direct sale counts on its sale date; an app
order counts on the day it was delivered (Dar es Salaam time), read from its
activity log until M2.5 stores it. A delivered order without a dated
"Delivered" entry is *unresolved*: listed, and kept out of period revenue and
cost (R5, R6). An order not yet delivered is a *commitment*, reported on its
own and never as revenue or as money owed to Omoterra.

Cost states (M1.3, rule R5): a sale line's buying cost is known, free (a
known zero an admin approved) or unknown. An unknown line counts for nothing
in cost of goods and makes every period containing it `provisional`:
profit is shown as "Provisional: buying costs incomplete" with the sales and
revenue affected, never as a final, minimum or range figure.

Not yet here (later milestones): money accounts and a verified cash balance
(M2.3); payout attempts and disputed exposure from them (M2.7).
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import Date, Integer, String, Text, and_, case, cast, exists, func, literal, literal_column, null, or_, select, union_all

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
    """The day an app order reached 'delivered', from its activity log (null
    when the log has no such entry). M2.5 replaces it with a stored column."""
    return literal_column(
        "(SELECT min(CAST(timezone('Africa/Dar_es_Salaam', CAST(entry->>'at' AS timestamptz)) AS date))"
        " FROM json_array_elements(CAST(orders.activity AS json)) AS entry WHERE entry->>'label' = 'Delivered')",
        Date)


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
    """App orders not delivered yet (and not cancelled): ordered value, the
    part still unpaid and any money the buyer paid ahead (a customer
    deposit). Never revenue and never a receivable."""
    rows = []
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
            'count': len(rows), 'rows': rows}


def payables(db, supplier_ids=None):
    """Owed by Omoterra now (metric 2): open ledger payables (sale costs,
    delivery notes, LPO receipts, manual debts, expenses) plus app payouts
    still pending. Beside it, never netted: payouts a supplier says never
    arrived (disputed), and money suppliers hold from transfers as credit
    or not yet classified (unresolved)."""
    today = c.business_today()
    query = select(m.LedgerDebt).where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open')
    settlements = (select(m.Settlement, delivered_on()).join(m.OrderItem, m.OrderItem.id == m.Settlement.order_item_id)
        .join(m.Order, m.Order.id == m.OrderItem.order_id).where(m.Settlement.status == 'pending'))
    disputed = select(m.Settlement).where(m.Settlement.status == 'paid', m.Settlement.supplier_confirmation == 'not_received')
    if supplier_ids is not None:
        supplier_ids = list(supplier_ids)
        query = query.where(m.LedgerDebt.supplier_id.in_(supplier_ids))
        settlements = settlements.where(m.Settlement.supplier_id.in_(supplier_ids))
        disputed = disputed.where(m.Settlement.supplier_id.in_(supplier_ids))
    rows = [_ledger_row(debt, today) for debt in db.scalars(query)]
    pending = db.execute(settlements).all()
    names = _supplier_names(db, [row.supplier_id for row, _on in pending])
    for row, delivered in pending:
        rows.append(_settlement_row(row, names, local_day_of(row.created_at), delivered, today))
    rows = dedupe(rows)
    held = tr.by_supplier(db, supplier_ids)
    disputes = db.scalars(disputed).all()
    return {**_split(rows), 'overdue': total(r for r in rows if r['overdue']),
            'overdue_count': sum(1 for r in rows if r['overdue']),
            'disputed': sum((row.total_payable for row in disputes), ZERO), 'disputed_count': len(disputes),
            'credit': sum((row['credit'] for row in held.values()), ZERO),
            'unresolved': sum((row['unresolved'] for row in held.values()), ZERO), 'rows': rows}


def _settlement_row(row, names, on, delivered=None, today=None):
    """An app payout, due PAYOUT_DAYS after its order was delivered; an
    undelivered order's payout has no due date yet."""
    due = delivered + timedelta(days=PAYOUT_DAYS) if delivered else None
    return _row('marketplace', 'settlements', row.id, on, row.total_payable,
        party=names.get(row.supplier_id, 'Supplier'), party_phone='', party_kind='supplier', party_key=row.supplier_id,
        buyer_profile_id=None, supplier_id=row.supplier_id, description='App order payout', due_on=due,
        overdue=due is not None and today is not None and due < today, order_item_id=row.order_item_id, href='/settlements')


def settlement_totals(db):
    """App payouts (metric 5): pending, paid to date, and paid ones the
    supplier says never arrived (shown separately until M2.7)."""
    rows = {status: (amount, n) for status, amount, n in db.execute(select(m.Settlement.status,
        func.coalesce(func.sum(m.Settlement.total_payable), 0), func.count()).group_by(m.Settlement.status))}
    disputed = db.execute(select(func.coalesce(func.sum(m.Settlement.total_payable), 0), func.count())
        .where(m.Settlement.status == 'paid', m.Settlement.supplier_confirmation == 'not_received')).one()
    pending, paid = rows.get('pending', (ZERO, 0)), rows.get('paid', (ZERO, 0))
    return {'pending': pending[0], 'pending_count': pending[1], 'paid': paid[0], 'paid_count': paid[1],
            'disputed': disputed[0], 'disputed_count': disputed[1]}


def supplier_totals(db, supplier_ids=None):
    """Per registered supplier, from their non-cancelled payables: bought,
    paid (allocated), owed, open invoices, due now (incl. overdue and
    undated), overdue; app payouts pending and paid beside them; credit and
    unresolved money on their transfers. The staff statement, Supplier
    payments, the Suppliers list and the portal all read these figures."""
    today = c.business_today()
    query = select(m.LedgerDebt).where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status != 'cancelled',
        m.LedgerDebt.supplier_id.is_not(None))
    settlements = select(m.Settlement.supplier_id, m.Settlement.status, func.sum(m.Settlement.total_payable)).group_by(
        m.Settlement.supplier_id, m.Settlement.status)
    if supplier_ids is not None:
        supplier_ids = list(supplier_ids)
        query = query.where(m.LedgerDebt.supplier_id.in_(supplier_ids))
        settlements = settlements.where(m.Settlement.supplier_id.in_(supplier_ids))
    blank = lambda: {'bought': ZERO, 'paid': ZERO, 'owed': ZERO, 'open_invoices': 0, 'due_now': ZERO,
        'overdue': ZERO, 'earliest_due': None, 'undated': False, 'settlements_pending': ZERO,
        'settlements_paid': ZERO, 'credit': ZERO, 'unresolved': ZERO}
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
    for supplier_id, status, amount in db.execute(settlements):
        if status in ('pending', 'paid'):
            out[supplier_id][f'settlements_{status}'] += amount or ZERO
    for supplier_id, held in tr.by_supplier(db, supplier_ids).items():
        out[supplier_id]['credit'] = held['credit']
        out[supplier_id]['unresolved'] = held['unresolved']
    return dict(out)


# ---- sales, cost and profit (metrics 6, 7, 13 to 16) ---------------------------

def _orders_recognised(db):
    """Delivered app orders with their delivery day (None: unresolved)."""
    return db.execute(select(m.Order, delivered_on()).where(m.Order.internal_status.in_(RECOGNISED))).all()


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
    rows = dedupe(rows)
    return {'total': total(rows), 'direct': total(r for r in rows if r['source'] == 'ledger'),
            'marketplace': total(r for r in rows if r['source'] == 'marketplace'),
            'direct_count': sum(1 for r in rows if r['source'] == 'ledger'),
            'marketplace_count': sum(1 for r in rows if r['source'] == 'marketplace'), 'count': len(rows),
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
    return {'sales_total': direct + total(market), 'direct_total': direct, 'sales_count': count,
            'unknown_cost': {'lines': lines, 'sales': affected, 'revenue': affected_revenue},
            'provisional': lines > 0,
            'marketplace_total': total(market), 'marketplace_count': len(market),
            'received': db.scalar(paid) or ZERO, 'buyer_owes': buyer_owes, 'buyer_owes_count': owing,
            'supplier_owed': supplier_owed, 'supplier_owed_count': supplier_sales,
            'expenses_owed': expenses_owed, 'expenses_owed_count': expense_sales,
            'commitments': {k: pending[k] for k in ('total', 'unpaid', 'deposits', 'count')}}


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
            m.OrderItem.id == m.Settlement.order_item_id).where(m.OrderItem.order_id.in_(list(orders)))).all()
        names = _supplier_names(db, [row.supplier_id for row, _order in settled])
        for row, order_id in settled:
            rows.append({**_settlement_row(row, names, orders[order_id]), 'cost_state': 'known',
                'order_id': order_id, 'description': f'App order {order_id[:8].upper()} payout',
                'href': f'/orders/{order_id}'})
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
    stolen, spoiled, or not recovered from a cancelled or reduced sale)."""
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
    - supplier payouts, on the day they were marked paid. A payout re-sent
      after "not received" overwrites the first one's date until M2.7.

    `flow` is 'in' or 'out'; `kind` is payment, allocation (a reversed one),
    transfer, refund, receipt or payout; `source` is ledger or marketplace."""
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
        .where(or_(P.supplier_payment_id.is_(None), P.reversed_at.is_not(None))))
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
    payouts = (select(ST.id, text_('payout'), text_('out'), local_day(ST.paid_at), ST.total_payable,
            text_('app_payout'), func.coalesce(ST.payment_reference, text_('')), text_(''), supplier,
            func.concat(text_('Payout for app order '), func.upper(func.substr(OI.order_id, 1, 8))),
            nothing(String(36)), nothing(String(36)), ST.supplier_id, nothing(String(36)), cast(literal(0), Integer),
            ST.paid_at, nothing(String(36)), nothing(when), nothing(String(36)), text_(''), text_('marketplace'),
            text_('settlements'), OI.order_id)
        .join(OI, OI.id == ST.order_item_id).join(U, U.id == ST.supplier_id).outerjoin(S, S.user_id == ST.supplier_id)
        .where(ST.status == 'paid', ST.paid_at.is_not(None)))
    return union_all(payments, transfers, refunds, receipts, paid_now, payouts).subquery('cash_movements')


CASH = _cash_movements()
COUNTED = CASH.c.reversed_at.is_(None)


def moved(db, *conditions):
    """Money in and out over the counted movements matching the conditions."""
    rows = db.execute(select(CASH.c.flow, func.coalesce(func.sum(CASH.c.amount), 0))
        .where(COUNTED, *conditions).group_by(CASH.c.flow)).all()
    totals = {flow: amount for flow, amount in rows}
    return totals.get('in', ZERO), totals.get('out', ZERO)


def disputed_out(db, *conditions):
    """App payouts inside the matching money out that the supplier says
    never arrived. They stay money out (rule R3: a recorded outflow is never
    removed) and are shown beside it until payout attempts (M2.7) settle
    whether the debit happened."""
    disputed = select(m.Settlement.id).where(m.Settlement.supplier_confirmation == 'not_received')
    amount, count = db.execute(select(func.coalesce(func.sum(CASH.c.amount), 0), func.count())
        .where(COUNTED, CASH.c.source_table == 'settlements', CASH.c.id.in_(disputed), *conditions)).one()
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
        paid = dict(db.execute(select(m.LedgerPayment.paid_on, func.sum(m.LedgerPayment.amount))
            .join(m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
            .where(live, m.LedgerPayment.reversed_at.is_(None)).group_by(m.LedgerPayment.paid_on)).all())
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
    payouts = db.execute(select(local_day(m.Settlement.created_at), m.Settlement.status, local_day(m.Settlement.paid_at),
        m.Settlement.total_payable)).all()
    for n, d in enumerate(window):
        for created, status, paid_on, amount in payouts:
            if created <= d and (status == 'pending' or (paid_on is not None and paid_on > d)):
                i_owe[n] += amount
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
