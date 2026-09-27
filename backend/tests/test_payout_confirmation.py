import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError
from app import models as m, contracts as c, services as s
from test_commerce import order, headers

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def supplier_order(client):
    rows = client.get('/api/v1/supplier/orders', headers=headers('supplier')).json()
    assert len(rows) == 1
    return rows[0]


def steps(row):
    return {step['key']: step['done'] for step in row['steps']}


def advance(sessions, id, *statuses):
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        for status in statuses:
            s.advance(db, row, c.Progress(internal_status=status, actual_quantity=3, rejected_quantity=1,
                expected_collection_date='2027-01-05' if status == 'pickup_scheduled' else None))


def pay(client, settlement, key, reference):
    return client.post(f'/api/v1/ops/settlements/{settlement}/pay', headers={**OPS, 'Idempotency-Key': key},
        json={'amount': '27000', 'payment_reference': reference})


def test_supplier_follows_the_order_to_a_confirmed_payout(client, sessions, seeded):
    id = order(sessions, seeded)
    row = supplier_order(client)
    assert row['stage'] == 'confirmed' and steps(row)['ordered'] and not steps(row)['collection_scheduled']
    # Supplier contracts never carry the buyer's identity, address or price.
    assert 'Private Buyer' not in str(row) and 'Secret buyer address' not in str(row) and '12000' not in str(row)

    advance(sessions, id, 'pickup_scheduled')
    row = supplier_order(client)
    assert row['stage'] == 'collection_scheduled' and row['expected_collection_date'] == '2027-01-05'

    advance(sessions, id, 'collected', 'quality_checked', 'in_transit', 'delivered')
    row = supplier_order(client)
    assert row['stage'] == 'awaiting_buyer_payment'
    assert row['accepted_quantity'] == '3.000' and row['rejected_quantity'] == '1.000'
    collected = next(step for step in row['steps'] if step['key'] == 'collected')
    assert collected['note'] == {'accepted': '3.000', 'rejected': '1.000'}
    settlement = row['settlements'][0]
    assert settlement['total_payable'] == '27000.00' and settlement['reference'] == row['reference']

    # Confirming before Omoterra has paid is refused.
    early = client.post(f"/api/v1/supplier/payouts/{settlement['id']}/confirm", headers=headers('supplier'), json={'received': True})
    assert early.status_code == 409

    reconcile = client.post(f'/api/v1/ops/orders/{id}/reconcile', headers={**OPS, 'Idempotency-Key': 'buyer-paid-0001'},
        json={'amount': '36000', 'payment_reference': 'cash-0001'})
    assert reconcile.json()['status'] == 'paid'
    assert supplier_order(client)['stage'] == 'awaiting_payout'

    assert pay(client, settlement['id'], 'payout-key-0001', 'MPESA-FIRST').status_code == 200
    row = supplier_order(client)
    assert row['stage'] == 'confirm_payout' and steps(row)['payout_sent']

    # The money did not arrive: operations are alerted and can send it again.
    missing = client.post(f"/api/v1/supplier/payouts/{settlement['id']}/confirm", headers=headers('supplier'),
        json={'received': False, 'note': 'Nothing on my M-Pesa yet'})
    assert missing.status_code == 200 and missing.json()['supplier_confirmation'] == 'not_received'
    assert supplier_order(client)['stage'] == 'payout_disputed'
    alerts = client.get('/api/v1/ops/alerts', headers=OPS).json()['items']
    assert any(alert['kind'] == 'payout' and 'Green Pastures' in alert['title'] for alert in alerts)
    listed = client.get('/api/v1/ops/settlements?status=not_received', headers=OPS).json()['items']
    assert [item['id'] for item in listed] == [settlement['id']] and listed[0]['supplier_note'] == 'Nothing on my M-Pesa yet'

    assert pay(client, settlement['id'], 'payout-key-0002', 'MPESA-SECOND').status_code == 200
    row = supplier_order(client)
    assert row['stage'] == 'confirm_payout'

    received = client.post(f"/api/v1/supplier/payouts/{settlement['id']}/confirm", headers=headers('supplier'), json={'received': True})
    assert received.status_code == 200
    detail = received.json()
    assert detail['supplier_confirmation'] == 'received'
    assert [(row['outcome'], row['payment_reference']) for row in detail['confirmations']] == [
        ('not_received', 'MPESA-FIRST'), ('received', 'MPESA-SECOND')]
    row = supplier_order(client)
    assert row['stage'] == 'payout_confirmed' and all(steps(row).values())

    # 'Received' is final, and a confirmed payout cannot be recorded again.
    again = client.post(f"/api/v1/supplier/payouts/{settlement['id']}/confirm", headers=headers('supplier'), json={'received': False})
    assert again.status_code == 409
    assert pay(client, settlement['id'], 'payout-key-0003', 'MPESA-THIRD').status_code != 200


def test_confirmation_history_is_append_only(client, sessions, seeded):
    id = order(sessions, seeded)
    advance(sessions, id, 'pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered')
    settlement = supplier_order(client)['settlements'][0]['id']
    pay(client, settlement, 'payout-key-0101', 'BANK-0101')
    client.post(f'/api/v1/supplier/payouts/{settlement}/confirm', headers=headers('supplier'), json={'received': True})
    with pytest.raises(DBAPIError):
        with sessions.begin() as db:
            db.execute(text("UPDATE payout_confirmations SET outcome = 'not_received'"))
    with sessions() as db:
        assert db.scalars(select(m.PayoutConfirmation.outcome)).all() == ['received']


def test_other_suppliers_cannot_confirm(client, sessions, seeded):
    id = order(sessions, seeded)
    advance(sessions, id, 'pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered')
    settlement = supplier_order(client)['settlements'][0]['id']
    pay(client, settlement, 'payout-key-0201', 'BANK-0201')
    with sessions.begin() as db:
        db.get(m.User, seeded['other']).roles = ['buyer', 'supplier']
    response = client.post(f'/api/v1/supplier/payouts/{settlement}/confirm', headers=headers('other'), json={'received': True})
    assert response.status_code in (403, 404)


def test_cancelled_order_stops_the_timeline(client, sessions, seeded):
    id = order(sessions, seeded)
    advance(sessions, id, 'cancelled')
    assert supplier_order(client)['stage'] == 'cancelled'
