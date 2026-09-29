"""Sales staff record, the debts ledger, installments and the finance overview."""
from decimal import Decimal
from io import BytesIO

import pytest
from PIL import Image

from app import contracts as c, models as m, notifications as notes

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
STAFF = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-staff'}
API = '/api/v1/ops'
TODAY = c.business_today().isoformat()
_keys = iter(range(10**6))


def key():
    return f'finance-key-{next(_keys):06d}'


def post(client, path, body, headers=OPS, idem=None):
    return client.post(API + path, json=body, headers={**headers, 'Idempotency-Key': idem or key()})


def sale(client, **overrides):
    body = {'new_buyer': {'business_name': 'Mama Asha Restaurant', 'phone': '0754 111 222', 'region': 'dar es salaam'},
            'sold_on': TODAY,
            'items': [{'category': 'local_chicken', 'unit': 'bird', 'quantity': '20', 'unit_price': '15000'}]}
    body.update(overrides)
    response = post(client, '/sales', body)
    assert response.status_code == 201, response.text
    return response.json()


def pay(client, debt_id, amount, **extra):
    return post(client, f'/ledger/debts/{debt_id}/payments',
        {'amount': amount, 'paid_on': TODAY, 'method': 'cash', **extra})


def receivable(body):
    return next(d for d in body['debts'] if d['direction'] == 'receivable')


def test_sale_to_new_buyer_keeps_buyer_and_opens_receivable(client, sessions):
    body = sale(client)
    assert body['sale_number'].startswith('SL-')
    assert Decimal(body['total_amount']) == Decimal('300000.00')
    assert Decimal(body['balance']) == Decimal('300000.00')
    assert body['buyer_phone'] == '+255754111222'
    debt = receivable(body)
    assert debt['party_kind'] == 'buyer' and debt['status'] == 'open'
    with sessions() as db:
        profile = db.get(m.BuyerProfile, body['buyer_profile_id'])
        # Kept as a buyer record for later sales and promotions.
        assert profile.business_name == 'Mama Asha Restaurant' and profile.region == 'Dar es Salaam'
    # The same phone later is the same buyer, not a duplicate.
    again = sale(client, new_buyer={'business_name': 'Asha', 'phone': '+255754111222'})
    assert again['buyer_profile_id'] == body['buyer_profile_id']


def test_sale_to_existing_app_buyer_creates_their_record_once(client, seeded):
    first = sale(client, new_buyer=None, buyer_user_id=seeded['buyer'])
    second = sale(client, new_buyer=None, buyer_user_id=seeded['buyer'])
    assert first['buyer_profile_id'] == second['buyer_profile_id']
    assert first['buyer_name'] == 'Buyer Test'
    by_profile = sale(client, new_buyer=None, buyer_profile_id=first['buyer_profile_id'])
    assert by_profile['buyer_user_id'] == seeded['buyer']


