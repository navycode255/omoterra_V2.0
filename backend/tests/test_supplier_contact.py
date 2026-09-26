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


def test_payout_options_are_kept_and_never_ask_for_accounts(client, seeded, sessions):
    saved = client.put('/api/v1/supplier/contact', json={**DETAILS, 'payout_methods': ['mpesa', 'bank_transfer', 'mpesa']}, headers=SUPPLIER)
    assert saved.status_code == 200 and saved.json()['payout_methods'] == ['mpesa', 'bank_transfer']
    # Leaving them out keeps the choice.
    client.put('/api/v1/supplier/contact', json=DETAILS, headers=SUPPLIER)
    with sessions() as db:
        assert db.get(m.SupplierProfile, seeded['supplier']).payout_methods == ['mpesa', 'bank_transfer']
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'payout_methods': []}, headers=SUPPLIER).status_code == 422
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'payout_methods': ['paypal']}, headers=SUPPLIER).status_code == 422
    assert client.put('/api/v1/supplier/contact', json={**DETAILS, 'account_number': '123'}, headers=SUPPLIER).status_code == 422


def test_a_profile_save_without_payout_options_does_not_erase_them(client, seeded, sessions):
    with sessions.begin() as db:
        db.get(m.SupplierProfile, seeded['supplier']).payout_methods = ['airtel_money']
    profile = client.get('/api/v1/supplier/profile', headers=SUPPLIER).json()
    body = {k: profile[k] for k in ('public_alias', 'legal_name', 'alternate_phone', 'region', 'district', 'general_area', 'categories',
        'primary_category', 'production_profile', 'production_frequency', 'internal_pickup_address', 'pickup_instructions',
        'omoterra_pickup', 'supplier_transport', 'supply_forms', 'preferred_contact_method', 'operating_notes')}
    # The seeded profile has no region or main category, which a full save refuses.
    body.update(region='Pwani', primary_category='broilers')
    saved = client.put('/api/v1/supplier/profile', json=body, headers=SUPPLIER)
    assert saved.status_code == 200, saved.text
    with sessions() as db:
        assert db.get(m.SupplierProfile, seeded['supplier']).payout_methods == ['airtel_money']
