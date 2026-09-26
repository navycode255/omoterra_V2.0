import pytest
from sqlalchemy import select
from app import models as m
from app.config import settings
from test_supplier_onboarding import supplier_body, sample_batch, _jpeg

PASSPHRASE = 'field-onboarding-26'
BASE = '/api/v1/mobile-admin'


@pytest.fixture
def mobile_on(monkeypatch):
    monkeypatch.setattr(settings(), 'mobile_admin_passphrase', PASSPHRASE)


def sign_in(client, phone='+255710000001', passphrase=PASSPHRASE):
    started = client.post(f'{BASE}/auth/otp', json={'passphrase': passphrase, 'phone': phone})
    assert started.status_code == 200, started.text
    challenge = started.json()
    done = client.post(f'{BASE}/auth/verify', json={'challenge_id': challenge['challenge_id'],
        'code': challenge['development_code']})
    assert done.status_code == 200, done.text
    return {'X-Operator-Session': done.json()['session_token']}


def keyed(session, key):
    return {**session, 'Idempotency-Key': f'mobile-admin-{key}'}


def buyer_body(phone='+255713000001'):
    return {
        'phone': phone, 'name': 'Mama Asha', 'business_name': 'Asha Grill House', 'buyer_type': 'restaurant',
        'region': 'Dar es Salaam', 'area': 'Sinza',
        'preferences': {'preferred_products': ['broilers'], 'purchase_frequency': 'weekly',
                        'preferred_days': ['friday']},
        'last_known_buying_price': '11500', 'minimum_order': '50', 'payment_terms': 'Cash on delivery',
        'internal_notes': 'Met at Sinza market',
    }


def test_sign_in_needs_the_passphrase_and_an_operator_phone(client, mobile_on):
    wrong = client.post(f'{BASE}/auth/otp', json={'passphrase': 'not-the-one', 'phone': '+255710000001'})
    assert wrong.status_code == 403
    stranger = client.post(f'{BASE}/auth/otp', json={'passphrase': PASSPHRASE, 'phone': '+255719999999'})
    assert stranger.status_code == 403
    session = sign_in(client)
    me = client.get(f'{BASE}/me', headers=session)
    assert me.json()['name'] == 'Test Admin'
    # The dashboard's server token is never needed, and never granted.
    assert client.get('/api/v1/ops/suppliers', headers=session).status_code == 403


def test_off_when_no_passphrase_is_configured(client, monkeypatch):
    monkeypatch.setattr(settings(), 'mobile_admin_passphrase', '')
    assert client.post(f'{BASE}/auth/otp', json={'passphrase': 'anything', 'phone': '+255710000001'}).status_code == 403
    assert client.get(f'{BASE}/me', headers={'X-Operator-Session': 'ops-admin'}).status_code == 403


def test_wrong_passphrases_lock_mobile_sign_in_but_not_admin_setup(client, mobile_on, monkeypatch):
    monkeypatch.setattr(settings(), 'admin_setup_passphrase', 'correct horse battery staple')
    for _ in range(5):
        client.post(f'{BASE}/auth/otp', json={'passphrase': 'guess', 'phone': '+255710000001'})
    locked = client.post(f'{BASE}/auth/otp', json={'passphrase': PASSPHRASE, 'phone': '+255710000001'})
    assert locked.status_code == 429
    setup = client.post('/api/v1/ops/setup/start', headers={'X-Ops-Token': 'test-operator-secret'},
        json={'passphrase': 'correct horse battery staple'})
    assert setup.status_code == 200