def test_installments_until_settled_and_no_overpayment(client):
    body = sale(client, payment={'amount': '100000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'QX1'})
    debt = receivable(body)
    assert Decimal(debt['paid_amount']) == Decimal('100000') and debt['status'] == 'open'
    over = pay(client, debt['id'], '200000.01')
    assert over.status_code == 422 and 'TZS 200,000.00' in over.json()['detail']
    duplicate = pay(client, debt['id'], '1000', method='mpesa', reference='QX1')
    assert duplicate.status_code == 409
    assert pay(client, debt['id'], '150000').status_code == 201
    done = pay(client, debt['id'], '50000')
    assert done.status_code == 201
    assert done.json()['status'] == 'settled' and Decimal(done.json()['balance']) == 0
    assert len(done.json()['payments']) == 3
    assert pay(client, debt['id'], '1').status_code == 422


def test_same_key_retried_records_once(client):
    debt = receivable(sale(client))
    idem = 'retry-same-payment-01'
    body = {'amount': '5000', 'paid_on': TODAY, 'method': 'cash'}
    assert post(client, f"/ledger/debts/{debt['id']}/payments", body, idem=idem).status_code == 201
    again = post(client, f"/ledger/debts/{debt['id']}/payments", body, idem=idem)
    assert again.status_code == 201 and Decimal(again.json()['paid_amount']) == Decimal('5000')


def test_supplier_cost_lines_open_payables_per_supplier(client, seeded):
    body = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '12000',
         'supplier_id': seeded['supplier'], 'unit_cost': '9000'},
        {'description': 'Local hens', 'unit': 'bird', 'quantity': '5', 'unit_price': '20000',
         'supplier_id': seeded['supplier'], 'unit_cost': '15000'},
        {'description': 'Eggs', 'unit': 'tray', 'quantity': '2', 'unit_price': '12000',
         'supplier_name': 'Mzee Juma', 'unit_cost': '9000'},
        {'description': 'Own stock goat', 'unit': 'animal', 'quantity': '1', 'unit_price': '150000'},
    ])
    assert Decimal(body['total_amount']) == Decimal('394000.00')
    assert Decimal(body['cost_amount']) == Decimal('183000.00')
    assert Decimal(body['margin']) == Decimal('211000.00')
    payables = {d['party_name']: d for d in body['debts'] if d['direction'] == 'payable'}
    assert Decimal(payables['Secret legal name']['amount']) == Decimal('165000.00')
    assert payables['Secret legal name']['supplier_id'] == seeded['supplier']
    assert Decimal(payables['Mzee Juma']['amount']) == Decimal('18000.00')
    assert payables['Mzee Juma']['party_kind'] == 'other'
    assert Decimal(body['supplier_balance']) == Decimal('183000.00')



def test_stock_bought_for_sale_can_be_recorded_paid_or_owed(client, seeded):
    body = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '5', 'unit_price': '15000',
         'supplier_id': seeded['supplier'], 'unit_cost': '10000',
         'cost_payment': {'paid_on': TODAY, 'method': 'mpesa', 'reference': 'BUY-ORDER-01'}},
        {'description': 'Extra birds', 'unit': 'bird', 'quantity': '2', 'unit_price': '15000',
         'supplier_id': seeded['supplier'], 'unit_cost': '10000',
         'cost_payment': {'paid_on': TODAY, 'method': 'mpesa', 'reference': 'BUY-ORDER-01'}},
        {'description': 'Egg trays', 'unit': 'tray', 'quantity': '2', 'unit_price': '12000',
         'supplier_name': 'Mzee Juma', 'unit_cost': '9000'},
    ])
    assert Decimal(body['total_amount']) == Decimal('129000.00')
    assert Decimal(body['cost_amount']) == Decimal('88000.00')
    assert Decimal(body['margin']) == Decimal('41000.00')
    debts = {row['party_name']: row for row in body['debts'] if row['direction'] == 'payable'}
    paid = debts['Secret legal name']
    assert paid['status'] == 'settled' and Decimal(paid['paid_amount']) == Decimal('70000.00')
    assert len(paid['payments']) == 1 and paid['payments'][0]['reference'] == 'BUY-ORDER-01'
    assert Decimal(debts['Mzee Juma']['balance']) == Decimal('18000.00')
    assert Decimal(body['supplier_balance']) == Decimal('18000.00')


def test_sale_can_be_edited_without_losing_payments(client, seeded):
    original = sale(client, payment={'amount': '20000', 'paid_on': TODAY, 'method': 'cash'}, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '5', 'unit_price': '15000',
         'supplier_id': seeded['supplier'], 'unit_cost': '10000'}])
    supplier_debt = next(row for row in original['debts'] if row['direction'] == 'payable')
    assert pay(client, supplier_debt['id'], '10000').status_code == 201

    changed = client.put(API + f"/sales/{original['id']}", headers=OPS, json={
        'buyer_profile_id': original['buyer_profile_id'], 'sold_on': TODAY, 'notes': 'Corrected quantities',
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '6', 'unit_price': '16000',
                   'supplier_id': seeded['supplier'], 'unit_cost': '11000'}],
    })
    assert changed.status_code == 200, changed.text
    body = changed.json()
    assert Decimal(body['total_amount']) == Decimal('96000.00')
    assert Decimal(body['cost_amount']) == Decimal('66000.00')
    assert Decimal(body['margin']) == Decimal('30000.00')
    assert Decimal(receivable(body)['paid_amount']) == Decimal('20000.00')
    payable = next(row for row in body['debts'] if row['direction'] == 'payable' and row['status'] != 'cancelled')
    assert payable['id'] == supplier_debt['id'] and Decimal(payable['paid_amount']) == Decimal('10000.00')

    too_small = client.put(API + f"/sales/{original['id']}", headers=OPS, json={
        'buyer_profile_id': original['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '10000',
                   'supplier_id': seeded['supplier'], 'unit_cost': '5000'}],
    })
    assert too_small.status_code == 422

