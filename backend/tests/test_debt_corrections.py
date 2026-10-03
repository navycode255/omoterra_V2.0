"""M1.4 (audit F06): correcting a supplier debt without erasing cost, and
M1.5 (audit F03 part 1): received stock is sold in its receipt's unit.

A sale's supplier debt is corrected for a stated reason, by an admin, and each
correction writes a financial_adjustments row with the state before and
after. Money already paid stays with whoever received it (rule R1).
"""
from decimal import Decimal

import pytest
from sqlalchemy import select

from app import models as m, transfers as tr
from test_finance import API, OPS, STAFF, TODAY, pay, post, sale
from test_purchasing import draft, issue, marked, receive  # noqa: F401  (fixture)
from test_transfers import balanced, cash, statement, transfer


def other_supplier(sessions, phone='+255712345690', name='Correct Farm'):
    with sessions.begin() as db:
        user = m.User(phone=phone, roles=['supplier'], name=name)
        db.add(user); db.flush()
        db.add(m.SupplierProfile(user_id=user.id, legal_name=name, internal_pickup_address='x'))
        return user.id


def payable(body, status=None):
    return next(d for d in body['debts'] if d['direction'] == 'payable' and (status is None or d['status'] == status))


def correct(client, debt_id, body, headers=OPS):
    return post(client, f'/ledger/debts/{debt_id}/corrections', body, headers)


def adjustments(sessions):
    with sessions() as db:
        return db.scalars(select(m.FinancialAdjustment).order_by(m.FinancialAdjustment.created_at)).all()


def invoice_100k(client, seeded):
    body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '13000',
        'supplier_id': seeded['supplier'], 'unit_cost': '10000'}])
    return body, payable(body)


def collection(client, seeded, quantity='20', unit_cost='7000'):
    batch = post(client, f"/suppliers/{seeded['supplier']}/batches", {
        'category': 'broilers', 'initial_quantity': '50', 'expected_ready_date': TODAY,
        'form': 'live', 'asking_price_per_unit': unit_cost, 'region': 'Pwani', 'photos': []}).json()
    note = post(client, f"/suppliers/{seeded['supplier']}/collections", {
        'batch_id': batch['id'], 'received_on': TODAY, 'delivered_quantity': quantity,
        'accepted_quantity': quantity, 'unit_cost': unit_cost})
    assert note.status_code == 201, note.text
    return note.json()


# ---- M1.4 -------------------------------------------------------------------