def test_operator_registers_a_full_supplier_and_sees_them_listed(client, sessions, seeded, mobile_on):
    session = sign_in(client)
    photo = client.post('/api/v1/referrals/photos', headers=session,
        files={'file': ('farm.jpg', _jpeg(), 'image/jpeg')}).json()['url']
    body = supplier_body('+255713000010', current_batch=sample_batch())
    body['evidence_photos'] = [photo]
    created = client.post('/api/v1/referrals/supplier', headers=keyed(session, 'm-sup-1'), json=body)
    assert created.status_code == 201, created.text
    assert created.json()['business_name'] == 'JM Poultry Supply'
    retried = client.post('/api/v1/referrals/supplier', headers=keyed(session, 'm-sup-1'), json=body)
    assert retried.json()['id'] == created.json()['id']
    # Registration is confirmed; the supplier's own verification is not.
    assert created.json()['status'] == 'confirmed'
    assert created.json()['supplier_status'] == 'under_review'
    with sessions() as db:
        referral = db.get(m.Referral, created.json()['id'])
        assert referral.source == 'admin' and referral.role_requested == 'supplier'
        assert referral.referred_by_operator_id == seeded['operator_admin']
        user = db.get(m.User, referral.target_user_id)
        profile = db.get(m.SupplierProfile, user.id)
        assert profile.internal_notes == 'Staff introduction visit'
        assert profile.created_by_actor == 'ops'
        assert db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == user.id)) is not None
        assert db.scalar(select(m.OpsAuditEntry).where(
            m.OpsAuditEntry.operator_id == seeded['operator_admin'],
            m.OpsAuditEntry.path.endswith('/referrals/supplier'))) is not None
    listed = client.get('/api/v1/referrals/mine', headers=session).json()
    assert [row['phone'] for row in listed] == ['+255713000010']


def test_operator_registers_a_buyer_with_the_crm_record(client, sessions, seeded, mobile_on):
    session = sign_in(client)
    created = client.post('/api/v1/referrals/buyer', headers=keyed(session, 'm-buy-1'), json=buyer_body())
    assert created.status_code == 201, created.text
    with sessions() as db:
        referral = db.get(m.Referral, created.json()['id'])
        assert referral.referred_by_operator_id == seeded['operator_admin']
        user = db.get(m.User, referral.target_user_id)
        assert user.roles == ['buyer'] and user.buyer_type == 'restaurant'
        crm = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == user.id))
        assert crm.business_name == 'Asha Grill House' and crm.contact_person == 'Mama Asha'
        assert crm.preferences['purchase_frequency'] == 'weekly'
    again = client.post('/api/v1/referrals/buyer', headers=keyed(session, 'm-buy-2'), json=buyer_body())
    assert again.status_code == 409
    # The buyer later signs in with their own phone and lands on the same account.
    listed = client.get('/api/v1/referrals/mine', headers=session).json()
    assert listed[0]['business_name'] == 'Asha Grill House'


def test_each_operator_sees_only_their_own_registrations(client, mobile_on):
    admin = sign_in(client)
    staff = sign_in(client, '+255710000002')
    client.post('/api/v1/referrals/buyer', headers=keyed(admin, 'm-own-1'), json=buyer_body('+255713000020'))
    client.post('/api/v1/referrals/buyer', headers=keyed(staff, 'm-own-2'), json=buyer_body('+255713000021'))
    assert [r['phone'] for r in client.get('/api/v1/referrals/mine', headers=admin).json()] == ['+255713000020']
    assert [r['phone'] for r in client.get('/api/v1/referrals/mine', headers=staff).json()] == ['+255713000021']


def test_an_existing_member_referred_for_a_new_role_gets_a_row_for_that_role(client, sessions, seeded, mobile_on):
    session = sign_in(client)
    with sessions() as db:
        phone = db.get(m.User, seeded['supplier']).phone
    created = client.post('/api/v1/referrals/buyer', headers=keyed(session, 'm-exist'), json=buyer_body(phone))
    assert created.status_code == 201, created.text
    with sessions() as db:
        assert db.get(m.User, seeded['supplier']).roles == ['buyer', 'supplier']
        rows = db.scalars(select(m.Referral).where(m.Referral.target_user_id == seeded['supplier'])).all()
        # They signed up as a supplier themselves; only the buyer role was referred.
        assert [(r.role_requested, r.source) for r in rows] == [('buyer', 'admin')]


def test_members_cannot_refer_yet(client):
    member = {'Authorization': 'Bearer buyer', 'Idempotency-Key': 'member-referral-1'}
    assert client.post('/api/v1/referrals/buyer', headers=member, json=buyer_body()).status_code == 403
    assert client.get('/api/v1/referrals/mine', headers=member).status_code == 403


def test_a_referral_is_visible_only_to_its_referrer(client, mobile_on):
    admin = sign_in(client)
    staff = sign_in(client, '+255710000002')
    created = client.post('/api/v1/referrals/buyer', headers=keyed(admin, 'm-view'), json=buyer_body()).json()
    assert client.get(f"/api/v1/referrals/{created['id']}", headers=admin).json()['business_name'] == 'Asha Grill House'
    assert client.get(f"/api/v1/referrals/{created['id']}", headers=staff).status_code == 404
