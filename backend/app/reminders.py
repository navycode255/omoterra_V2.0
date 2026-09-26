"""Reminds suppliers to confirm stock before (or just after) it drops out of
buyers' view. Run from cron, e.g. hourly on cPanel:

    cd ~/omoterra/backend && .venv/bin/python -m app.reminders

Each listing gets at most one reminder per confirmation window: the
reminder is stamped on the listing and a new confirmation starts a new window.

The same run deletes photos and videos uploaded over a day ago that nothing
uses (a form that was abandoned), from disk or R2.
"""
from datetime import timedelta

from sqlalchemy import or_, select

from . import models as m, notifications as notes
from .i18n import M, category

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
        key = 'notify.stock_hidden' if listing.confirmation_due_at <= now else 'notify.stock_confirm'
        # ?confirm=1 opens the stock with "Still available?" already asked.
        notes.notify(db, listing.supplier_id, 'supplier', 'stock_confirm', M(key, what=category(listing.category)),
            f'/stock/{listing.id}?confirm=1')
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
    # Same hourly run: delete uploads that were never saved onto anything.
    from .media import prune_unused_media
    with Session.begin() as db:
        pruned = prune_unused_media(db)
    print(f'Unused media deleted: {pruned}')
    from .media import prune_stale_uploads
    with Session.begin() as db:
        print(f'Unfinished video uploads removed: {prune_stale_uploads(db)}')
