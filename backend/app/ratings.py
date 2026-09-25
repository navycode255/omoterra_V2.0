"""Supplier reputation: buyer star ratings, deliveries, and the share of
supply that passed Omoterra's quality check at collection.

Buyers see the average only once a supplier has MIN_RATINGS ratings, so one
early review cannot define a supplier. The quality figure comes from
operations' own checks, not from buyers, so it cannot be gamed.
"""
from datetime import timedelta
from decimal import Decimal

from sqlalchemy import func, select

from . import models as m

MIN_RATINGS = 3
EDIT_DAYS = 14


def _supplier_orders(supplier_id):
    return (select(m.OrderItem.order_id).join(m.Listing, m.Listing.id == m.OrderItem.listing_id)
            .where(m.Listing.supplier_id == supplier_id))


def reputation(db, supplier_id):
    stars = db.execute(select(func.avg(m.OrderRating.stars), func.count(m.OrderRating.id)).where(
        m.OrderRating.order_id.in_(_supplier_orders(supplier_id)), m.OrderRating.hidden.is_(False))).one()
    accepted, rejected = db.execute(
        select(func.coalesce(func.sum(m.OrderItem.actual_quantity), 0),
               func.coalesce(func.sum(m.OrderItem.rejected_quantity), 0))
        .join(m.Listing, m.Listing.id == m.OrderItem.listing_id)
        .where(m.Listing.supplier_id == supplier_id, m.OrderItem.actual_quantity.is_not(None))).one()
    checked = Decimal(accepted) + Decimal(rejected)
    profile = db.get(m.SupplierProfile, supplier_id)
    count = stars[1]
    return {
        'rating': round(float(stars[0]), 1) if count >= MIN_RATINGS else None,
        'ratings': count,
        'deliveries': profile.completed_supplies_count if profile else 0,
        # Share of collected units that passed the quality check, when any were checked.
        'quality_passed': round(float(Decimal(accepted) / checked * 100)) if checked > 0 else None,
    }


def rating_view(rating, for_buyer=True):
    view = {'id': rating.id, 'stars': rating.stars, 'comment': rating.comment,
            'created_at': rating.created_at, 'updated_at': rating.updated_at}
    if for_buyer:
        view['editable_until'] = rating.created_at + timedelta(days=EDIT_DAYS)
    return view


def can_edit(rating):
    return m.now() <= rating.created_at + timedelta(days=EDIT_DAYS)


def supplier_ids_for_order(db, order_id):
    return db.scalars(select(m.Listing.supplier_id).join(m.OrderItem, m.OrderItem.listing_id == m.Listing.id)
                      .where(m.OrderItem.order_id == order_id).distinct()).all()
