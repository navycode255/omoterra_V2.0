from datetime import timedelta
from decimal import Decimal
import pytest
from app import models as m, notifications as notes
from test_commerce import headers, order

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-staff'}


@pytest.fixture(autouse=True)
def inline_pushes(monkeypatch):
    monkeypatch.setattr(notes, 'dispatch', lambda job: job())


def delivered_order(sessions, seeded, key, accepted=4, rejected=0):
    id = order(sessions, seeded, quantity=accepted + rejected, key=key)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        row.internal_status = 'delivered'
        for item in db.query(m.OrderItem).filter_by(order_id=id):
            item.actual_quantity, item.rejected_quantity = Decimal(accepted), Decimal(rejected)
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.completed_supplies_count += 1
    return id


def rate(client, id, stars, comment=''):
    return client.post(f'/api/v1/orders/{id}/rating', headers=headers(), json={'stars': stars, 'comment': comment})


def listing_reputation(client, seeded):
    return client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).json()['supplier']['reputation']


def test_buyer_rates_a_delivered_order_and_supplier_is_told(client, sessions, seeded):
    id = delivered_order(sessions, seeded, 'rate-order-01')
    detail = client.get(f'/api/v1/orders/{id}', headers=headers()).json()
    assert detail['can_rate'] is True and detail['rating'] is None
    rated = rate(client, id, 5, 'Healthy birds, on time')
    assert rated.status_code == 200, rated.text
    assert rated.json()['rating']['stars'] == 5
    inbox = client.get('/api/v1/notifications', headers=headers('supplier')).json()['items']
    assert any(n['kind'] == 'rating_new' for n in inbox)


def test_orders_not_yet_delivered_cannot_be_rated(client, sessions, seeded):
    id = order(sessions, seeded, key='rate-early-01')
    assert rate(client, id, 4).status_code == 409
    assert client.get(f'/api/v1/orders/{id}', headers=headers()).json()['can_rate'] is False


def test_only_the_buyer_who_ordered_can_rate(client, sessions, seeded):
    id = delivered_order(sessions, seeded, 'rate-other-01')
    response = client.post(f'/api/v1/orders/{id}/rating', headers=headers('other'), json={'stars': 1})
    assert response.status_code == 404


def test_one_rating_per_order_editable_for_two_weeks(client, sessions, seeded):
    id = delivered_order(sessions, seeded, 'rate-edit-01')
    rate(client, id, 2)
    assert rate(client, id, 4).json()['rating']['stars'] == 4
    with sessions.begin() as db:
        assert db.query(m.OrderRating).count() == 1
        db.query(m.OrderRating).one().created_at = m.now() - timedelta(days=15)
    assert rate(client, id, 1).status_code == 409
    assert client.get(f'/api/v1/orders/{id}', headers=headers()).json()['can_rate'] is False


def test_average_shows_only_after_three_ratings(client, sessions, seeded):
    ids = [delivered_order(sessions, seeded, f'rate-avg-0{i}', accepted=1) for i in range(3)]
    rate(client, ids[0], 5)
    rate(client, ids[1], 4)
    before = listing_reputation(client, seeded)
    assert before['rating'] is None and before['ratings'] == 2
    rate(client, ids[2], 3)
    after = listing_reputation(client, seeded)
    assert after['rating'] == 4.0 and after['ratings'] == 3 and after['deliveries'] == 3
    card = client.get('/api/v1/listings', headers=headers()).json()[0]['supplier_rating']
    assert card == {'rating': 4.0, 'ratings': 3}


def test_quality_share_comes_from_collection_checks(client, sessions, seeded):
    delivered_order(sessions, seeded, 'rate-quality-01', accepted=3, rejected=1)
    assert listing_reputation(client, seeded)['quality_passed'] == 75


def test_supplier_sees_comments_but_not_who_wrote_them(client, sessions, seeded):
    id = delivered_order(sessions, seeded, 'rate-private-01')
    rate(client, id, 4, 'Good weight, a little late')
    mine = client.get('/api/v1/supplier/reputation', headers=headers('supplier')).json()
    assert mine['reviews'][0]['comment'] == 'Good weight, a little late'
    assert 'buyer_id' not in mine['reviews'][0] and 'buyer_name' not in mine['reviews'][0]
    # Other buyers never get comments.
    assert 'reviews' not in listing_reputation(client, seeded)


def test_ops_can_hide_a_rating_and_it_stops_counting(client, sessions, seeded):
    ids = [delivered_order(sessions, seeded, f'rate-hide-0{i}', accepted=1) for i in range(3)]
    for i, id in enumerate(ids):
        rate(client, id, 1 if i == 0 else 5, 'rude words' if i == 0 else '')
    assert listing_reputation(client, seeded)['rating'] == pytest.approx(3.7)
    listed = client.get('/api/v1/ops/ratings', headers=OPS).json()['items']
    abusive = next(r for r in listed if r['comment'] == 'rude words')
    assert abusive['buyer_name'] == 'Buyer Test'
    hidden = client.patch(f"/api/v1/ops/ratings/{abusive['id']}", headers=OPS, json={'hidden': True})
    assert hidden.status_code == 200
    rep = listing_reputation(client, seeded)
    assert rep['ratings'] == 2 and rep['rating'] is None  # below the minimum again
    again = next(r for r in client.get('/api/v1/ops/ratings', headers=OPS).json()['items'] if r['id'] == abusive['id'])
    assert again['hidden'] is True and again['hidden_by'] == 'Test Staff'
    assert client.get('/api/v1/ops/ratings?status=hidden', headers=OPS).json()['total'] == 1
    assert client.get('/api/v1/ops/ratings?q=rude', headers=OPS).json()['total'] == 1
    assert client.get(f"/api/v1/ops/suppliers/{seeded['supplier']}", headers=OPS).json()['reputation']['ratings'] == 2