def test_editing_sale_reassigns_paid_supplier_debt(client, seeded, sessions):
    original = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '7000',
         'supplier_id': seeded['supplier'], 'unit_cost': '6500'}])
    old_debt = next(row for row in original['debts'] if row['direction'] == 'payable')
    assert pay(client, old_debt['id'], '19500').status_code == 201

    with sessions.begin() as db:
        replacement = m.User(phone='+255712345681', roles=['supplier'], name='Replacement Supplier', region='Morogoro')
        db.add(replacement); db.flush()
        db.add(m.SupplierProfile(user_id=replacement.id, legal_name='New Supplier', public_alias='New Farm',
            status='approved', categories=['broilers'], district='Morogoro', internal_pickup_address='New farm'))
        replacement_id = replacement.id

    changed = client.put(API + f"/sales/{original['id']}", headers=OPS, json={
        'buyer_profile_id': original['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '7000',
                   'supplier_id': replacement_id, 'unit_cost': '6500'}],
    })
    assert changed.status_code == 200, changed.text
    body = changed.json()
    assert body['items'][0]['supplier_id'] == replacement_id
    debt = next(row for row in body['debts'] if row['direction'] == 'payable' and row['status'] != 'cancelled')
    assert debt['id'] == old_debt['id']
    assert debt['supplier_id'] == replacement_id
    assert debt['party_name'] == 'New Supplier'
    assert Decimal(debt['paid_amount']) == Decimal('19500')
    assert debt['status'] == 'settled'

def test_sale_supplier_debt_can_be_reconciled_as_recording_error(client, seeded):
    original = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '7000',
         'supplier_id': seeded['supplier'], 'unit_cost': '6500'}])
    debt = next(row for row in original['debts'] if row['direction'] == 'payable')

    staff = post(client, f"/ledger/debts/{debt['id']}/cancel", {'reason': 'Wrong supplier cost'}, STAFF)
    assert staff.status_code == 403
    reconciled = post(client, f"/ledger/debts/{debt['id']}/cancel", {'reason': 'Wrong supplier cost'})
    assert reconciled.status_code == 200, reconciled.text
    assert reconciled.json()['status'] == 'cancelled'
    assert reconciled.json()['cancel_reason'] == 'Wrong supplier cost'

    refreshed = client.get(API + f"/sales/{original['id']}", headers=OPS).json()
    assert Decimal(refreshed['cost_amount']) == 0
    assert Decimal(refreshed['margin']) == Decimal('21000')
    assert refreshed['items'][0]['supplier_id'] is None
    assert refreshed['items'][0]['unit_cost'] is None
    assert Decimal(refreshed['supplier_balance']) == 0


def test_paid_supplier_debt_must_be_reversed_before_reconciliation(client, seeded):
    original = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '10000',
         'supplier_id': seeded['supplier'], 'unit_cost': '6000'}])
    debt = next(row for row in original['debts'] if row['direction'] == 'payable')
    payment = pay(client, debt['id'], '12000').json()['payments'][0]
    blocked = post(client, f"/ledger/debts/{debt['id']}/cancel", {'reason': 'Wrong supplier cost'})
    assert blocked.status_code == 409
    assert post(client, f"/ledger/payments/{payment['id']}/reverse", {'reason': 'Payment attached in error'}).status_code == 200
    assert post(client, f"/ledger/debts/{debt['id']}/cancel", {'reason': 'Wrong supplier cost'}).status_code == 200

