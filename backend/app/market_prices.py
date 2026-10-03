"""Market prices by weight band, published by operations for suppliers.

A price list holds one category's bands from `effective_from`. Lists are
never edited: an admin publishes a new list (today or a future date) or
withdraws one. For each category the current list is the newest one already
in effect that is not withdrawn; when two share an effective date, the one
published later wins. Every list stays in the history.

A band covers min_weight_kg <= weight < max_weight_kg; a missing bound is
open on that side. Bands never overlap (contracts.MarketPriceListInput);
gaps between them are allowed and reported so operations can see weights
that have no price.
"""
from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import func, select

from . import auth, contracts as c, models as m, notifications as notes, services as s
from .db import database
from .i18n import M, fail

router = APIRouter(prefix='/api/v1')
supplier = auth.role('supplier')
CATEGORIES = list(c.UNITS)
MAX_DAYS_AHEAD = 90


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def _bands(db, list_ids):
    rows = db.scalars(select(m.MarketPriceBand).where(m.MarketPriceBand.price_list_id.in_(list_ids))
        .order_by(m.MarketPriceBand.position)).all() if list_ids else []
    grouped = {}
    for row in rows:
        grouped.setdefault(row.price_list_id, []).append(row)
    return grouped


def _gaps(bands):
    return [{'from_kg': lower.max_weight_kg, 'to_kg': upper.min_weight_kg}
            for lower, upper in zip(bands, bands[1:]) if lower.max_weight_kg < upper.min_weight_kg]


def _same_range(a, b):
    return a.min_weight_kg == b.min_weight_kg and a.max_weight_kg == b.max_weight_kg


class Timeline:
    """Every list of the given categories, with each one's status worked out
    once: current, scheduled, superseded or withdrawn."""

    def __init__(self, db, categories=None):
        query = select(m.MarketPriceList)
        if categories is not None:
            query = query.where(m.MarketPriceList.category.in_(categories))
        self.lists = db.scalars(query.order_by(m.MarketPriceList.effective_from, m.MarketPriceList.created_at)).all()
        self.bands = _bands(db, [row.id for row in self.lists])
        operators = {row.published_by for row in self.lists} | {row.withdrawn_by for row in self.lists}
        operators.discard(None)
        self.names = dict(db.execute(select(m.Operator.id, m.Operator.name).where(m.Operator.id.in_(operators))).all()) \
            if operators else {}
        today = c.business_today()
        self.status, self.current, self.upcoming, self.previous = {}, {}, {}, {}
        live, last = {}, {}
        for row in self.lists:
            if row.withdrawn_at:
                self.status[row.id] = 'withdrawn'
                continue
            # Ordered by date then publication, so a later list on the same day replaces an earlier one.
            # Prices are compared with the list published just before, even on the same day.
            if row.category in last:
                self.previous[row.id] = last[row.category]
            last[row.category] = row
            day = live.setdefault(row.category, {})
            replaced = day.get(row.effective_from)
            if replaced:
                self.status[replaced.id] = 'superseded'
            day[row.effective_from] = row
        for category, by_day in live.items():
            effective = [by_day[key] for key in sorted(by_day)]
            past = [row for row in effective if row.effective_from <= today]
            for row in past[:-1]:
                self.status[row.id] = 'superseded'
            if past:
                self.current[category] = past[-1]
                self.status[past[-1].id] = 'current'
            self.upcoming[category] = [row for row in effective if row.effective_from > today]
            for row in self.upcoming[category]:
                self.status[row.id] = 'scheduled'

    def view(self, row, ops=False):
        bands = self.bands.get(row.id, [])
        before = self.bands.get(self.previous[row.id].id, []) if row.id in self.previous else []
        def band(b):
            match = next((p for p in before if _same_range(p, b)), None)
            return {'label': b.label, 'min_weight_kg': b.min_weight_kg, 'max_weight_kg': b.max_weight_kg,
                    'price_per_unit': b.price_per_unit, 'previous_price': match.price_per_unit if match else None}
        view = {'id': row.id, 'category': row.category, 'unit_type': row.unit_type,
                'effective_from': row.effective_from, 'published_at': row.created_at, 'note': row.note,
                'status': self.status.get(row.id, 'superseded'), 'bands': [band(b) for b in bands], 'gaps': _gaps(bands)}
        if ops:
            view.update({'published_by': self.names.get(row.published_by, ''), 'withdrawn_at': row.withdrawn_at,
                         'withdrawn_by': self.names.get(row.withdrawn_by, ''), 'withdraw_reason': row.withdraw_reason})
        return view

    def board(self, category, ops=False):
        current = self.current.get(category)
        return {'category': category, 'unit_type': c.UNITS[category],
                'current': self.view(current, ops) if current else None,
                'upcoming': [self.view(row, ops) for row in self.upcoming.get(category, [])]}


