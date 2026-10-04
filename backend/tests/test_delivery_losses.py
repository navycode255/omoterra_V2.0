"""Losses on a delivery note: received goods that died, were culled, stolen or
spoiled before they were sold (migration 036). Stock on hand drops, the cost
counts against profit, and what Omoterra owes the supplier does not change."""
from datetime import timedelta
from decimal import Decimal

from app import contracts as c, models as m
from test_batch_sales import batch, note, receipt_debt
from test_finance import OPS, STAFF, TODAY, post

YESTERDAY = (c.business_today() - timedelta(days=1)).isoformat()


def receive(client, seeded, batch_id, quantity=80, on=TODAY):
    response = post(client, f'/suppliers/{seeded["supplier"]}/collections', {'batch_id': batch_id, 'received_on': on,
        'delivered_quantity': str(quantity), 'accepted_quantity': str(quantity), 'unit_cost': '6500'})
    assert response.status_code == 201, response.text
    return response.json()['id']


def lose(client, note_id, quantity='5', reason='died', on=TODAY, headers=STAFF, **extra):
    return post(client, f'/supplier-collections/{note_id}/losses',
        {'quantity': quantity, 'lost_on': on, 'reason': reason, 'note': 'Died on the way from the farm', **extra}, headers)


def profit_today(client):
    response = client.get('/api/v1/ops/finance/profit', params={'start': TODAY, 'end': TODAY}, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def test_five_of_eighty_die_on_the_way(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 300))
    before = Decimal(profit_today(client)['stock_lost'])

    response = lose(client, note_id)
    assert response.status_code == 201, response.text
    body = response.json()
    assert Decimal(body['on_hand']) == 75 and Decimal(body['lost']) == 5
    event = body['movements'][-1]
    assert event['kind'] == 'lost' and event['loss_reason'] == 'died' and Decimal(event['value']) == Decimal('32500')
    assert event['note'] == 'Died on the way from the farm' and event['cancelled_at'] is None

    # The loss is the cost of the 5 birds, on the day they died.
    assert Decimal(profit_today(client)['stock_lost']) - before == Decimal('32500')
    # Omoterra received all 80, so the supplier is still owed for all 80.
    assert receipt_debt(sessions, note_id).amount == Decimal('520000')


def test_cannot_lose_more_than_is_on_hand_or_before_receipt(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 300), quantity=10)
    assert lose(client, note_id, quantity='11').status_code == 422
    assert lose(client, note_id, quantity='1.5').status_code == 422  # birds are whole
    assert lose(client, note_id, on=YESTERDAY).status_code == 422
    tomorrow = (c.business_today() + timedelta(days=1)).isoformat()
    assert lose(client, note_id, on=tomorrow).status_code == 422
    assert lose(client, note_id, reason='eaten').status_code == 422
    assert lose(client, note_id, quantity='10').status_code == 201
    assert lose(client, note_id, quantity='1').status_code == 422  # nothing left
    # Lost goods can no longer be returned to the supplier.
    assert post(client, f'/supplier-collections/{note_id}/returns',
        {'quantity': '1', 'returned_on': TODAY, 'reason': 'Underweight'}).status_code == 422


def test_admin_cancels_a_mistaken_loss_and_the_birds_are_back(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 300))
    movement = lose(client, note_id).json()['movements'][-1]['id']
    path = f'/supplier-collections/{note_id}/losses/{movement}/cancel'
    assert post(client, path, {'reason': 'Counted twice'}, STAFF).status_code == 403
    assert post(client, path, {'reason': 'x'}).status_code == 422
    before = Decimal(profit_today(client)['stock_lost'])

    response = post(client, path, {'reason': 'Counted twice'})
    assert response.status_code == 200, response.text
    body = response.json()
    assert Decimal(body['on_hand']) == 80 and Decimal(body['lost']) == 0
    event = body['movements'][-1]
    assert event['cancelled_at'] and event['cancel_reason'] == 'Counted twice' and event['cancelled_by']
    assert before - Decimal(profit_today(client)['stock_lost']) == Decimal('32500')
    assert post(client, path, {'reason': 'Counted twice'}).status_code == 404  # already cancelled


def test_recording_a_loss_is_idempotent(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 300))
    body = {'quantity': '5', 'lost_on': TODAY, 'reason': 'died', 'note': ''}
    first = post(client, f'/supplier-collections/{note_id}/losses', body, STAFF, idem='same-loss-key-01')
    replay = post(client, f'/supplier-collections/{note_id}/losses', body, STAFF, idem='same-loss-key-01')
    assert first.status_code == replay.status_code == 201
    assert Decimal(note(client, note_id)['lost']) == 5
    with sessions() as db:
        assert db.query(m.CollectionMovement).filter_by(collection_id=note_id, kind='lost').count() == 1
