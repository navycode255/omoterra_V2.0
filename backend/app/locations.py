"""Owned assets and location trading. Transfers move stock, never create a
second supplier bill. Location sales/expenses use the existing finance ledger.
Straight-line depreciation is non-cash and is included in business profit.
"""
from calendar import monthrange
from datetime import date, timedelta
from decimal import Decimal
from typing import Optional, Literal, Annotated

from fastapi import APIRouter, Depends, Header
from pydantic import Field, model_validator, field_validator
from sqlalchemy import select, func

from . import auth, contracts as c, models as m, services as s
from .db import database
from .i18n import fail as error

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')
Cost = Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=2)]


def whole_quantity(unit, quantity):
    if unit in ('bird', 'animal', 'tray', 'piece') and quantity != quantity.to_integral_value():
        error('err.location_whole_quantity', 422)


def result(value, status=200):
    from .main import result as respond
    return respond(value, status)


class LocationInput(c.Input):
    name: str = Field(min_length=2, max_length=150)
    address: str = Field(default='', max_length=500)
    notes: str = Field(default='', max_length=2000)
    daily_target: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] = ZERO
    active: bool = True


class AssetInput(c.Input):
    name: str = Field(min_length=2, max_length=150)
    purchased_on: date
    cost: Cost
    residual_value: Cost = ZERO
    useful_months: int = Field(ge=1, le=1200)
    depreciation_start: date
    notes: str = Field(default='', max_length=2000)

    @model_validator(mode='after')
    def valid(self):
        if self.residual_value > self.cost or self.depreciation_start < self.purchased_on:
            error('err.location_asset_cost_dates', 422)
        c._not_future(self.purchased_on)
        return self


class InvestmentInput(c.Input):
    invested_on: date
    description: str = Field(min_length=2, max_length=500)
    amount: c.Money

    @field_validator('invested_on')
    @classmethod
    def past(cls, value):
        return c._not_future(value)


class AllocationInput(c.Input):
    allocated_on: date
    category: c.Category = 'broilers'
    description: str = Field(default='', max_length=200)
    unit: Literal['bird', 'animal', 'kg', 'tray', 'piece'] = 'bird'
    quantity: c.Quantity
    unit_cost: Optional[Cost] = None
    opening_source_id: Optional[str] = Field(default=None, max_length=36)
    lpo_line_id: Optional[str] = Field(default=None, max_length=36)
    supplier_collection_id: Optional[str] = Field(default=None, max_length=36)
    notes: str = Field(default='', max_length=2000)

    @model_validator(mode='after')
    def valid(self):
        c._not_future(self.allocated_on)
        if sum(bool(v) for v in (self.lpo_line_id, self.supplier_collection_id, self.opening_source_id)) > 1:
            error('err.location_one_receipt', 422)
        if not self.lpo_line_id and not self.supplier_collection_id and not self.opening_source_id and self.unit_cost is None:
            error('err.location_opening_cost', 422)
        if (self.lpo_line_id or self.supplier_collection_id or self.opening_source_id) and self.unit_cost is not None:
            error('err.location_receipt_cost', 422)
        return self


class StockEventInput(c.Input):
    occurred_on: date
    kind: Literal['returned', 'lost']
    quantity: c.Quantity
    note: str = Field(min_length=3, max_length=500)

    @field_validator('occurred_on')
    @classmethod
    def past(cls, value):
        return c._not_future(value)


class LocationSaleInput(c.Input):
    allocation_id: str = Field(max_length=36)
    sold_on: date
    quantity: c.Quantity
    unit_price: c.Money
    payment: Optional[c.LedgerPaymentInput] = None
    notes: str = Field(default='', max_length=2000)


class RetirementInput(c.Input):
    retired_on: date
    reason: str = Field(min_length=3, max_length=500)

    @field_validator('retired_on')
    @classmethod
    def past(cls, value):
        return c._not_future(value)