@pytest.mark.parametrize('payments', ['credit', 'unresolved'])
def test_wrong_supplier_moves_the_whole_obligation_and_payment_stays_with_receiver(client, seeded, sessions, payments):
    """TZS 100,000 invoice, 40,000 paid to the wrong supplier: the correct
    supplier is owed 100,000; the wrong one still holds 40,000 (credit or
    unresolved); cash out is still 40,000; cost of goods is unchanged."""
    body, wrong = invoice_100k(client, seeded)
    sent = transfer(client, seeded, 40000, [wrong['id']])
    correct_id = other_supplier(sessions)
    before = cash(client)
    assert before['money_out'] == Decimal('40000')

    request = {'kind': 'wrong_supplier', 'reason': 'Birds came from Correct Farm', 'supplier_id': correct_id}
    assert correct(client, wrong['id'], {**request, 'payments': payments}, STAFF).status_code == 403
    assert correct(client, wrong['id'], request).status_code == 422  # what is the 40,000 now?
    assert correct(client, wrong['id'], {**request, 'supplier_id': seeded['supplier'], 'payments': payments}).status_code == 422
    done = correct(client, wrong['id'], {**request, 'payments': payments})
    assert done.status_code == 200, done.text
    assert done.json()['status'] == 'cancelled' and Decimal(done.json()['paid_amount']) == 0

    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    assert Decimal(after['cost_amount']) == Decimal('100000')  # COGS kept
    assert after['items'][0]['supplier_id'] == correct_id and Decimal(after['items'][0]['unit_cost']) == Decimal('10000')
    owed = payable(after, 'open')
    assert owed['supplier_id'] == correct_id
    assert Decimal(owed['amount']) == Decimal('100000') and Decimal(owed['paid_amount']) == 0  # never "paid" by R1
    assert cash(client) == before
    rows = balanced(sessions)
    assert rows[sent['id']]['amount'] == Decimal('40000') and rows[sent['id']]['allocated'] == 0
    assert rows[sent['id']][payments] == Decimal('40000')
    original = statement(client, seeded)
    assert Decimal(original['transferred']) == Decimal('40000')
    assert Decimal(original[payments]) == Decimal('40000') and Decimal(original['owed']) == 0
    with sessions() as db:
        assert db.get(m.SupplierPayment, sent['id']).supplier_id == seeded['supplier']
        assert tr.by_supplier(db, [correct_id]) == {}

    [row] = adjustments(sessions)
    assert row.kind == 'wrong_supplier' and row.entity_id == wrong['id'] and row.related_debt_id == owed['id']
    assert row.recorded_by == seeded['operator_admin'] and row.reason == 'Birds came from Correct Farm'
    assert row.before['debt']['supplier_id'] == seeded['supplier'] and row.before['debt']['paid_amount'] == '40000.00'
    assert row.before['items'][0]['supplier_id'] == seeded['supplier'] and row.before['target'] is None
    assert row.after['debt']['status'] == 'cancelled' and row.after['items'][0]['supplier_id'] == correct_id
    assert row.after['target']['amount'] == '100000.00'
    assert row.linked_ids['transfer_ids'] == [sent['id']] and row.linked_ids['payments_as'] == payments
    detail = client.get(API + f"/ledger/debts/{owed['id']}", headers=OPS).json()
    assert [a['kind'] for a in detail['adjustments']] == ['wrong_supplier']