def test_one_supplier_payment_covers_many_invoices_and_is_visible_to_supplier(client, seeded):
    first = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '12000',
        'supplier_id': seeded['supplier'], 'unit_cost': '9000'}])
    second = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '12000',
        'supplier_id': seeded['supplier'], 'unit_cost': '8000'}])
    debts = [next(row for row in sale_['debts'] if row['direction'] == 'payable') for sale_ in (first, second)]

    raw = BytesIO()
    Image.new('RGB', (32, 20), (30, 120, 70)).save(raw, 'JPEG')
    receipt = client.post(API + '/ledger/supplier-payment-receipts', headers=OPS,
        files={'file': ('receipt.jpg', raw.getvalue(), 'image/jpeg')})
    assert receipt.status_code == 201, receipt.text

    payment = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", {
        'amount': '100000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'MPESA-GROUP-01',
        'sms_text': 'Confirmed. TZS 100,000 sent to supplier.', 'debt_ids': [row['id'] for row in debts],
        'receipt_media_id': receipt.json()['id'],
    })
    assert payment.status_code == 201, payment.text

    refreshed = [client.get(API + f"/ledger/debts/{row['id']}", headers=OPS).json() for row in debts]
    assert refreshed[0]['status'] == 'settled' and Decimal(refreshed[0]['paid_amount']) == Decimal('90000')
    assert refreshed[1]['status'] == 'open' and Decimal(refreshed[1]['paid_amount']) == Decimal('10000')

    dashboard = client.get('/api/v1/supplier/invoices', headers={'Authorization': 'Bearer supplier'}).json()
    assert Decimal(dashboard['pending_total']) == Decimal('70000')
    assert Decimal(dashboard['paid_total']) == Decimal('100000')
    assert len(dashboard['invoices']) == 2
    allocations = [payment for invoice in dashboard['invoices'] for payment in invoice['payments']]
    assert sum((Decimal(row['amount']) for row in allocations), Decimal('0')) == Decimal('100000')
    assert {row['reference'] for row in allocations} == {'MPESA-GROUP-01'}
    assert all('Confirmed.' in row['sms_text'] for row in allocations)
    assert all(row['has_receipt'] for row in allocations)
    proof = client.get(f"/api/v1/supplier/payments/{allocations[0]['supplier_payment_id']}/receipt",
        headers={'Authorization': 'Bearer supplier'})
    assert proof.status_code == 200 and proof.json()['content_type'] == 'image/jpeg'


def test_supplier_payment_needs_proof_and_cannot_cross_suppliers(client, seeded):
    body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '12000',
        'supplier_id': seeded['supplier'], 'unit_cost': '9000'}])
    debt = next(row for row in body['debts'] if row['direction'] == 'payable')
    no_proof = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", {
        'amount': '1000', 'paid_on': TODAY, 'method': 'cash', 'debt_ids': [debt['id']],
    })
    assert no_proof.status_code == 422
    wrong_supplier = post(client, f"/ledger/suppliers/{seeded['other']}/payments", {
        'amount': '1000', 'paid_on': TODAY, 'method': 'cash', 'reference': 'CASH-01', 'debt_ids': [debt['id']],
    })
    assert wrong_supplier.status_code == 422


def test_bad_lines_are_refused(client, seeded):
    base = {'new_buyer': {'business_name': 'X Shop'}, 'sold_on': TODAY}
    cost_without_supplier = post(client, '/sales', {**base, 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '1', 'unit_cost': '1'}]})
    assert cost_without_supplier.status_code == 422
    half_bird = post(client, '/sales', {**base, 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '1.5', 'unit_price': '1'}]})
    assert half_bird.status_code == 422
    not_a_supplier = post(client, '/sales', {**base, 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '2', 'supplier_id': seeded['buyer'], 'unit_cost': '1'}]})
    assert not_a_supplier.status_code == 422
    future = post(client, '/sales', {**base, 'sold_on': '2999-01-01', 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '1'}]})
    assert future.status_code == 422
    two_buyers = post(client, '/sales', {**base, 'buyer_user_id': seeded['buyer'], 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '1'}]})
    assert two_buyers.status_code == 422


