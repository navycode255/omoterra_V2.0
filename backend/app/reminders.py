"""Reminds suppliers to confirm stock before (or just after) it drops out of
buyers' view. Run from cron, e.g. hourly on cPanel:

    cd ~/omoterra/backend && .venv/bin/python -m app.reminders

Each listing gets at most one reminder per confirmation window: the
reminder is stamped on the listing and a new confirmation starts a new window.
"""
from datetime import timedelta

from sqlalchemy import or_, select

from . import models as m, notifications as notes
from .services import category

REMIND_BEFORE = timedelta(hours=6)


def remind_stale_stock(db, now=None):
    now = now or m.now()
    rows = db.scalars(select(m.Listing).where(
        m.Listing.listing_status.in_(['live', 'needs_confirmation']),
        m.Listing.confirmation_due_at.is_not(None),
        m.Listing.confirmation_due_at <= now + REMIND_BEFORE,
        or_(m.Listing.confirmation_reminded_at.is_(None),
            m.Listing.confirmation_reminded_at < m.Listing.last_confirmed_at),
    ).with_for_update()).all()
    for listing in rows:
        what = category(listing.category)
        if listing.confirmation_due_at <= now:
            title, body = ('Stock hidden from buyers',
                f'Your {what} needs confirming before buyers can see it again. Open it and tap Confirm availability.')
        else:
            title, body = ('Confirm your stock is still available',
                f'Your {what} will be hidden from buyers in a few hours unless you confirm it is still available.')
        notes.notify(db, listing.supplier_id, 'supplier', 'stock_confirm', title, body, f'/stock/{listing.id}')
        listing.confirmation_reminded_at = now
    return len(rows)


if __name__ == '__main__':
    from .config import settings
    from .db import Session
    settings().validate_runtime()
    # The process exits right after; deliver pushes before it does.
    notes.dispatch = lambda job: job()
    with Session.begin() as db:
        sent = remind_stale_stock(db)
    print(f'Stock reminders sent: {sent}')
