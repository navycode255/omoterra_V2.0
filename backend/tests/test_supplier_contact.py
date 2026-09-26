from app import models as m

SUPPLIER = {'Authorization': 'Bearer supplier'}
DETAILS = {'alternate_phone': '+255655111222', 'preferred_contact_method': 'whatsapp',
           'internal_pickup_address': 'Plot 9, Kibaha road', 'pickup_instructions': 'Call on arrival'}


def test_contact_changes_keep_an_approved_supplier_approved(client, seeded, sessions):
    saved = client.put('/api/v1/supplier/contact', json=DETAILS, headers=SUPPLIER)
    assert saved.status_code == 200
    assert saved.json()['status'] == 'approved'
    assert saved.json()['preferred_contact_method'] == 'whatsapp'
    with sessions() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        assert (profile.status, profile.alternate_phone, profile.internal_pickup_address) == ('approved', '+255655111222', 'Plot 9, Kibaha road')


def test_a_new_pickup_address_needs_the_location_checked_again(client, seeded, sessions):
    with sessions.begin() as db:
        db.get(m.SupplierProfile, seeded['supplier']).verification = {'location_confirmed': True, 'location_visited': True, 'phone_confirmed': True}
    client.put('/api/v1/supplier/contact', json=DETAILS, headers=SUPPLIER)
    with sessions() as db:
        checks = db.get(m.SupplierProfile, seeded['supplier']).verification
    assert checks == {'location_confirmed': False, 'location_visited': False, 'phone_confirmed': True}


def test_same_address_keeps_location_checks(client, seeded, sessions):
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.verification = {'location_confirmed': True}
        address = profile.internal_pickup_address
    client.put('/api/v1/supplier/contact', json={**DETAILS, 'internal_pickup_address': address}, headers=SUPPLIER)
    with sessions() as db:
        assert db.get(m.SupplierProfile, seeded['supplier']).verification == {'location_confirmed': True}


def test_contact_details_are_validated_and_supplier_only(client):
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'alternate_phone': '0712'}, headers=SUPPLIER).status_code == 422
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'internal_pickup_address': 'x'}, headers=SUPPLIER).status_code == 422
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'public_alias': 'New name'}, headers=SUPPLIER).status_code == 422
    assert client.put('/api/v1/supplier/contact', json=DETAILS, headers={'Authorization': 'Bearer buyer'}).status_code == 403