def test_reversal_and_cancel_are_admin_only_and_keep_history(client):
    body = sale(client, payment={'amount': '1000', 'paid_on': TODAY, 'method': 'cash'})
    debt = receivable(body)
    payment_id = debt['payments'][0]['id']
    # Nothing is cancelled while money is recorded against it.
    assert post(client, f"/sales/{body['id']}/cancel", {'reason': 'Entered twice'}).status_code == 409
    assert post(client, f'/ledger/payments/{payment_id}/reverse', {'reason': 'Wrong sale'}, STAFF).status_code == 403
    reversed_ = post(client, f'/ledger/payments/{payment_id}/reverse', {'reason': 'Wrong sale'})
    assert reversed_.status_code == 200
    assert Decimal(reversed_.json()['paid_amount']) == 0
    assert reversed_.json()['payments'][0]['reversed'] is True
    assert post(client, f'/ledger/payments/{payment_id}/reverse', {'reason': 'again'}).status_code == 409
    assert post(client, f"/sales/{body['id']}/cancel", {'reason': 'Entered twice'}, STAFF).status_code == 403
    cancelled = post(client, f"/sales/{body['id']}/cancel", {'reason': 'Entered twice'})
    assert cancelled.status_code == 200 and cancelled.json()['status'] == 'cancelled'
    assert all(d['status'] == 'cancelled' for d in cancelled.json()['debts'])
    assert pay(client, debt['id'], '1').status_code == 409


def test_manual_debts_both_ways(client, seeded):
    lend = post(client, '/ledger/debts', {'direction': 'receivable', 'party_name': 'Juma (driver)',
        'description': 'Advance on salary', 'amount': '50000', 'incurred_on': TODAY, 'due_on': '2020-01-01'})
    assert lend.status_code == 201, lend.text
    assert lend.json()['overdue'] is True
    owe = post(client, '/ledger/debts', {'direction': 'payable', 'party_kind': 'supplier', 'supplier_id': seeded['supplier'],
        'description': 'Feed on credit', 'amount': '80000', 'incurred_on': TODAY}, STAFF)
    assert owe.status_code == 201 and owe.json()['party_name'] == 'Secret legal name'
    nameless = post(client, '/ledger/debts', {'direction': 'payable', 'description': 'Transport', 'amount': '1', 'incurred_on': TODAY})
    assert nameless.status_code == 422
    assert pay(client, owe.json()['id'], '30000', method='bank_transfer').status_code == 201
    listed = client.get(API + '/ledger/debts?status=i_owe', headers=OPS).json()
    assert [d['id'] for d in listed['items']] == [owe.json()['id']]
    assert Decimal(listed['items'][0]['balance']) == Decimal('50000.00')
    # A sale's debt is cancelled through its sale; a manual one directly.
    assert post(client, f"/ledger/debts/{lend.json()['id']}/cancel", {'reason': 'Forgiven'}).status_code == 200


def test_summary_adds_up_every_shilling(client, seeded, sessions):
    from test_commerce import order
    order(sessions, seeded)  # a marketplace order: TZS 48,000 still owed by its buyer
    first = sale(client, items=[{'category': 'local_chicken', 'unit': 'bird', 'quantity': '10', 'unit_price': '15000',
        'supplier_name': 'Mzee Juma', 'unit_cost': '10000'}],
        payment={'amount': '60000', 'paid_on': TODAY, 'method': 'mpesa'})
    payable = next(d for d in first['debts'] if d['direction'] == 'payable')
    assert pay(client, payable['id'], '40000').status_code == 201
    second = sale(client, new_buyer={'business_name': 'Hotel Bahari'})
    assert pay(client, receivable(second)['id'], '100000', method='cash').status_code == 201
    body = client.get(API + '/finance/summary', headers=STAFF).json()
    assert Decimal(body['today']['sales']) == Decimal('450000.00')
    assert body['today']['sales_count'] == 2
    assert Decimal(body['today']['money_in']) == Decimal('160000.00')
    assert Decimal(body['today']['money_out']) == Decimal('40000.00')
    # Sales less money in, plus the marketplace buyer.
    assert Decimal(body['owed_to_me']['ledger']) == Decimal('290000.00')
    assert Decimal(body['owed_to_me']['marketplace']) == Decimal('48000.00')
    assert Decimal(body['owed_to_me']['total']) == Decimal('338000.00')
    assert Decimal(body['i_owe']['ledger']) == Decimal('60000.00')
    debtors = {p['party_name']: Decimal(p['balance']) for p in body['debtors']}
    assert debtors == {'Hotel Bahari': Decimal('200000.00'), 'Mama Asha Restaurant': Decimal('90000.00')}
    methods = {row['method']: row for row in body['by_method']}
    assert Decimal(methods['cash']['net']) == Decimal('60000.00')
    assert Decimal(methods['mpesa']['in']) == Decimal('60000.00')
    book = client.get(API + '/ledger/payments?status=in', headers=OPS).json()
    assert book['counts'] == {'all': 3, 'in': 2, 'out': 1, 'reversed': 0}
    sales = client.get(API + '/sales?status=unpaid&q=bahari', headers=OPS).json()
    assert [s['id'] for s in sales['items']] == [second['id']]