def _notify_suppliers(db, row):
    profiles = db.scalars(select(m.SupplierProfile).where(m.SupplierProfile.status == 'approved')).all()
    for profile in profiles:
        if row.category in (profile.categories or []):
            notes.notify(db, profile.user_id, 'supplier', 'market_prices_updated', M('notify.market_prices_updated',
                product=row.category.replace('_', ' '), date=row.effective_from), '/account')


# ---- suppliers ----------------------------------------------------------------

@router.get('/market-prices')
def supplier_prices(user=Depends(supplier), db=Depends(database)):
    """Categories that have a price now or soon; each with its next change only."""
    timeline = Timeline(db)
    boards = []
    for category in CATEGORIES:
        board = timeline.board(category)
        if board['current'] or board['upcoming']:
            board['upcoming'] = board['upcoming'][:1]
            boards.append(board)
    return _result(boards)


# ---- operations ---------------------------------------------------------------

@router.get('/ops/market-prices')
def ops_prices(operator=Depends(auth.ops), db=Depends(database)):
    timeline = Timeline(db)
    return _result({'today': c.business_today(), 'can_publish': operator.role == 'admin',
                    'categories': [timeline.board(category, ops=True) for category in CATEGORIES]})


@router.get('/ops/market-prices/history')
def ops_price_history(category: str = '', page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=100),
                      operator=Depends(auth.ops), db=Depends(database)):
    """Every list, newest publication first."""
    if category and category not in c.UNITS:
        category = ''
    where = (m.MarketPriceList.category == category,) if category else ()
    total = db.scalar(select(func.count()).select_from(m.MarketPriceList).where(*where))
    ids = db.scalars(select(m.MarketPriceList.id).where(*where).order_by(m.MarketPriceList.created_at.desc())
        .offset((page - 1) * page_size).limit(page_size)).all()
    timeline = Timeline(db, [category] if category else None)
    by_id = {row.id: row for row in timeline.lists}
    return _result({'items': [timeline.view(by_id[id], ops=True) for id in ids], 'total': total,
                    'page': page, 'page_size': page_size, 'actionable': 0})


@router.post('/ops/market-prices', status_code=201)
def publish_prices(data: c.MarketPriceListInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                   db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'market-price-list', idempotency_key, data.model_dump())
    if prior:
        timeline = Timeline(db, [data.category])
        return _result(timeline.view(next(row for row in timeline.lists if row.id == prior), ops=True), 201)
    today = c.business_today()
    if not today <= data.effective_from <= today + timedelta(days=MAX_DAYS_AHEAD):
        fail('err.price_effective_date', 422)
    row = m.MarketPriceList(category=data.category, unit_type=c.UNITS[data.category], effective_from=data.effective_from,
                            note=data.note, published_by=operator.id)
    db.add(row); db.flush()
    for position, band in enumerate(data.bands):
        db.add(m.MarketPriceBand(price_list_id=row.id, position=position, label=band.label,
            min_weight_kg=band.min_weight_kg, max_weight_kg=band.max_weight_kg, price_per_unit=band.price_per_unit))
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    _notify_suppliers(db, row)
    timeline = Timeline(db, [data.category])
    return _result(timeline.view(row, ops=True), 201)


@router.post('/ops/market-prices/{id}/withdraw')
def withdraw_prices(id: str, data: c.MarketPriceWithdrawInput, idempotency_key: str = Header(),
                    operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'market-price-withdraw', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.MarketPriceList, id, with_for_update=True)
    if not row:
        fail('err.price_list_not_found', 404)
    if not prior:
        if Timeline(db, [row.category]).status.get(row.id) not in ('current', 'scheduled'):
            fail('err.price_list_cannot_withdraw', 409)
        row.withdrawn_at, row.withdrawn_by, row.withdraw_reason = m.now(), operator.id, data.reason
        db.flush()
        s.remember(db, key, fingerprint, row.id)
    return _result(Timeline(db, [row.category]).view(row, ops=True))

