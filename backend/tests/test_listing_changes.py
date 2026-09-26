from sqlalchemy import select
from app import models as m
from test_commerce import headers
from test_supplier_onboarding import _jpeg

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def review(client, listing, key, **body):
    return client.patch(f'/api/v1/ops/listings/{listing}/status', headers={**OPS, 'Idempotency-Key': key}, json=body)


def pending_listing(sessions, seeded):
    with sessions.begin() as db:
        row = db.get(m.Listing, seeded['listing'])
        row.listing_status, row.approved_at = 'pending_review', None
    return seeded['listing']


def test_ops_asks_for_changes_and_the_supplier_sends_it_back(client, sessions, seeded):
    listing = pending_listing(sessions, seeded)
    assert review(client, listing, 'changes-no-note', status='changes_requested').status_code == 422
    asked = review(client, listing, 'changes-with-note', status='changes_requested',
        note='Add a clearer photo of the birds')
    assert asked.status_code == 200, asked.text
    stock = client.get(f'/api/v1/supplier/stock/{listing}', headers=headers('supplier')).json()
    assert stock['listing_status'] == 'changes_requested'
    assert stock['review_note'] == 'Add a clearer photo of the birds'
    with sessions() as db:
        note = db.scalar(select(m.Notification).where(m.Notification.kind == 'stock_changes_requested'))
        assert 'clearer photo' in note.body and note.link == f'/stock/{listing}'
    back = client.patch(f'/api/v1/supplier/stock/{listing}', headers={**headers('supplier'), 'Idempotency-Key': 'resubmit-001'},
        json={'action': 'resubmit'})
    assert back.status_code == 200, back.text
    assert back.json()['listing_status'] == 'pending_review'
    again = client.patch(f'/api/v1/supplier/stock/{listing}', headers={**headers('supplier'), 'Idempotency-Key': 'resubmit-002'},
        json={'action': 'resubmit'})
    assert again.status_code == 409


def test_new_photos_send_changed_stock_back_to_review(client, sessions, seeded):
    listing = pending_listing(sessions, seeded)
    review(client, listing, 'changes-photo', status='changes_requested', note='Photos are too dark')
    photo = client.post('/api/v1/media', headers=headers('supplier'),
        files={'file': ('birds.jpg', _jpeg(), 'image/jpeg')}).json()['url']
    media = client.put(f'/api/v1/supplier/stock/{listing}/media', headers=headers('supplier'),
        json={'photos': [photo], 'video': None})
    assert media.status_code == 200, media.text
    assert media.json()['listing_status'] == 'pending_review'


def test_changes_are_only_requested_on_stock_under_review(client, seeded):
    # The seeded stock is already live.
    assert review(client, seeded['listing'], 'changes-live', status='changes_requested',
        note='Too late for this').status_code == 409


def test_ops_resumes_stock_it_paused(client, sessions, seeded):
    listing = seeded['listing']
    assert review(client, listing, 'pause-first', status='paused').status_code == 200
    resumed = review(client, listing, 'resume-it', status='live')
    assert resumed.status_code == 200, resumed.text
    assert resumed.json()['status'] == 'live'
    with sessions() as db:
        assert db.scalar(select(m.Notification).where(m.Notification.kind == 'stock_live')) is not None
    # Unapproved stock cannot be "resumed" around review.
    pending_listing(sessions, seeded)
    assert review(client, listing, 'resume-pending', status='live').status_code == 409
