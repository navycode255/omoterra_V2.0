"""Weight-banded market prices: publishing, validation, versions and the supplier view."""
from datetime import timedelta
from decimal import Decimal

from app import contracts as c, models as m

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
STAFF = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-staff'}
SUPPLIER = {'Authorization': 'Bearer supplier'}
API = '/api/v1'
TODAY = c.business_today()

# The ladder from the request: above 1.0 kg, 0.85-0.95 kg and below 0.80 kg.
LADDER = [
    {'label': 'Large', 'min_weight_kg': '1.0', 'max_weight_kg': None, 'price_per_unit': '6500'},
    {'label': 'Medium', 'min_weight_kg': '0.85', 'max_weight_kg': '0.95', 'price_per_unit': '6200'},
    {'label': 'Small', 'min_weight_kg': None, 'max_weight_kg': '0.80', 'price_per_unit': '5800'},
]


def publish(client, bands=LADDER, days=0, key='price-list-0001', headers=OPS, category='broilers', note=''):
    return client.post(API + '/ops/market-prices', headers={**headers, 'Idempotency-Key': key},
        json={'category': category, 'effective_from': str(TODAY + timedelta(days=days)), 'note': note, 'bands': bands})


def board(client, category='broilers', headers=SUPPLIER, path='/market-prices'):
    body = client.get(API + path, headers=headers).json()
    rows = body['categories'] if isinstance(body, dict) else body
    return next((row for row in rows if row['category'] == category), None)


def withdraw(client, id, key='price-withdraw-0001', reason='Market moved'):
    return client.post(API + f'/ops/market-prices/{id}/withdraw', headers={**OPS, 'Idempotency-Key': key}, json={'reason': reason})


def test_admin_publishes_ladder_and_supplier_sees_it_lightest_first(client, sessions, seeded):
    assert publish(client, headers=STAFF, key='staff-price-01').status_code == 403
    response = publish(client, note='Dar es Salaam live market')
    assert response.status_code == 201, response.text
    published = response.json()
    assert published['status'] == 'current' and published['unit_type'] == 'bird'

    prices = board(client)
    current = prices['current']
    assert [b['label'] for b in current['bands']] == ['Small', 'Medium', 'Large']
    assert [Decimal(b['price_per_unit']) for b in current['bands']] == [Decimal('5800'), Decimal('6200'), Decimal('6500')]
    # Weights between the bands have no price, and operations can see exactly which.
    assert [(Decimal(g['from_kg']), Decimal(g['to_kg'])) for g in current['gaps']] == \
        [(Decimal('0.80'), Decimal('0.85')), (Decimal('0.95'), Decimal('1.0'))]
    assert 'published_by' not in current  # staff names stay internal

    ops = board(client, headers=STAFF, path='/ops/market-prices')
    assert ops['current']['published_by'] and ops['current']['note'] == 'Dar es Salaam live market'
    with sessions() as db:
        notice = db.query(m.Notification).filter_by(user_id=seeded['supplier'], kind='market_prices_updated').one()
        assert notice.link == '/account'


def test_invalid_ladders_are_rejected(client, seeded):
    overlap = [{'min_weight_kg': '0.8', 'max_weight_kg': '1.0', 'price_per_unit': '6000'},
               {'min_weight_kg': '0.9', 'max_weight_kg': None, 'price_per_unit': '6500'}]
    two_open_tops = [{'min_weight_kg': '1.0', 'price_per_unit': '6500'}, {'min_weight_kg': '1.2', 'price_per_unit': '7000'}]
    backwards = [{'min_weight_kg': '1.0', 'max_weight_kg': '0.9', 'price_per_unit': '6000'}]
    no_weight = [{'price_per_unit': '6000'}, {'min_weight_kg': '1.0', 'price_per_unit': '6500'}]
    zero_price = [{'min_weight_kg': '1.0', 'price_per_unit': '0'}]
    for index, bands in enumerate([overlap, two_open_tops, backwards, no_weight, zero_price]):
        assert publish(client, bands=bands, key=f'bad-ladder-{index:04}').status_code == 422, bands
    assert publish(client, days=-1, key='past-price-01').status_code == 422
    assert publish(client, days=91, key='far-price-001').status_code == 422
    # One price for every weight is fine, and touching bands do not overlap.
    assert publish(client, bands=[{'price_per_unit': '6000'}], key='flat-price-01').status_code == 201
    touching = [{'max_weight_kg': '1.0', 'price_per_unit': '6000'}, {'min_weight_kg': '1.0', 'price_per_unit': '6500'}]
    assert publish(client, bands=touching, key='touch-price-1').status_code == 201
    assert board(client)['current']['gaps'] == []


def test_republishing_replaces_current_and_shows_previous_price(client, seeded):
    first = publish(client).json()
    raised = [{**band, 'price_per_unit': str(int(band['price_per_unit']) + 300)} if band['label'] == 'Large' else band for band in LADDER]
    second = publish(client, bands=raised, key='price-list-0002').json()
    current = board(client)['current']
    assert current['id'] == second['id']
    large = next(b for b in current['bands'] if b['label'] == 'Large')
    assert Decimal(large['price_per_unit']) == Decimal('6800') and Decimal(large['previous_price']) == Decimal('6500')

    history = client.get(API + '/ops/market-prices/history?category=broilers', headers=STAFF).json()
    assert history['total'] == 2
    assert [(row['id'], row['status']) for row in history['items']] == [(second['id'], 'current'), (first['id'], 'superseded')]
    assert withdraw(client, first['id']).status_code == 409


def test_scheduled_prices_and_withdrawal(client, seeded):
    today = publish(client).json()
    later = [{**band, 'price_per_unit': '7000'} for band in LADDER]
    scheduled = publish(client, bands=later, days=7, key='price-list-0003').json()
    assert scheduled['status'] == 'scheduled'
    prices = board(client)
    assert prices['current']['id'] == today['id'] and [row['id'] for row in prices['upcoming']] == [scheduled['id']]

    response = withdraw(client, scheduled['id'])
    assert response.status_code == 200 and response.json()['status'] == 'withdrawn'
    assert response.json()['withdraw_reason'] == 'Market moved'
    assert withdraw(client, scheduled['id']).json()['status'] == 'withdrawn'  # replayed, not repeated
    assert board(client)['upcoming'] == []

    # Withdrawing the only current list leaves the category without prices.
    assert withdraw(client, today['id'], key='price-withdraw-0002').status_code == 200
    assert board(client) is None


def test_publishing_is_idempotent(client, sessions, seeded):
    first = publish(client).json()
    again = publish(client)
    assert again.status_code == 201 and again.json()['id'] == first['id']
    with sessions() as db:
        assert db.query(m.MarketPriceList).count() == 1
        assert db.query(m.MarketPriceBand).count() == 3