def test_ledger_rows_cannot_be_overpaid_even_bypassing_the_api(sessions, client):
    from sqlalchemy.exc import IntegrityError
    debt_id = receivable(sale(client))['id']
    with pytest.raises(IntegrityError):
        with sessions.begin() as db:
            db.get(m.LedgerDebt, debt_id).paid_amount = Decimal('300000.01')


@pytest.fixture
def inline(monkeypatch):
    monkeypatch.setattr(notes, 'dispatch', lambda job: job())


def test_promotion_reaches_buyers_including_offline_ones(client, seeded, sessions, inline):
    sale(client)  # an offline buyer with a phone
    post(client, '/promotions/opt-outs', {'phone': '0712345679'})  # the other app buyer
    size = client.get(API + '/promotions/audience?who=buyers', headers=OPS).json()
    assert size['numbers'] == 2 and size['with_app'] == 1
    assert post(client, '/promotions', {'audience': 'buyers', 'title': 'Kuku offer', 'message': 'Local chicken 14,000 this week'},
        STAFF).status_code == 403
    created = post(client, '/promotions', {'audience': 'buyers', 'title': 'Kuku offer', 'message': 'Local chicken 14,000 this week'})
    assert created.status_code == 201, created.text
    body = created.json()
    assert body['recipient_count'] == 2 and body['in_app_count'] == 1
    detail = client.get(API + f"/promotions/{body['id']}", headers=OPS).json()
    phones = {r['phone'] for r in detail['recipients']}
    assert phones == {'+255712345678', '+255754111222'}
    # Test servers have no SMS provider: honestly marked, not "sent".
    assert detail['sms'] == {'queued': 0, 'sent': 0, 'failed': 0, 'skipped': 2}
    with sessions() as db:
        note = db.query(m.Notification).filter_by(user_id=seeded['buyer'], kind='promotion').one()
        assert (note.title, note.body) == ('Kuku offer', 'Local chicken 14,000 this week')


def test_promotion_sms_sent_through_sema(client, seeded, inline, monkeypatch):
    from app import sms
    from app.config import settings
    sent = []
    monkeypatch.setattr(settings(), 'sms_provider', 'sema')

    def fake_send(phone, text, reference='', validity_seconds=None):
        if phone == '+255712345680':
            raise sms.SmsNotSent('no balance')
        sent.append((phone, text, validity_seconds))
    monkeypatch.setattr(sms, 'send', fake_send)
    body = post(client, '/promotions', {'audience': 'everyone', 'title': 'Hello', 'message': 'Omoterra market day Saturday',
        'send_in_app': False}).json()
    # The answer comes before the queue is sent; the queue follows the commit.
    assert body['sms']['queued'] == 3
    detail = lambda: client.get(API + f"/promotions/{body['id']}", headers=OPS).json()
    assert detail()['sms'] == {'queued': 0, 'sent': 2, 'failed': 1, 'skipped': 0}
    assert all(v == 86400 for _, _, v in sent)
    assert client.post(API + f"/promotions/{body['id']}/retry", headers=OPS).status_code == 200
    failed = [r for r in detail()['recipients'] if r['sms_status'] == 'failed']
    assert len(failed) == 1 and failed[0]['sms_attempts'] == 2 and failed[0]['sms_error'] == 'no balance'