def test_wrong_supplier_already_on_the_sale_is_owed_one_debt(client, seeded, sessions):
    correct_id = other_supplier(sessions)
    body = sale(client, items=[
        {'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '12000', 'supplier_id': seeded['supplier'], 'unit_cost': '10000'},
        {'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '12000', 'supplier_id': correct_id, 'unit_cost': '10000'}])
    wrong = next(d for d in body['debts'] if d['supplier_id'] == seeded['supplier'])
    assert correct(client, wrong['id'], {'kind': 'wrong_supplier', 'reason': 'All five from Correct Farm',
        'supplier_id': correct_id}).status_code == 200
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    [owed] = [d for d in after['debts'] if d['direction'] == 'payable' and d['status'] != 'cancelled']
    assert owed['supplier_id'] == correct_id and Decimal(owed['amount']) == Decimal('50000')
    assert Decimal(after['cost_amount']) == Decimal('50000')
    # A later edit of the sale keeps one debt per supplier.
    edited = client.put(API + f"/sales/{body['id']}", headers=OPS, json={
        'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY, 'items': [
            {'category': 'broilers', 'unit': 'bird', 'quantity': '5', 'unit_price': '12000', 'supplier_id': correct_id, 'unit_cost': '10000'}]})
    assert edited.status_code == 200, edited.text
    assert [Decimal(d['amount']) for d in edited.json()['debts'] if d['direction'] == 'payable' and d['status'] != 'cancelled'] == [Decimal('50000')]


def test_wrong_supplier_by_name_for_an_unregistered_supplier(client, seeded, sessions):
    body, wrong = invoice_100k(client, seeded)
    done = correct(client, wrong['id'], {'kind': 'wrong_supplier', 'reason': 'Bought at Tegeta market',
        'supplier_name': 'Tegeta Sokoni'})
    assert done.status_code == 200, done.text
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    owed = payable(after, 'open')
    assert owed['party_kind'] == 'other' and owed['party_name'] == 'Tegeta Sokoni' and Decimal(owed['amount']) == Decimal('100000')
    assert after['items'][0]['supplier_id'] is None and after['items'][0]['supplier_name'] == 'Tegeta Sokoni'
    # Money paid to someone unregistered cannot be held as their credit.
    owed_pay = pay(client, owed['id'], '1000')
    assert owed_pay.status_code == 201
    back = correct(client, owed['id'], {'kind': 'wrong_supplier', 'reason': 'Was our supplier after all',
        'supplier_id': seeded['supplier'], 'payments': 'credit'})
    assert back.status_code == 409


def test_duplicate_liability_keeps_cost_and_payment_becomes_credit_for_the_real_debt(client, seeded, sessions):
    body, copy = invoice_100k(client, seeded)
    real = post(client, '/ledger/debts', {'direction': 'payable', 'party_kind': 'supplier', 'supplier_id': seeded['supplier'],
        'description': 'The same 10 birds, invoiced by hand', 'amount': '100000', 'incurred_on': TODAY}).json()
    assert pay(client, copy['id'], '30000', reference='CASH-1').status_code == 201
    other_debt = post(client, '/ledger/debts', {'direction': 'payable', 'party_kind': 'supplier',
        'supplier_id': other_supplier(sessions), 'description': 'Feed on credit', 'amount': '5000', 'incurred_on': TODAY}).json()
    base = {'kind': 'duplicate_liability', 'reason': 'Same birds as the hand invoice', 'payments': 'credit'}
    assert correct(client, copy['id'], {**base, 'duplicate_of': other_debt['id']}).status_code == 422
    assert correct(client, copy['id'], {**base, 'duplicate_of': copy['id']}).status_code == 422
    assert correct(client, copy['id'], {**base, 'kind': 'free_stock', 'duplicate_of': real['id']}).status_code == 422
    before = cash(client)
    done = correct(client, copy['id'], {**base, 'duplicate_of': real['id']})
    assert done.status_code == 200, done.text
    assert done.json()['adjustments'][0]['related_debt_id'] == real['id']
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    assert Decimal(after['cost_amount']) == Decimal('100000')
    assert after['items'][0]['supplier_id'] == seeded['supplier']
    assert cash(client) == before
    assert Decimal(statement(client, seeded)['credit']) == Decimal('30000')
    # The credit then pays the real debt; no money moves.
    applied = post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '30000', 'debt_ids': [real['id']]})
    assert applied.status_code == 201, applied.text
    assert cash(client) == before
    # Editing the sale does not open the duplicate again.
    edited = client.put(API + f"/sales/{body['id']}", headers=OPS, json={
        'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY, 'notes': 'edited', 'items': [
            {'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '13000', 'supplier_id': seeded['supplier'], 'unit_cost': '10000'}]})
    assert edited.status_code == 200, edited.text
    assert [d['status'] for d in edited.json()['debts'] if d['direction'] == 'payable'] == ['cancelled']
    [row] = adjustments(sessions)
    assert row.kind == 'duplicate_liability' and row.linked_ids['duplicate_of'] == real['id']
    balanced(sessions)


def test_free_stock_needs_an_admin_and_is_a_known_zero(client, seeded, sessions):
    body, debt = invoice_100k(client, seeded)
    request = {'kind': 'free_stock', 'reason': 'Supplier gave these birds free'}
    assert correct(client, debt['id'], request, STAFF).status_code == 403
    assert correct(client, debt['id'], {**request, 'reason': ' '}).status_code == 422
    done = correct(client, debt['id'], request)
    assert done.status_code == 200, done.text
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    assert Decimal(after['items'][0]['unit_cost']) == 0 and Decimal(after['items'][0]['cost_total']) == 0
    assert after['items'][0]['supplier_id'] == seeded['supplier']
    assert Decimal(after['cost_amount']) == 0 and Decimal(after['margin']) == Decimal('130000')
    [row] = adjustments(sessions)
    assert row.kind == 'free_stock' and row.before['items'][0]['unit_cost'] == '10000.00'
    assert row.after['items'][0]['unit_cost'] == '0.00' and row.linked_ids['item_ids'] == [after['items'][0]['id']]
    # An edit keeps the free line and owes no one for it ...
    line = {'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '13000', 'supplier_id': seeded['supplier'], 'unit_cost': '0'}
    edited = client.put(API + f"/sales/{body['id']}", headers=OPS, json={
        'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY, 'items': [line]})
    assert edited.status_code == 200, edited.text
    assert [d['status'] for d in edited.json()['debts'] if d['direction'] == 'payable'] == ['cancelled']
    # ... but a cost of 0 is never typed into a sale.
    refused = post(client, '/sales', {'new_buyer': {'business_name': 'Free birds?'}, 'sold_on': TODAY, 'items': [line]})
    assert refused.status_code == 422


def test_free_stock_and_no_cost_refuse_a_paid_debt(client, seeded):
    _body, debt = invoice_100k(client, seeded)
    assert pay(client, debt['id'], '1000').status_code == 201
    for kind in ('free_stock', 'cost_never_existed'):
        assert correct(client, debt['id'], {'kind': kind, 'reason': 'No cost'}).status_code == 409


def test_receipt_lines_are_never_touched(client, seeded, sessions):
    """A sale mixing delivery-note stock and stock bought for the sale from
    the same supplier: correcting the sale's debt changes only the direct
    line, and the receipt's own debt is corrected on the receipt."""
    note = collection(client, seeded)
    body = sale(client, items=[
        {'quantity': '5', 'unit_price': '9000', 'supplier_collection_id': note['id']},
        {'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '9000', 'supplier_id': seeded['supplier'], 'unit_cost': '6000'}])
    assert Decimal(body['cost_amount']) == Decimal('47000')
    debt = payable(body)
    assert Decimal(debt['amount']) == Decimal('12000')
    done = correct(client, debt['id'], {'kind': 'cost_never_existed', 'reason': 'The two were our own birds'})
    assert done.status_code == 200, done.text
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    received, direct = after['items']
    assert received['supplier_collection_id'] == note['id'] and received['supplier_id'] == seeded['supplier']
    assert Decimal(received['unit_cost']) == Decimal('7000') and Decimal(received['cost_total']) == Decimal('35000')
    assert direct['unit_cost'] is None and direct['supplier_id'] is None
    assert Decimal(after['cost_amount']) == Decimal('35000')
    receipt_debt = note['debt_id']
    assert correct(client, receipt_debt, {'kind': 'free_stock', 'reason': 'Free'}).status_code == 409
    assert post(client, f'/ledger/debts/{receipt_debt}/cancel', {'reason': 'Free'}).status_code == 409
    with sessions() as db:
        assert db.get(m.LedgerDebt, receipt_debt).status == 'open'


def test_cost_never_existed_is_unknown_not_zero(client, seeded, sessions):
    from app import finance_exceptions as fx
    body, debt = invoice_100k(client, seeded)
    assert correct(client, debt['id'], {'kind': 'cost_never_existed', 'reason': 'Bought by the buyer himself'}).status_code == 200
    after = client.get(API + f"/sales/{body['id']}", headers=OPS).json()
    assert after['items'][0]['unit_cost'] is None and after['items'][0]['cost_total'] is None
    [row] = adjustments(sessions)
    assert row.before['items'][0]['supplier_id'] == seeded['supplier'] and row.after['items'][0]['unit_cost'] is None
    with sessions() as db:
        # Listed as unknown cost (R5); not as an unexplained cancelled debt.
        assert [r['sale_item_id'] for r in fx.unknown_cost_lines(db)['records']] == [after['items'][0]['id']]
        assert fx.cancelled_sale_cost_debts(db)['records'] == []


# ---- M1.5 -------------------------------------------------------------------

def test_delivery_note_lines_take_the_receipt_unit_and_category(client, seeded):
    note = collection(client, seeded)
    body = sale(client, items=[{'quantity': '4', 'unit_price': '9000', 'supplier_collection_id': note['id']}])
    assert body['items'][0]['unit'] == 'bird' and body['items'][0]['category'] == 'broilers'
    same = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '9000',
        'supplier_collection_id': note['id']}])
    assert same['items'][0]['unit'] == 'bird'
    base = {'new_buyer': {'business_name': 'Kg buyer'}, 'sold_on': TODAY}
    kg = post(client, '/sales', {**base, 'items': [{'unit': 'kg', 'quantity': '3', 'unit_price': '9000',
        'supplier_collection_id': note['id']}]})
    assert kg.status_code == 422 and 'received by bird' in kg.json()['detail']
    goats = post(client, '/sales', {**base, 'items': [{'category': 'goats', 'quantity': '1', 'unit_price': '9000',
        'supplier_collection_id': note['id']}]})
    assert goats.status_code == 422 and 'broilers' in goats.json()['detail']
    half = post(client, '/sales', {**base, 'items': [{'quantity': '2.5', 'unit_price': '9000',
        'supplier_collection_id': note['id']}]})
    assert half.status_code == 422
    # The same rule on an edit.
    edited = client.put(API + f"/sales/{body['id']}", headers=OPS, json={
        'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'unit': 'kg', 'quantity': '4', 'unit_price': '9000', 'supplier_collection_id': note['id']}]})
    assert edited.status_code == 422
    kept = client.put(API + f"/sales/{body['id']}", headers=OPS, json={
        'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'quantity': '3', 'unit_price': '9000', 'supplier_collection_id': note['id']}]})
    assert kept.status_code == 200, kept.text
    assert kept.json()['items'][0]['unit'] == 'bird'


def test_lpo_lines_take_the_receipt_unit(client, seeded, marked):  # noqa: F811
    lpo = issue(client, draft(client, seeded))
    lpo = receive(client, lpo, '20', '20').json()
    line = lpo['lines'][0]['id']
    body = sale(client, items=[{'quantity': '3', 'unit_price': '9000', 'lpo_line_id': line}])
    assert body['items'][0]['unit'] == 'bird' and body['items'][0]['category'] == 'broilers'
    kg = post(client, '/sales', {'new_buyer': {'business_name': 'Kg buyer'}, 'sold_on': TODAY,
        'items': [{'unit': 'kg', 'quantity': '3', 'unit_price': '9000', 'lpo_line_id': line}]})
    assert kg.status_code == 422
    half = post(client, '/sales', {'new_buyer': {'business_name': 'Half'}, 'sold_on': TODAY,
        'items': [{'unit': 'bird', 'quantity': '2.5', 'unit_price': '9000', 'lpo_line_id': line}]})
    assert half.status_code == 422


def test_lines_not_from_a_receipt_still_need_a_unit(client):
    missing = post(client, '/sales', {'new_buyer': {'business_name': 'No unit'}, 'sold_on': TODAY,
        'items': [{'category': 'beef', 'quantity': '2.5', 'unit_price': '12000'}]})
    assert missing.status_code == 422
    beef = sale(client, items=[{'category': 'beef', 'unit': 'kg', 'quantity': '2.5', 'unit_price': '12000'}])
    assert Decimal(beef['items'][0]['quantity']) == Decimal('2.5')
    birds = post(client, '/sales', {'new_buyer': {'business_name': 'Half bird'}, 'sold_on': TODAY,
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '2.5', 'unit_price': '12000'}]})
    assert birds.status_code == 422


def test_migration_034_allows_a_free_cost_and_needs_a_reason():
    """On a migrated database (not one built from the models) the old
    `unit_cost > 0` check becomes `>= 0`, and an adjustment needs a reason."""
    import os
    import uuid
    from sqlalchemy import create_engine, text
    from sqlalchemy.exc import IntegrityError
    from app import migrations
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m034_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    try:
        assert '034_financial_adjustments.sql' in migrations.apply(engine)
        with engine.connect() as db:
            checks = db.execute(text("""SELECT pg_get_constraintdef(oid) FROM pg_constraint
                WHERE conrelid = 'sale_items'::regclass AND conname = 'sale_items_unit_cost_check'""")).scalars().all()
            assert checks == ['CHECK ((unit_cost >= (0)::numeric))']
            assert db.execute(text("SELECT to_regclass('financial_adjustments') IS NOT NULL")).scalar()
        with pytest.raises(IntegrityError), engine.begin() as db:
            db.execute(text("""INSERT INTO financial_adjustments (id, kind, entity_type, entity_id, reason, before, after,
                linked_ids) VALUES ('a1', 'free_stock', 'ledger_debt', 'd1', '  ', '{}', '{}', '{}')"""))
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()