def location(db, id, active=False, lock=False):
    query = select(m.OperatingLocation).where(m.OperatingLocation.id == id)
    row = db.scalar(query.with_for_update() if lock else query)
    if not row:
        error('err.location_not_found', 404)
    if active and not row.active:
        error('err.location_closed', 422)
    return row


def view(row, keys):
    return {key: getattr(row, key) for key in ('id', 'created_at', *keys)}


def location_view(row):
    return view(row, ('name', 'address', 'notes', 'daily_target', 'active'))


def asset_view(row, as_of=None):
    accumulated = asset_accrued(row, as_of or c.business_today())
    return {**view(row, ('location_id', 'name', 'purchased_on', 'cost', 'residual_value', 'useful_months', 'depreciation_start', 'retired_on', 'notes')),
            'monthly_depreciation': s.money((row.cost - row.residual_value) / row.useful_months),
            'accumulated_depreciation': accumulated, 'book_value': row.cost - accumulated}


def add_months(value, months):
    year, month = divmod(value.year * 12 + value.month - 1 + months, 12)
    return date(year, month + 1, min(value.day, monthrange(year, month + 1)[1]))


def asset_accrued(asset, on):
    finish = add_months(asset.depreciation_start, asset.useful_months) - timedelta(days=1)
    if asset.retired_on:
        finish = min(finish, asset.retired_on - timedelta(days=1))
    on = min(on, finish)
    if on < asset.depreciation_start:
        return ZERO
    monthly = (asset.cost - asset.residual_value) / asset.useful_months
    months = (on.year - asset.depreciation_start.year) * 12 + on.month - asset.depreciation_start.month
    if on < add_months(asset.depreciation_start, months):
        months -= 1
    boundary = add_months(asset.depreciation_start, months)
    next_boundary = add_months(asset.depreciation_start, months + 1)
    fraction = Decimal((on - boundary).days + 1) / (next_boundary - boundary).days
    return min(asset.cost - asset.residual_value, s.money(monthly * (months + fraction)))


def depreciation_rows(assets, start, end):
    """Straight line from the service anniversary, prorated by days. Differences
    of rounded cumulative values keep reports additive across date splits.
    """
    rows = []
    for asset in assets:
        finish = add_months(asset.depreciation_start, asset.useful_months) - timedelta(days=1)
        if asset.retired_on:
            finish = min(finish, asset.retired_on - timedelta(days=1))
        first, last = max(start, asset.depreciation_start), min(end, finish)
        if first > last:
            continue
        previous = asset_accrued(asset, first - timedelta(days=1))
        for n in range((last - first).days + 1):
            day = first + timedelta(days=n)
            accumulated = asset_accrued(asset, day)
            amount = accumulated - previous
            previous = accumulated
            if amount:
                rows.append({'asset_id': asset.id, 'location_id': asset.location_id, 'date': day, 'amount': amount,
                             'description': f'Depreciation · {asset.name}'})
    return rows


def transferred(db, column, source_id):
    return db.scalar(select(func.coalesce(func.sum(m.LocationAllocation.quantity - m.LocationAllocation.returned_quantity), 0))
        .where(column == source_id)) or ZERO


def opening_return_stock(db, row):
    if not row.returned_quantity:
        return ZERO
    return row.returned_quantity - transferred(db, m.LocationAllocation.opening_source_id, row.id)


@router.get('/location-opening-stock')
def opening_stock(operator=Depends(auth.ops), db=Depends(database)):
    rows = []
    for allocation in db.scalars(select(m.LocationAllocation).where(m.LocationAllocation.lpo_line_id.is_(None), m.LocationAllocation.supplier_collection_id.is_(None), m.LocationAllocation.opening_source_id.is_(None))):
        available = opening_return_stock(db, allocation)
        if available > 0:
            rows.append({'id': allocation.id, 'description': allocation.description, 'unit': allocation.unit, 'unit_cost': allocation.unit_cost, 'on_hand': available})
    return result(rows)