def expense(client, headers=OPS, **overrides):
    body = {'spent_on': TODAY, 'category': 'labour', 'description': 'Three helpers for chicken prep',
            'amount': '30000', 'paid_to': 'Helpers', 'payment': {'amount': '30000', 'paid_on': TODAY, 'method': 'cash'}}
    body.update(overrides)
    response = post(client, '/expenses', body, headers)
    assert response.status_code == 201, response.text
    return response.json()


def test_expenses_paid_or_owed_feed_cash_book_and_debts(client):
    paid = expense(client, headers=STAFF)
    assert paid['status'] == 'settled' and paid['expense_category'] == 'labour'
    owed = expense(client, category='transport', description='Pickup truck to market', amount='25000',
        paid_to='Juma transport', payment=None)
    assert owed['status'] == 'open' and Decimal(owed['balance']) == Decimal('25000.00')
    body = client.get(API + f'/expenses?start={TODAY}&end={TODAY}', headers=OPS).json()
    assert Decimal(body['total']) == Decimal('55000.00')
    assert {r['category']: Decimal(r['owed']) for r in body['by_category']} == {'labour': 0, 'transport': Decimal('25000.00')}
    book = client.get(API + '/ledger/payments?status=out', headers=OPS).json()
    assert [Decimal(p['amount']) for p in book['items']] == [Decimal('30000.00')]
    creditors = client.get(API + '/finance/summary', headers=OPS).json()['creditors']
    assert [(c['party_name'], Decimal(c['balance'])) for c in creditors] == [('Juma transport', Decimal('25000.00'))]
    future = post(client, '/expenses', {'spent_on': '2999-01-01', 'category': 'fuel', 'description': 'x fuel', 'amount': '1'})
    assert future.status_code == 422
    # A wrongly entered expense is cancelled (once nothing is paid on it) and drops out.
    assert post(client, f"/ledger/debts/{owed['id']}/cancel", {'reason': 'Duplicate'}).status_code == 200
    assert Decimal(client.get(API + '/expenses', headers=OPS).json()['total']) == Decimal('30000.00')


def test_profit_is_sales_less_stock_cost_less_expenses(client, seeded, sessions):
    first = sale(client, items=[{'category': 'local_chicken', 'unit': 'bird', 'quantity': '20', 'unit_price': '15000',
        'supplier_name': 'Mzee Juma', 'unit_cost': '11000'}])
    expense(client, sale_id=first['id'])
    expense(client, category='transport', description='Truck', amount='20000', payment=None)
    cancelled = sale(client, new_buyer={'business_name': 'Mistake'})
    post(client, f"/sales/{cancelled['id']}/cancel", {'reason': 'Wrong'})
    body = client.get(API + '/finance/profit', headers=STAFF).json()
    assert Decimal(body['sales']) == Decimal('300000.00')
    assert Decimal(body['stock_cost']) == Decimal('220000.00')
    assert Decimal(body['gross_profit']) == Decimal('80000.00')
    assert Decimal(body['expenses']) == Decimal('50000.00')
    assert Decimal(body['net_profit']) == Decimal('30000.00')
    today = body['days'][0]
    assert today['date'] == TODAY and Decimal(today['net_profit']) == Decimal('30000.00')
    assert {r['category'] for r in body['expenses_by_category']} == {'labour', 'transport'}
    summary = client.get(API + '/finance/summary', headers=OPS).json()
    assert Decimal(summary['profit_today']['net_profit']) == Decimal('30000.00')
    for_sale = client.get(API + f"/expenses?sale_id={first['id']}", headers=OPS).json()
    assert Decimal(for_sale['total']) == Decimal('30000.00')
    assert client.get(API + '/finance/profit?start=2026-01-02&end=2026-01-01', headers=OPS).status_code == 422
