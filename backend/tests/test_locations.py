from sqlalchemy import select
from app import models as m
from test_commerce import headers


def address(label):
    return {'label': label, 'recipient_name': 'Buyer Test', 'phone': '+255712345678', 'region': 'Dar es Salaam',
            'district_area': 'Kinondoni', 'address_text': f'{label} gate'}


def test_buyers_have_one_default_delivery_address(client, sessions, seeded):
    with sessions.begin() as db:
        # The seeded buyer's existing address is not a default yet.
        db.get(m.Address, seeded['address']).deleted = True
    first = client.post('/api/v1/addresses', headers=headers(), json=address('Home')).json()
    second = client.post('/api/v1/addresses', headers=headers(), json=address('Shop')).json()
    assert first['is_default'] is True and second['is_default'] is False

    chosen = client.post(f"/api/v1/addresses/{second['id']}/default", headers=headers())
    assert chosen.status_code == 200 and chosen.json()['is_default'] is True
    listed = client.get('/api/v1/addresses', headers=headers()).json()
    assert [(row['label'], row['is_default']) for row in listed] == [('Shop', True), ('Home', False)]

    # Removing the default hands it to the address that is left.
    assert client.delete(f"/api/v1/addresses/{second['id']}", headers=headers()).status_code == 204
    assert [(row['label'], row['is_default']) for row in client.get('/api/v1/addresses', headers=headers()).json()] \
        == [('Home', True)]
    # Nobody else's address can be made default.
    assert client.post(f"/api/v1/addresses/{first['id']}/default", headers=headers('other')).status_code in (403, 404)


def test_supplier_moves_the_farm_pin_and_stays_approved(client, sessions, seeded):
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.verification = {'location_confirmed': True, 'location_visited': True, 'phone_confirmed': True}
    body = {'farm_latitude': '-6.781234', 'farm_longitude': '38.912345',
            'farm_map_url': 'https://www.google.com/maps/search/?api=1&query=-6.781234,38.912345',
            'internal_pickup_address': 'Maili Moja, past the school'}
    saved = client.put('/api/v1/supplier/farm-location', headers=headers('supplier'), json=body)
    assert saved.status_code == 200, saved.text
    assert saved.json()['internal_pickup_address'] == 'Maili Moja, past the school'
    with sessions() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        assert profile.status == 'approved'
        assert str(profile.farm_latitude) == '-6.781234'
        # Ops re-check the new pin; unrelated checks stay.
        assert profile.verification == {'location_confirmed': False, 'location_visited': False, 'phone_confirmed': True}
    bad = client.put('/api/v1/supplier/farm-location', headers=headers('supplier'),
        json={**body, 'farm_map_url': 'https://example.com/farm'})
    assert bad.status_code == 422
    assert client.put('/api/v1/supplier/farm-location', headers=headers(), json=body).status_code == 403
