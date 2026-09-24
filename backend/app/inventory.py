"""Append-only stock history. Call inside the commerce transaction before mutating balances."""
from decimal import Decimal
from sqlalchemy import select
from . import models as m


def balances(listing):
    return (Decimal(listing.quantity_total or 0), Decimal(listing.quantity_reserved or 0), Decimal(listing.quantity_sold or 0))


def movement(db, listing, kind, before, reference, reason='', actor=None):
    after = balances(listing)
    row = m.StockMovement(listing_id=listing.id, kind=kind,
        total_delta=after[0] - before[0], reserved_delta=after[1] - before[1], sold_delta=after[2] - before[2],
        total_after=after[0], reserved_after=after[1], sold_after=after[2],
        reference=reference, reason=reason, actor_id=actor)
    db.add(row)
    db.flush()
    return row


def ensure_history(db, listing):
    if not db.scalar(select(m.StockMovement.id).where(m.StockMovement.listing_id == listing.id).limit(1)):
        movement(db, listing, 'opening_balance', (Decimal(0), Decimal(0), Decimal(0)),
            f'opening:{listing.id}', 'Opening balance when stock history began. Earlier activity is not reconstructed.')


def view(row):
    return {**{key: getattr(row, key) for key in ['id', 'kind', 'created_at', 'total_delta', 'reserved_delta', 'sold_delta', 'total_after', 'reserved_after', 'sold_after', 'reason']},
        'available_after': row.total_after - row.reserved_after - row.sold_after}


def sale_view(db, sale):
    listing = db.get(m.Listing, sale.listing_id)
    reversal = db.scalar(select(m.StockSaleReversal).where(m.StockSaleReversal.sale_id == sale.id))
    return {'status': 'reversed' if reversal else 'recorded', 'reversal_reason': reversal.reason if reversal else None,
        'id': sale.id, 'listing_id': listing.id, 'category': listing.category, 'unit_type': listing.unit_type,
        'source': sale.source, 'quantity': sale.quantity, 'sold_at': sale.sold_at, 'created_at': sale.created_at,
        'unit_price': sale.unit_price if sale.source == 'external' else None,
        'note': sale.note, 'total': (sale.quantity * sale.unit_price).quantize(Decimal('.01')) if sale.unit_price is not None and sale.source == 'external' else None}
