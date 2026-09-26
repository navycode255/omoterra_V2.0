"""One paging and search contract for every operations list.

    GET /ops/<list>?status=&q=&page=&page_size=
    -> {items, total, page, page_size, actionable, counts}

- `page_size` defaults to 50 and is capped at 100.
- `status` picks a tab (a named group such as `open` for orders in progress)
  or, failing that, one raw status value. Empty or `all` means every row.
- `q` searches references, supplier alias or legal name, buyer name or phone,
  category and region with ILIKE. Migration 017 gives those columns trigram
  indexes, so a `%text%` match stays indexed.
- Rows that need action (unpaid settlements, orders in progress, stock
  awaiting review...) are never paged: every one of them comes first on
  page 1, most urgent first. Paging applies only to the history behind them,
  so work can never fall off the end of a list. `actionable` says how many
  of `total` are such rows; the history pages are
  ceil((total - actionable) / page_size), at least one.
- `counts` gives each tab's row count under the same search, from the
  database, so tab badges never depend on what one page happens to hold.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Callable, get_args

from fastapi import Query
from sqlalchemy import Text, and_, cast, false, func, literal, not_, or_, select, union_all

from . import contracts as c, models as m

MAX_PAGE_SIZE = 100
DEFAULT_PAGE_SIZE = 50


class Paging:
    """The query parameters every operations list accepts."""

    def __init__(self, status: str = '', q: str = '', page: int = Query(1, ge=1),
                 page_size: int = Query(DEFAULT_PAGE_SIZE, ge=1)):
        self.status = status.strip()
        self.q = q.strip()[:100]
        self.page = page
        self.page_size = min(page_size, MAX_PAGE_SIZE)

    @property
    def offset(self):
        return (self.page - 1) * self.page_size


# ---- search -----------------------------------------------------------------

def _like(q):
    escaped = q.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
    return f'%{escaped}%'


def matches(q, *columns):
    """`q` appears anywhere in any of the columns, ignoring case."""
    return or_(*(column.ilike(_like(q), escape='\\') for column in columns))


# References shown on the dashboard are a two or three letter prefix and the
# first six hex digits of the id, e.g. OR-3F2A9C.
_REFERENCE = re.compile(r'^(?:[a-z]{2,3}-)?([0-9a-f]{4,8})$', re.I)


def reference(q, *columns):
    """Conditions matching `q` as a dashboard reference (an id prefix)."""
    found = _REFERENCE.match(q.replace(' ', ''))
    return [column.like(found.group(1).lower() + '%') for column in columns] if found else []


CATEGORIES = get_args(c.Category)


def categories(q):
    """Category keys whose label contains `q` ('local chicken', 'goat')."""
    text = q.casefold().replace('_', ' ')
    return [key for key in CATEGORIES if text in key.replace('_', ' ')]


def supplier_ids(q):
    """Suppliers found by alias, legal name or phone."""
    return (select(m.SupplierProfile.user_id).join(m.User, m.User.id == m.SupplierProfile.user_id)
        .where(matches(q, m.SupplierProfile.public_alias, m.SupplierProfile.legal_name, m.User.phone)))


def buyer_user_ids(q):
    """Buyer accounts found by name or phone, or by their CRM business name."""
    return union_all(
        select(m.User.id).where(matches(q, m.User.name, m.User.phone)),
        select(m.BuyerProfile.user_id).where(m.BuyerProfile.user_id.is_not(None),
            matches(q, m.BuyerProfile.business_name, m.BuyerProfile.contact_person, m.BuyerProfile.phone)))


def buyer_profile_ids(q):
    """Offline (CRM) buyers found by business name, contact or phone."""
    return select(m.BuyerProfile.id).where(
        matches(q, m.BuyerProfile.business_name, m.BuyerProfile.contact_person, m.BuyerProfile.phone))


def _order_items(q):
    """Order items whose stock came from a matching supplier, category or region."""
    return (select(m.OrderItem.id, m.OrderItem.order_id).join(m.Listing, m.Listing.id == m.OrderItem.listing_id)
        .where(or_(m.Listing.supplier_id.in_(supplier_ids(q)), m.Listing.category.in_(categories(q)),
                   matches(q, m.Listing.region))))


def order_search(q):
    managed = select(m.SourcingRequest.id).where(m.SourcingRequest.buyer_profile_id.in_(buyer_profile_ids(q)))
    return or_(*reference(q, m.Order.id),
        m.Order.buyer_id.in_(buyer_user_ids(q)),
        m.Order.sourcing_request_id.in_(managed),
        m.Order.id.in_(_order_items(q).with_only_columns(m.OrderItem.order_id)),
        matches(q, m.Order.delivery_snapshot['region'].as_string()))


def settlement_search(q):
    return or_(*reference(q, m.Settlement.id),
        m.Settlement.supplier_id.in_(supplier_ids(q)),
        *(m.Settlement.order_item_id.in_(select(m.OrderItem.id).where(condition))
          for condition in reference(q, m.OrderItem.order_id)),
        m.Settlement.order_item_id.in_(_order_items(q).with_only_columns(m.OrderItem.id)))


def payment_search(q):
    orders = select(m.Order.id).where(order_search(q))
    return or_(m.Payment.order_id.in_(orders), matches(q, m.Payment.provider_transaction_id))


def listing_search(q):
    return or_(*reference(q, m.Listing.id), m.Listing.supplier_id.in_(supplier_ids(q)),
        m.Listing.category.in_(categories(q)), matches(q, m.Listing.region))


def demand_search(q):
    return or_(*reference(q, m.SourcingRequest.id),
        matches(q, m.SourcingRequest.requirement_number, m.SourcingRequest.delivery_region,
                m.SourcingRequest.product_subtype),
        m.SourcingRequest.category.in_(categories(q)),
        m.SourcingRequest.buyer_id.in_(buyer_user_ids(q)),
        m.SourcingRequest.buyer_profile_id.in_(buyer_profile_ids(q)))


def opportunity_search(q):
    return or_(*reference(q, m.BusinessOpportunity.id),
        matches(q, m.BusinessOpportunity.business_type, m.BusinessOpportunity.area),
        m.BusinessOpportunity.buyer_id.in_(buyer_user_ids(q)))


def supplier_search(q):
    return or_(m.SupplierProfile.user_id.in_(supplier_ids(q)),
        matches(q, m.SupplierProfile.region, m.SupplierProfile.district),
        *(cast(m.SupplierProfile.categories, Text).like(f'%"{key}"%') for key in categories(q)))


def rating_search(q):
    orders = select(m.Order.id).where(order_search(q))
    return or_(m.OrderRating.order_id.in_(orders), matches(q, m.OrderRating.comment))


def buyer_account_search(q):
    return matches(q, m.User.name, m.User.phone, m.User.region)


def is_buyer(user=m.User):
    return cast(user.roles, Text).like('%"buyer"%')


def buyer_directory():
    """Buyer CRM records and buyer app accounts without one, as one table."""
    linked = select(m.BuyerProfile.user_id).where(m.BuyerProfile.user_id.is_not(None))
    return union_all(
        select(m.BuyerProfile.id, m.BuyerProfile.user_id, m.BuyerProfile.business_name, m.BuyerProfile.buyer_type,
               m.BuyerProfile.contact_person, m.BuyerProfile.phone, m.BuyerProfile.region, m.BuyerProfile.area,
               literal(True).label('crm_record')),
        select(m.User.id, m.User.id.label('user_id'), m.User.name.label('business_name'),
               func.coalesce(m.User.buyer_type, 'personal').label('buyer_type'), m.User.name.label('contact_person'),
               m.User.phone, m.User.region, literal('').label('area'), literal(False).label('crm_record'))
        .where(is_buyer(), m.User.id.not_in(linked)),
    ).subquery('buyer_directory')


# ---- lists --------------------------------------------------------------------

@dataclass
class Spec:
    """How one operations list filters, searches and orders its rows."""
    source: Any                                   # a model, or a subquery for row lists
    order: tuple                                  # history order, newest first
    search: Callable[[str], Any]
    tabs: dict = field(default_factory=dict)      # status tab -> condition
    column: Any = None                            # raw status column for other `status` values
    urgent: Any = None                            # rows that need action; never paged
    urgent_order: tuple = ()                      # most urgent first
    rows: bool = False                            # select columns, not an entity


OPEN_ORDER = m.Order.internal_status.not_in(('delivered', 'completed', 'cancelled', 'payment_failed'))
ORDERS = Spec(m.Order, (m.Order.created_at.desc(), m.Order.id.desc()), order_search,
    tabs={'open': OPEN_ORDER,
          'delivered': m.Order.internal_status.in_(('delivered', 'completed')),
          'failed': m.Order.internal_status.in_(('cancelled', 'payment_failed'))},
    column=m.Order.internal_status, urgent=OPEN_ORDER, urgent_order=(m.Order.created_at, m.Order.id))

UNPAID = m.Settlement.status == 'pending'
SETTLEMENTS = Spec(m.Settlement, (m.Settlement.created_at.desc(), m.Settlement.id.desc()), settlement_search,
    tabs={'pending': UNPAID, 'paid': m.Settlement.status == 'paid'},
    column=m.Settlement.status, urgent=UNPAID, urgent_order=(m.Settlement.created_at, m.Settlement.id))

OUTSTANDING = m.Payment.status.in_(('pending', 'partial'))
PAYMENTS = Spec(m.Payment, (m.Payment.created_at.desc(), m.Payment.id.desc()), payment_search,
    tabs={'outstanding': OUTSTANDING, 'paid': m.Payment.status == 'paid', 'failed': m.Payment.status == 'failed'},
    column=m.Payment.status, urgent=OUTSTANDING, urgent_order=(m.Payment.created_at, m.Payment.id))

# Live stock whose supplier has not reconfirmed it in time needs confirmation.
STALE = or_(m.Listing.listing_status == 'needs_confirmation',
            and_(m.Listing.listing_status == 'live', m.Listing.confirmation_due_at <= func.now()))
FRESH_LIVE = and_(m.Listing.listing_status == 'live',
                  or_(m.Listing.confirmation_due_at.is_(None), m.Listing.confirmation_due_at > func.now()))
LISTINGS = Spec(m.Listing, (m.Listing.created_at.desc(), m.Listing.id.desc()), listing_search,
    tabs={'live': FRESH_LIVE, 'pending_review': m.Listing.listing_status == 'pending_review', 'needs_confirmation': STALE,
          **{status: m.Listing.listing_status == status for status in ('changes_requested', 'paused', 'sold_out', 'rejected')}},
    column=m.Listing.listing_status, urgent=or_(m.Listing.listing_status == 'pending_review', STALE),
    urgent_order=(m.Listing.created_at, m.Listing.id))

ACTIVE_DEMAND = m.SourcingRequest.status.not_in(('completed', 'cancelled', 'converted'))
DEMAND = Spec(m.SourcingRequest, (m.SourcingRequest.needed_by_date.desc(), m.SourcingRequest.id.desc()), demand_search,
    tabs={'active': ACTIVE_DEMAND, 'closed': not_(ACTIVE_DEMAND)},
    column=m.SourcingRequest.status, urgent=ACTIVE_DEMAND,
    urgent_order=(m.SourcingRequest.needed_by_date, m.SourcingRequest.id))

PIPELINE = get_args(c.BusinessProgress.model_fields['status'].annotation)
OPPORTUNITIES = Spec(m.BusinessOpportunity, (m.BusinessOpportunity.created_at.desc(), m.BusinessOpportunity.id.desc()),
    opportunity_search, tabs={status: m.BusinessOpportunity.status == status for status in PIPELINE},
    column=m.BusinessOpportunity.status, urgent=m.BusinessOpportunity.status == 'new',
    urgent_order=(m.BusinessOpportunity.created_at, m.BusinessOpportunity.id))

SUPPLIERS = Spec(m.SupplierProfile, (m.SupplierProfile.public_alias, m.SupplierProfile.legal_name, m.SupplierProfile.user_id),
    supplier_search,
    tabs={'approved': m.SupplierProfile.status == 'approved',
          'under_review': m.SupplierProfile.status.in_(('under_review', 'new')),
          'suspended': m.SupplierProfile.status == 'suspended',
          'rejected': m.SupplierProfile.status == 'rejected'},
    column=m.SupplierProfile.status, urgent=m.SupplierProfile.status == 'under_review',
    urgent_order=(m.SupplierProfile.submitted_at.asc().nulls_last(), m.SupplierProfile.user_id))

RATINGS = Spec(m.OrderRating, (m.OrderRating.created_at.desc(), m.OrderRating.id.desc()), rating_search,
    tabs={'visible': m.OrderRating.hidden.is_(False), 'hidden': m.OrderRating.hidden.is_(True)})

BUYER_ACCOUNTS = Spec(m.User, (m.User.created_at.desc(), m.User.id.desc()), buyer_account_search)


def buyer_directory_list():
    table = buyer_directory()
    return Spec(table, (func.lower(table.c.business_name), table.c.id),
        lambda q: matches(q, table.c.business_name, table.c.contact_person, table.c.phone, table.c.region, table.c.area),
        tabs={'crm': table.c.crm_record.is_(True), 'app': table.c.crm_record.is_(False)}, rows=True)


# ---- paging -----------------------------------------------------------------

def _count(db, query):
    return db.scalar(select(func.count()).select_from(query.order_by(None).subquery())) or 0


def _fetch(db, spec, query):
    return db.execute(query).all() if spec.rows else db.scalars(query).all()


def page(db, spec: Spec, params: Paging, view: Callable = lambda row: row, where=(), base=None):
    """One page of a list under the contract in this module's docstring.
    `where` adds a list's own filters; `base` replaces the plain select."""
    query = base if base is not None else select(spec.source)
    for condition in where:
        query = query.where(condition)
    if params.q:
        query = query.where(spec.search(params.q))
    counts = {'all': _count(db, query), **{key: _count(db, query.where(condition)) for key, condition in spec.tabs.items()}} \
        if spec.tabs else None
    status = params.status if params.status != 'all' else ''
    if status in spec.tabs:
        query = query.where(spec.tabs[status])
    elif status and spec.column is not None:
        query = query.where(spec.column == status)
    total = counts['all'] if counts is not None and not status else _count(db, query)
    if spec.urgent is None:
        rows = _fetch(db, spec, query.order_by(*spec.order).offset(params.offset).limit(params.page_size))
        actionable = 0
    else:
        urgent = func.coalesce(spec.urgent, false())
        first = _fetch(db, spec, query.where(urgent).order_by(*spec.urgent_order)) if params.page == 1 else []
        actionable = len(first) if params.page == 1 else _count(db, query.where(urgent))
        rows = [*first, *_fetch(db, spec, query.where(not_(urgent)).order_by(*spec.order)
            .offset(params.offset).limit(params.page_size))]
    body = {'items': [view(row) for row in rows], 'total': total, 'page': params.page,
            'page_size': params.page_size, 'actionable': actionable}
    if counts is not None:
        body['counts'] = counts
    return body