def allocation_views(db, rows):
    if not rows:
        return []
    ids = [row.id for row in rows]
    sold = dict(db.execute(select(m.SaleItem.location_allocation_id, func.sum(m.SaleItem.quantity)).join(m.Sale)
        .where(m.SaleItem.location_allocation_id.in_(ids), m.Sale.status == 'active')
        .group_by(m.SaleItem.location_allocation_id)).all())
    lost = dict(db.execute(select(m.LocationStockEvent.allocation_id, func.sum(m.LocationStockEvent.quantity))
        .where(m.LocationStockEvent.allocation_id.in_(ids), m.LocationStockEvent.kind == 'lost')
        .group_by(m.LocationStockEvent.allocation_id)).all())
    return [{**view(row, ('location_id', 'allocated_on', 'category', 'description', 'unit', 'quantity', 'unit_cost',
                        'returned_quantity', 'lpo_line_id', 'supplier_collection_id', 'opening_source_id', 'notes')),
            'sold': sold.get(row.id, ZERO), 'lost': lost.get(row.id, ZERO),
            'on_hand': row.quantity - row.returned_quantity - sold.get(row.id, ZERO) - lost.get(row.id, ZERO)} for row in rows]


def allocation_view(db, row):
    return allocation_views(db, [row])[0]


def take_location_stock(db, line, location_id, sold_on, taken=ZERO):
    row = db.scalar(select(m.LocationAllocation).where(m.LocationAllocation.id == line.location_allocation_id).with_for_update())
    if not row or row.location_id != location_id:
        error('err.location_allocation_required', 422)
    if sold_on < row.allocated_on:
        error('err.location_sale_before_allocation', 422)
    if line.quantity > allocation_view(db, row)['on_hand'] - taken:
        error('err.location_insufficient_stock', 422)
    return row


@router.get('/locations')
def locations(start: Optional[date] = None, end: Optional[date] = None, operator=Depends(auth.ops), db=Depends(database)):
    start, end = period(start, end)
    return result({'start': start, 'end': end, 'items': [performance(db, row, start, end) for row in db.scalars(select(m.OperatingLocation).order_by(m.OperatingLocation.name))]})


def period(start, end):
    end = end or c.business_today()
    start = start or end.replace(day=1)
    if start > end or end > c.business_today() or (end - start).days > 366:
        error('err.location_valid_period', 422)
    return start, end


@router.post('/locations', status_code=201)
def create_location(data: LocationInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'location', idempotency_key, data.model_dump())
    if prior:
        return result(location_view(location(db, prior)), 201)
    if db.scalar(select(m.OperatingLocation.id).where(func.lower(m.OperatingLocation.name) == data.name.lower())):
        error('err.location_duplicate_name', 422)
    row = m.OperatingLocation(**data.model_dump(), created_by=operator.id)
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(location_view(row), 201)


