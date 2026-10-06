"""Stock as of the sale date (build plan M2.2, audit F03 part 2, rule R8).

Every change that takes stock from a received lot, or puts it back, is
replayed by date: it is refused if any day from then on would end below
zero, even when there is stock today, and stock cannot be used before it
was received. A record dated more than LATE_ENTRY_DAYS (3) back is a late
entry: admin only, with a reason, and still never below zero."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select

from app import contracts as c, lots, models as m
from test_batch_sales import batch
from test_delivery_losses import receive
from test_finance import API, OPS, STAFF, key, post, sale

DAY = c.business_today()
D = {n: DAY - timedelta(days=n) for n in range(12)}
LATE = lots.LATE_ENTRY_DAYS


@pytest.fixture
def no_late_window(monkeypatch):
    """The R8 date checks below span more than the late-entry window; they
    are about stock by date, not about who may enter late records."""
    monkeypatch.setattr(lots, 'LATE_ENTRY_DAYS', 30)


def line(note_id, quantity):
    return {'quantity': str(quantity), 'unit_price': '7500', 'supplier_collection_id': note_id}


def sell(client, note_id, quantity, on, headers=OPS, **extra):
    return client.post(API + '/sales', json={'new_buyer': {'business_name': 'Dated Buyer'}, 'sold_on': on.isoformat(),
        'items': [line(note_id, quantity)], **extra}, headers={**headers, 'Idempotency-Key': key()})


def edit(client, body, quantity, **extra):
    return client.put(API + f"/sales/{body['id']}", json={'buyer_profile_id': body['buyer_profile_id'],
        'sold_on': body['sold_on'], 'items': [line(body['items'][0]['supplier_collection_id'], quantity)], **extra},
        headers=OPS)


def on_hand(sessions, note_id, day=None):
    with sessions() as db:
        return lots.on_hand(lots.movements(db, 'supplier_collections', [note_id]), day).get(
            ('supplier_collections', note_id), 0)


def test_stock_cannot_be_sold_before_it_was_received(client, sessions, seeded, no_late_window):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[3].isoformat())
    early = sell(client, note_id, 5, D[5])
    assert early.status_code == 422 and D[3].isoformat() in early.json()['detail']
    assert sell(client, note_id, 5, D[3]).status_code == 201


def test_a_back_dated_sale_is_refused_when_a_later_day_would_go_below_zero(client, sessions, seeded, no_late_window):
    """100 received; 60 sold on D5 and 40 on D3; 10 of those come back
    today. There are 10 on hand now, but 10 more sold on D4 would leave D3
    at -10, so it is refused; the same 10 sold today are fine."""
    note_id = receive(client, seeded, batch(sessions, seeded, 200), 100, on=D[7].isoformat())
    assert sell(client, note_id, 60, D[5]).status_code == 201
    later = sell(client, note_id, 40, D[3]).json()
    returned = edit(client, later, 30, goods='buyer_return_accepted', goods_note='Two crates came back unopened')
    assert returned.status_code == 200, returned.text
    assert on_hand(sessions, note_id) == 10
    refused = sell(client, note_id, 10, D[4])
    assert refused.status_code == 422 and D[3].isoformat() in refused.json()['detail']
    assert on_hand(sessions, note_id, D[3]) == 0
    assert sell(client, note_id, 10, D[0]).status_code == 201
    assert on_hand(sessions, note_id) == 0


def test_moving_a_sale_earlier_is_checked_on_every_day(client, sessions, seeded, no_late_window):
    """10 received on D6: 6 sold on D2 and 4 on D4. Moving the D2 sale to
    D5 is fine; moving the D4 sale before the D2 one is fine too, but
    moving it before the receipt is not."""
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[6].isoformat())
    first = sell(client, note_id, 6, D[2]).json()
    second = sell(client, note_id, 4, D[4]).json()
    assert edit(client, {**first, 'sold_on': D[5].isoformat()}, 6).status_code == 200
    moved = edit(client, {**second, 'sold_on': D[8].isoformat()}, 4, late_reason='Found the paper invoice')
    assert moved.status_code == 422 and D[6].isoformat() in moved.json()['detail']


def test_undoing_a_buyer_return_that_later_sales_relied_on_is_refused(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[3].isoformat())
    first = sell(client, note_id, 10, D[2]).json()
    assert edit(client, first, 6, goods='buyer_return_accepted', goods_note='Four came back healthy').status_code == 200
    assert sell(client, note_id, 4, D[0]).status_code == 201
    assert edit(client, first, 10).status_code == 422
    assert on_hand(sessions, note_id) == 0


def test_a_late_entry_needs_an_admin_and_a_reason_and_still_never_goes_below_zero(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[LATE + 4].isoformat())
    assert sell(client, note_id, 3, D[LATE + 2], STAFF, late_reason='Paper invoice found').status_code == 422
    assert sell(client, note_id, 3, D[LATE + 2]).status_code == 422  # admin, no reason
    assert sell(client, note_id, 30, D[LATE + 2], late_reason='Paper invoice found').status_code == 422  # below zero
    done = sell(client, note_id, 3, D[LATE + 2], late_reason='Paper invoice found in the market book')
    assert done.status_code == 201, done.text
    with sessions() as db:
        [row] = db.scalars(select(m.LateEntry)).all()
        assert (row.entity_table, row.entity_id, row.entry_date) == ('sales', done.json()['id'], D[LATE + 2])
        assert row.reason == 'Paper invoice found in the market book'
    # Within the window it is an ordinary entry, for staff too.
    assert sell(client, note_id, 2, D[LATE], STAFF).status_code == 201
    # The same rule for losses and returns.
    path = f'/supplier-collections/{note_id}/losses'
    loss = {'quantity': '1', 'lost_on': D[LATE + 3].isoformat(), 'reason': 'died', 'note': 'Heat'}
    assert post(client, path, loss).status_code == 422
    assert post(client, path, {**loss, 'late_reason': 'Vet report arrived late'}).status_code == 201


def test_two_simultaneous_sales_cannot_oversell_a_lot(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[1].isoformat())
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: sell(client, note_id, 7, D[0]), range(2)))
    assert sorted(r.status_code for r in responses) == [201, 422]
    assert on_hand(sessions, note_id) == 3


def test_a_loss_dated_before_later_sales_is_checked_on_every_day(client, sessions, seeded, no_late_window):
    """10 received on D5, 8 sold on D3, 3 of them returned by the buyer
    today: 5 are on hand, but a loss of 3 on D4 would leave D3 at -1."""
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[5].isoformat())
    body = sell(client, note_id, 8, D[3]).json()
    assert edit(client, body, 5, goods='buyer_return_accepted', goods_note='Three came back healthy').status_code == 200
    assert on_hand(sessions, note_id) == 5
    path = f'/supplier-collections/{note_id}/losses'
    refused = post(client, path, {'quantity': '3', 'lost_on': D[4].isoformat(), 'reason': 'died'})
    assert refused.status_code == 422 and D[3].isoformat() in refused.json()['detail']
    assert post(client, path, {'quantity': '2', 'lost_on': D[4].isoformat(), 'reason': 'died'}).status_code == 201
    assert on_hand(sessions, note_id) == 3 and on_hand(sessions, note_id, D[3]) == 0
