"""Keeps media_references in step with the records that show media.

Imported at the bottom of models.py, so the hook is live wherever models are
used (API, cron jobs, one-off scripts) and no write can skip it: a missing
reference would let the hourly prune delete a photo that is still shown.
"""
import re

from sqlalchemy import event, inspect, literal, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from . import models as m

MEDIA_ID = re.compile(r'/media/([0-9a-f-]{36})')

# Records whose fields can show media: model -> (key attribute, [(field, holds a list)]).
# A new photo/video field must be added here (and to migration 019's backfill).
REFERENCING = {
    m.Listing: ('id', (('photos', True), ('video', False))),
    m.SupplierPhoto: ('id', (('image_url', False),)),
    m.SupplierProfile: ('user_id', (('evidence_photos', True),)),
    m.SupplierBatch: ('id', (('photos', True),)),
    m.BatchVerification: ('id', (('photos', True),)),
    m.SourcingRequest: ('id', (('reference_photo', False),)),
    m.Order: ('id', (('collection_photos', True),)),
}


def _media_ids(row, fields):
    ids = set()
    for field, listed in fields:
        value = getattr(row, field)
        for url in (value or []) if listed else [value]:
            if isinstance(url, str):
                ids.update(MEDIA_ID.findall(url))
    return ids


@event.listens_for(Session, 'after_flush')
def _sync_references(session, context):
    """Keep media_references in step with every record written in this flush.
    Only rows whose media fields changed are touched, so the stock-count
    updates that rewrite listings all day cost nothing here."""
    changes = []
    for row in session.new | session.dirty | session.deleted:
        spec = REFERENCING.get(type(row))
        if not spec:
            continue
        key, fields = spec
        if row in session.deleted:
            ids = set()
        elif row in session.new or any(inspect(row).attrs[field].history.has_changes() for field, _ in fields):
            ids = _media_ids(row, fields)
        else:
            continue
        changes.append((type(row).__tablename__, getattr(row, key), ids))
    if not changes:
        return
    refs = m.MediaReference.__table__
    connection = session.connection()
    for table, owner, ids in changes:
        connection.execute(refs.delete().where(refs.c.owner_table == table, refs.c.owner_id == owner))
        if ids:
            # Only media that exists: a stray URL never breaks the write.
            connection.execute(pg_insert(refs).from_select(['media_id', 'owner_table', 'owner_id'],
                select(m.MediaAsset.id, literal(table), literal(owner)).where(m.MediaAsset.id.in_(ids)))
                .on_conflict_do_nothing())