@router.put('/locations/{id}')
def update_location(id: str, data: LocationInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    row = location(db, id, lock=True)
    if db.scalar(select(m.OperatingLocation.id).where(func.lower(m.OperatingLocation.name) == data.name.lower(), m.OperatingLocation.id != id)):
        error('err.location_duplicate_name', 422)
    for name, value in data.model_dump().items():
        setattr(row, name, value)
    return result(location_view(row))


@router.get('/locations/{id}')
def detail(id: str, start: Optional[date] = None, end: Optional[date] = None, operator=Depends(auth.ops), db=Depends(database)):
    row = location(db, id)
    start, end = period(start, end)
    return result({**performance(db, row, start, end), 'start': start, 'end': end,
        'assets': [asset_view(a, end) for a in db.scalars(select(m.BusinessAsset).where(m.BusinessAsset.location_id == id).order_by(m.BusinessAsset.purchased_on))],
        'investments': [view(i, ('invested_on', 'description', 'amount')) for i in db.scalars(select(m.LocationInvestment).where(m.LocationInvestment.location_id == id).order_by(m.LocationInvestment.invested_on.desc()))],
        'allocations': allocation_views(db, list(db.scalars(select(m.LocationAllocation).where(m.LocationAllocation.location_id == id).order_by(m.LocationAllocation.allocated_on.desc())))),
        'stock_events': [view(e, ('allocation_id', 'occurred_on', 'kind', 'quantity', 'note')) for e in db.scalars(select(m.LocationStockEvent).join(m.LocationAllocation).where(m.LocationAllocation.location_id == id).order_by(m.LocationStockEvent.occurred_on.desc()))]})


@router.post('/locations/{id}/assets', status_code=201)
def create_asset(id: str, data: AssetInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'asset', idempotency_key, {'location_id': id, **data.model_dump()})
    if prior:
        return result(asset_view(db.get(m.BusinessAsset, prior)), 201)
    location(db, id, active=True)
    row = m.BusinessAsset(location_id=id, **data.model_dump(), created_by=operator.id)
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(asset_view(row), 201)


@router.post('/assets/{id}/retire')
def retire_asset(id: str, data: RetirementInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'asset-retire', idempotency_key, {'asset_id': id, **data.model_dump()})
    if prior:
        return result(asset_view(db.get(m.BusinessAsset, prior)))
    row = db.scalar(select(m.BusinessAsset).where(m.BusinessAsset.id == id).with_for_update())
    if not row:
        error('err.location_asset_not_found', 404)
    c._not_future(data.retired_on)
    if data.retired_on < row.depreciation_start:
        error('err.location_retirement_before_service', 422)
    if row.retired_on:
        error('err.location_already_retired', 422)
    row.retired_on = data.retired_on
    row.notes = (row.notes + '\nRetired: ' + data.reason).strip()
    s.remember(db, key, fingerprint, row.id)
    return result(asset_view(row))


@router.post('/locations/{id}/investments', status_code=201)
def create_investment(id: str, data: InvestmentInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'location-investment', idempotency_key, {'location_id': id, **data.model_dump()})
    if prior:
        return result(view(db.get(m.LocationInvestment, prior), ('invested_on', 'description', 'amount')), 201)
    location(db, id, active=True)
    row = m.LocationInvestment(location_id=id, **data.model_dump(), created_by=operator.id)
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(view(row, ('invested_on', 'description', 'amount')), 201)


@router.post('/locations/{id}/allocations', status_code=201)
def allocate(id: str, data: AllocationInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'location-stock', idempotency_key, {'location_id': id, **data.model_dump()})
    if prior:
        return result(allocation_view(db, db.get(m.LocationAllocation, prior)), 201)
    location(db, id, active=True)
    values = data.model_dump()
    if not data.lpo_line_id and not data.supplier_collection_id and not data.opening_source_id and operator.role != 'admin':
        error('err.location_opening_admin', 403)
    if data.opening_source_id:
        source = db.scalar(select(m.LocationAllocation).where(m.LocationAllocation.id == data.opening_source_id).with_for_update())
        if not source or source.lpo_line_id or source.supplier_collection_id or source.opening_source_id:
            error('err.location_returned_opening_required', 422)
        if data.allocated_on < source.allocated_on or data.quantity > opening_return_stock(db, source):
            error('err.location_returned_opening_available', 422)
        values.update(category=source.category, unit=source.unit, unit_cost=source.unit_cost, description=source.description)
    elif data.supplier_collection_id:
        from .batch_stock import take_collection_stock
        receipt, batch = take_collection_stock(db, data.supplier_collection_id, data.quantity)
        if data.allocated_on < receipt.received_on:
            error('err.location_allocation_before_receipt', 422)
        values.update(category=batch.category, unit=c.UNITS[batch.category], unit_cost=receipt.unit_cost)
    elif data.lpo_line_id:
        from .purchasing import take_stock
        receipt, _ = take_stock(db, data.lpo_line_id, data.quantity)
        earliest = db.scalar(select(func.min(m.LpoReceipt.received_on)).join(m.LpoReceiptLine)
            .where(m.LpoReceiptLine.lpo_line_id == receipt.id, m.LpoReceipt.cancelled_at.is_(None)))
        if earliest and data.allocated_on < earliest:
            error('err.location_allocation_before_receipt', 422)
        values.update(category=receipt.category or data.category, unit=receipt.unit, unit_cost=receipt.unit_price)
    whole_quantity(values['unit'], data.quantity)
    values['description'] = values['description'] or values['category'].replace('_', ' ')
    # Moving received stock to a kitchen is replayed by date like a sale (R8, M2.2).
    from .lots import StockGuard
    guard = StockGuard(db).watch('supplier_collections', data.supplier_collection_id).watch('lpo_lines', data.lpo_line_id)
    row = m.LocationAllocation(location_id=id, **values, created_by=operator.id)
    db.add(row); guard.check(); s.remember(db, key, fingerprint, row.id)
    return result(allocation_view(db, row), 201)


@router.post('/locations/{id}/stock-events', status_code=201)
def stock_event(id: str, data: StockEventInput, allocation_id: str, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'location-stock-event', idempotency_key, {'location_id': id, 'allocation_id': allocation_id, **data.model_dump()})
    if prior:
        return result(view(db.get(m.LocationStockEvent, prior), ('allocation_id', 'occurred_on', 'kind', 'quantity', 'note')), 201)
    row = db.scalar(select(m.LocationAllocation).where(m.LocationAllocation.id == allocation_id).with_for_update())
    if not row or row.location_id != id:
        error('err.location_allocation_not_found', 404)
    whole_quantity(row.unit, data.quantity)
    if data.occurred_on < row.allocated_on or data.quantity > allocation_view(db, row)['on_hand']:
        error('err.location_stock_event_available', 422)
    if data.kind == 'returned':
        # Lock the original receipt too, serializing the central on-hand increase.
        if row.supplier_collection_id:
            db.scalar(select(m.SupplierCollection).where(m.SupplierCollection.id == row.supplier_collection_id).with_for_update())
        if row.opening_source_id:
            db.scalar(select(m.LocationAllocation).where(m.LocationAllocation.id == row.opening_source_id).with_for_update())
        if row.lpo_line_id:
            db.scalar(select(m.LpoLine).where(m.LpoLine.id == row.lpo_line_id).with_for_update())
        row.returned_quantity += data.quantity
    event = m.LocationStockEvent(allocation_id=row.id, **data.model_dump(), created_by=operator.id)
    db.add(event); db.flush(); s.remember(db, key, fingerprint, event.id)
    return result(view(event, ('allocation_id', 'occurred_on', 'kind', 'quantity', 'note')), 201)


@router.post('/locations/{id}/sales', status_code=201)
def daily_sale(id: str, data: LocationSaleInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    from .finance import create_sale
    loc = location(db, id, active=True, lock=True)
    buyer_name = f'Walk-in sales · {loc.name}'
    profile = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.business_name == buyer_name, m.BuyerProfile.user_id.is_(None)))
    if not profile:
        profile = m.BuyerProfile(business_name=buyer_name, contact_person='', phone='', region='', buyer_type='personal')
        db.add(profile); db.flush()
    payload = c.DirectSaleInput(location_id=id, buyer_profile_id=profile.id, sold_on=data.sold_on, notes=data.notes,
        items=[c.SaleItemInput(location_allocation_id=data.allocation_id, quantity=data.quantity, unit_price=data.unit_price)], payment=data.payment)
    return create_sale(payload, idempotency_key, operator, db)


def performance(db, loc, start, end):
    """Location-specific accrual profit. Unassigned business costs stay shared."""
    assets = list(db.scalars(select(m.BusinessAsset).where(m.BusinessAsset.location_id == loc.id)))
    investment = sum((a.cost for a in assets if a.purchased_on <= end), ZERO)
    investment += db.scalar(select(func.coalesce(func.sum(m.LocationInvestment.amount), 0))
        .where(m.LocationInvestment.location_id == loc.id, m.LocationInvestment.invested_on <= end)) or ZERO
    days = {}
    def day(on):
        return days.setdefault(on, {'date': on, 'revenue': ZERO, 'stock_cost': ZERO, 'labour': ZERO, 'running_costs': ZERO,
                                    'depreciation': ZERO, 'stock_lost': ZERO, 'allocated': {}, 'sold': {}})
    query = select(m.SaleItem, m.Sale).join(m.Sale).where(m.Sale.location_id == loc.id, m.Sale.status == 'active', m.Sale.sold_on.between(start, end))
    unknown = 0
    sale_ids = set()
    for item, sale in db.execute(query):
        d = day(sale.sold_on); d['revenue'] += item.subtotal
        d['stock_cost'] += ZERO if item.cost_state == 'unknown' else item.cost_total or ZERO
        unknown += int(item.cost_state == 'unknown'); sale_ids.add(sale.id)
        key = f'{item.category}:{item.unit}'; d['sold'][key] = d['sold'].get(key, ZERO) + item.quantity
    attributed = func.coalesce(m.LedgerDebt.location_id, m.Sale.location_id)
    for debt in db.scalars(select(m.LedgerDebt).outerjoin(m.Sale, m.Sale.id == m.LedgerDebt.sale_id)
        .where(attributed == loc.id, m.LedgerDebt.source == 'expense', m.LedgerDebt.status != 'cancelled', m.LedgerDebt.incurred_on.between(start, end))):
        d = day(debt.incurred_on); d['labour' if debt.expense_category == 'labour' else 'running_costs'] += debt.amount
    for row in depreciation_rows(assets, start, end):
        day(row['date'])['depreciation'] += row['amount']
    allocations = list(db.scalars(select(m.LocationAllocation).where(m.LocationAllocation.location_id == loc.id)))
    for row in allocations:
        if start <= row.allocated_on <= end:
            d = day(row.allocated_on); key = f'{row.category}:{row.unit}'; d['allocated'][key] = d['allocated'].get(key, ZERO) + row.quantity
    for event, allocation in db.execute(select(m.LocationStockEvent, m.LocationAllocation).join(m.LocationAllocation)
        .where(m.LocationAllocation.location_id == loc.id, m.LocationStockEvent.kind == 'lost', m.LocationStockEvent.occurred_on.between(start, end))):
        day(event.occurred_on)['stock_lost'] += s.money(event.quantity * allocation.unit_cost)
    for d in days.values():
        d['profit_before_depreciation'] = d['revenue'] - d['stock_cost'] - d['labour'] - d['running_costs'] - d['stock_lost']
        d['net_profit'] = d['profit_before_depreciation'] - d['depreciation']
    totals = {key: sum((d[key] for d in days.values()), ZERO) for key in
        ('revenue', 'stock_cost', 'labour', 'running_costs', 'stock_lost', 'depreciation', 'profit_before_depreciation', 'net_profit')}
    on_hand = {}
    for allocation in allocation_views(db, allocations):
        key = f"{allocation['category']}:{allocation['unit']}"
        on_hand[key] = on_hand.get(key, ZERO) + allocation['on_hand']
    return {**location_view(loc), **totals, 'investment': investment, 'sale_count': len(sale_ids), 'unknown_cost_lines': unknown,
            'period_return_pct': s.money(totals['net_profit'] / investment * 100) if investment else None,
            'on_hand': on_hand, 'days': sorted(days.values(), key=lambda d: d['date'], reverse=True)}
