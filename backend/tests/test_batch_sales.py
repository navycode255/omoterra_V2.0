"""Batch sales become delivery notes (build plan M1.6, audit F09, rule R2).

A sale line from a supplier batch needs staff to confirm the goods were
physically collected. The server then records a same-day delivery note whose
payable is the supplier's only liability, and the line sells from it.
Cancelling or reducing the sale never touches the note or its payable; the
goods come back on hand only when staff say so. Correcting the receipt and
returning goods to the supplier are separate, physical events."""
from decimal import Decimal

from sqlalchemy import select

from app import models as m, transfers as tr
from test_finance import API, OPS, TODAY, post, sale


def batch(sessions, seeded, quantity=300):
    with sessions.begin() as db:
        row = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', initial_quantity=quantity,
            current_quantity=quantity, status='ready', approved_at=m.now())
        db.add(row); db.flush()
        return row.id


def state(sessions, id):
    with sessions() as db:
        row = db.get(m.SupplierBatch, id)
        return row.sold_quantity, row.externally_sold_quantity, row.available_to_commit, row.status


def line(seeded, batch_id, quantity, confirmed=True, **extra):
    return {'category': 'broilers', 'unit': 'bird', 'quantity': str(quantity), 'unit_price': '7000',
            'supplier_id': seeded['supplier'], 'unit_cost': '6500', 'supplier_batch_id': batch_id,
            'receipt_confirmed': confirmed, **extra}


def note_of(body):
    return body['items'][0]['supplier_collection_id']


def note(client, id):
    response = client.get(API + f'/supplier-collections/{id}', headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def receipt_debt(sessions, note_id):
    with sessions() as db:
        return db.get(m.LedgerDebt, db.get(m.SupplierCollection, note_id).debt_id)


def supplier_debts(sessions, seeded):
    with sessions() as db:
        return db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.supplier_id == seeded['supplier'],
            m.LedgerDebt.status != 'cancelled')).all()


def cancel(client, sale_id, goods=None, **extra):
    body = {'reason': 'Buyer changed their mind', **({'goods': goods} if goods else {}), **extra}
    return post(client, f'/sales/{sale_id}/cancel', body)


def credit_of(sessions, seeded):
    with sessions() as db:
        return tr.by_supplier(db, [seeded['supplier']]).get(seeded['supplier'], {})


def test_selling_20_from_300_records_one_receipt_and_one_payable(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    item = body['items'][0]
    assert item['supplier_collection_id'] and item['supplier_batch_id'] is None
    # The sale opens no supplier debt of its own: the receipt's is the only one.
    assert [d['direction'] for d in body['debts']] == ['receivable']
    assert Decimal(body['cost_amount']) == Decimal('130000')
    with sessions() as db:
        notes = db.scalars(select(m.SupplierCollection)).all()
        assert len(notes) == 1
        row = notes[0]
        assert (row.origin, row.delivered_quantity, row.accepted_quantity, row.unit_cost, row.received_on.isoformat(),
                row.sale_id, row.confirmed_by, row.recorded_by) == (
            'sale', Decimal('20'), Decimal('20'), Decimal('6500'), TODAY, body['id'], seeded['operator_admin'],
            seeded['operator_admin'])
    debts = supplier_debts(sessions, seeded)
    assert [(d.source, d.amount, d.sale_id) for d in debts] == [('batch_receipt', Decimal('130000'), None)]
    assert state(sessions, id)[2] == Decimal('280')
    view = note(client, row.id)
    assert (Decimal(view['sold']), Decimal(view['on_hand'])) == (Decimal('20'), Decimal('0'))
    assert view['sale_number'] == body['sale_number'] and view['confirmed_by'] == 'Test Admin'
    statement = client.get(API + f"/ledger/suppliers/{seeded['supplier']}/statement", headers=OPS).json()
    assert (Decimal(statement['bought']), Decimal(statement['owed'])) == (Decimal('130000'), Decimal('130000'))


def test_a_batch_line_without_receipt_confirmation_is_refused(client, sessions, seeded):
    id = batch(sessions, seeded)
    refused = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111'},
        'sold_on': TODAY, 'items': [line(seeded, id, 20, confirmed=False)]})
    assert refused.status_code == 422 and 'physically collected' in refused.text
    assert state(sessions, id)[0] == 0
    with sessions() as db:
        assert db.scalars(select(m.SupplierCollection)).all() == [] and db.scalars(select(m.Sale)).all() == []


def test_a_batch_line_must_match_the_batch_product(client, sessions, seeded):
    id = batch(sessions, seeded)
    wrong = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111'},
        'sold_on': TODAY, 'items': [line(seeded, id, 2, category='local_chicken')]})
    assert wrong.status_code == 422


def test_cancel_goods_never_left_keeps_receipt_and_payable_and_20_on_hand(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    assert cancel(client, body['id']).status_code == 422  # the goods question is required
    cancelled = cancel(client, body['id'], 'never_left')
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()['cancel_goods'] == 'never_left'
    view = note(client, note_of(body))
    assert view['cancelled_at'] is None and Decimal(view['on_hand']) == Decimal('20')
    assert [mv['kind'] for mv in view['movements']] == ['never_left']
    debt = receipt_debt(sessions, note_of(body))
    assert (debt.status, debt.amount) == ('open', Decimal('130000'))
    assert state(sessions, id)[2] == Decimal('280')  # the birds are Omoterra's stock, not the batch's
    # They can be sold again from the note.
    again = sale(client, items=[{'quantity': '20', 'unit_price': '7200', 'supplier_collection_id': note_of(body)}])
    assert Decimal(again['cost_amount']) == Decimal('130000')


def test_buyer_return_accepted_needs_the_goods_condition(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    assert cancel(client, body['id'], 'buyer_return_accepted').status_code == 422
    done = cancel(client, body['id'], 'buyer_return_accepted', goods_note='All alive, checked by Juma')
    assert done.status_code == 200, done.text
    assert Decimal(note(client, note_of(body))['on_hand']) == Decimal('20')


def test_cancel_not_recovered_leaves_nothing_on_hand_and_records_a_loss(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    assert cancel(client, body['id'], 'not_recovered').status_code == 200
    view = note(client, note_of(body))
    assert (Decimal(view['on_hand']), Decimal(view['not_recovered'])) == (Decimal('0'), Decimal('20'))
    debt = receipt_debt(sessions, note_of(body))
    assert (debt.status, debt.amount) == ('open', Decimal('130000'))
    profit = client.get(API + '/finance/profit', headers=OPS).json()
    assert Decimal(profit['stock_lost']) == Decimal('130000') and Decimal(profit['sales']) == 0


def test_reducing_the_quantity_asks_what_happened_to_the_difference(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    edited = {'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'quantity': '15', 'unit_price': '7000', 'supplier_collection_id': note_of(body)}]}
    assert client.put(API + f"/sales/{body['id']}", headers=OPS, json=edited).status_code == 422
    done = client.put(API + f"/sales/{body['id']}", headers=OPS, json={**edited, 'goods': 'not_recovered'})
    assert done.status_code == 200, done.text
    view = note(client, note_of(body))
    assert (Decimal(view['sold']), Decimal(view['not_recovered']), Decimal(view['on_hand'])) == (15, 5, 0)
    assert receipt_debt(sessions, note_of(body)).amount == Decimal('130000')
    # Selling more again cannot take the lost birds.
    more = client.put(API + f"/sales/{body['id']}", headers=OPS, json={**edited,
        'items': [{'quantity': '16', 'unit_price': '7000', 'supplier_collection_id': note_of(body)}]})
    assert more.status_code == 422


def test_correct_receipt_to_zero_cancels_the_payable_and_restores_the_batch(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    correction = {'quantity': '20', 'reason': 'Supplier never brought them', 'evidence': 'Gate log 4 Oct, no truck'}
    # Sold goods cannot be corrected away while the sale stands (R8).
    blocked = post(client, f'/supplier-collections/{note_of(body)}/corrections', correction)
    assert blocked.status_code == 422 and 'Only 0' in blocked.text
    assert cancel(client, body['id'], 'never_left').status_code == 200
    staff = {'X-Ops-Token': OPS['X-Ops-Token'], 'X-Operator-Session': 'ops-staff'}
    assert post(client, f'/supplier-collections/{note_of(body)}/corrections', correction, headers=staff).status_code == 403
    done = post(client, f'/supplier-collections/{note_of(body)}/corrections', correction)
    assert done.status_code == 200, done.text
    assert done.json()['cancelled_at'] is not None and Decimal(done.json()['on_hand']) == 0
    assert receipt_debt(sessions, note_of(body)).status == 'cancelled'
    assert state(sessions, id)[2] == Decimal('300')
    with sessions() as db:
        adjustment = db.scalar(select(m.FinancialAdjustment))
        assert adjustment.kind == 'receipt_correction' and adjustment.entity_id == note_of(body)
        assert adjustment.before['debt']['status'] == 'open' and adjustment.after['debt']['status'] == 'cancelled'


def test_correcting_a_paid_receipt_keeps_the_money_with_the_supplier(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20, cost_payment={'paid_on': TODAY, 'method': 'cash'})])
    assert cancel(client, body['id'], 'never_left').status_code == 200
    path = f'/supplier-collections/{note_of(body)}/corrections'
    partial = {'quantity': '5', 'reason': 'Five were never delivered', 'evidence': 'Supplier confirmed by phone'}
    assert post(client, path, partial).status_code == 422  # say what the paid money is
    done = post(client, path, {**partial, 'payments': 'credit'})
    assert done.status_code == 200, done.text
    debt = receipt_debt(sessions, note_of(body))
    # 15 x 6,500 still owed and still paid; the 32,500 paid for the 5 is their credit.
    assert (debt.amount, debt.paid_amount, debt.status) == (Decimal('97500'), Decimal('97500'), 'settled')
    held = credit_of(sessions, seeded)
    assert (held['transferred'], held['credit'], held['allocated']) == (Decimal('130000'), Decimal('32500'), Decimal('97500'))
    with sessions() as db:
        assert all(tr.balanced(row) for row in tr.buckets(db).values())
    assert state(sessions, id)[2] == Decimal('285')


def test_return_to_supplier_awaits_a_credit_note_before_the_payable_falls(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20)])
    assert cancel(client, body['id'], 'never_left').status_code == 200
    path = f'/supplier-collections/{note_of(body)}/returns'
    assert post(client, path, {'quantity': '21', 'returned_on': TODAY, 'reason': 'Underweight'}).status_code == 422
    returned = post(client, path, {'quantity': '20', 'returned_on': TODAY, 'reason': 'Underweight'})
    assert returned.status_code == 201, returned.text
    view = returned.json()
    assert (Decimal(view['on_hand']), Decimal(view['returned'])) == (0, 20)
    assert Decimal(view['awaiting_credit_quantity']) == 20 and Decimal(view['awaiting_credit_value']) == Decimal('130000')
    assert receipt_debt(sessions, note_of(body)).amount == Decimal('130000')  # unchanged until credit
    assert state(sessions, id)[2] == Decimal('280')
    movement = next(mv for mv in view['movements'] if mv['kind'] == 'returned_to_supplier')
    credit_path = f"/supplier-collections/{note_of(body)}/returns/{movement['id']}/credit-note"
    assert post(client, credit_path, {'amount': '130001', 'issued_on': TODAY, 'reference': 'CN-1'}).status_code == 422
    credited = post(client, credit_path, {'amount': '120000', 'issued_on': TODAY, 'reference': 'CN-1'})
    assert credited.status_code == 201, credited.text
    assert Decimal(credited.json()['awaiting_credit_quantity']) == 0
    debt = receipt_debt(sessions, note_of(body))
    assert (debt.amount, debt.status) == (Decimal('10000'), 'open')
    assert post(client, credit_path, {'amount': '1000', 'issued_on': TODAY, 'reference': 'CN-2'}).status_code == 409
    with sessions() as db:
        assert db.scalar(select(m.FinancialAdjustment.kind)) == 'supplier_credit_note'


def test_cost_paid_at_sale_is_a_transfer_allocated_to_the_receipt_debt(client, sessions, seeded):
    id = batch(sessions, seeded)
    body = sale(client, items=[line(seeded, id, 20, cost_payment={'paid_on': TODAY, 'method': 'mpesa', 'reference': 'QX9'})])
    debt = receipt_debt(sessions, note_of(body))
    assert (debt.source, debt.paid_amount, debt.status) == ('batch_receipt', Decimal('130000'), 'settled')
    with sessions() as db:
        payment = db.scalar(select(m.LedgerPayment).where(m.LedgerPayment.debt_id == debt.id))
        transfer = db.get(m.SupplierPayment, payment.supplier_payment_id)
        assert (transfer.amount, transfer.origin, transfer.supplier_id) == (Decimal('130000'), 'single', seeded['supplier'])
        assert tr.balanced(tr.buckets(db, [transfer.id])[transfer.id])
    cash = client.get(API + '/ledger/payments?status=out', headers=OPS).json()
    assert [(row['kind'], Decimal(row['amount'])) for row in cash['items']] == [('transfer', Decimal('130000'))]


def test_legacy_batch_lines_keep_their_form_until_linked(client, sessions, seeded):
    """Sold straight from a batch before M1.6: an edit keeps the line (no new
    receipt) and cancelling gives the birds back to the batch."""
    id = batch(sessions, seeded)
    body = sale(client, items=[{**line(seeded, '', 20)}])
    with sessions.begin() as db:
        db.get(m.SaleItem, body['items'][0]['id']).supplier_batch_id = id
        db.get(m.SupplierBatch, id).sold_quantity = 20
    edited = client.put(API + f"/sales/{body['id']}", headers=OPS, json={'buyer_profile_id': body['buyer_profile_id'],
        'sold_on': TODAY, 'items': [line(seeded, id, 25, confirmed=False)]})
    assert edited.status_code == 200, edited.text
    assert edited.json()['items'][0]['supplier_batch_id'] == id and state(sessions, id)[0] == Decimal('25')
    with sessions() as db:
        assert db.scalars(select(m.SupplierCollection)).all() == []
    assert cancel(client, body['id']).status_code == 200
    assert state(sessions, id)[0] == 0


def test_cannot_sell_more_than_is_left_or_from_another_suppliers_batch(client, sessions, seeded):
    id = batch(sessions, seeded, 30)
    too_many = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111', 'region': 'dar'},
        'sold_on': TODAY, 'items': [line(seeded, id, 31)]})
    assert too_many.status_code == 422 and '30' in too_many.text
    with sessions.begin() as db:
        db.get(m.SupplierBatch, id).supplier_id = seeded['other']
    wrong = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111', 'region': 'dar'},
        'sold_on': TODAY, 'items': [line(seeded, id, 1)]})
    assert wrong.status_code == 422


def test_staff_record_sold_elsewhere_and_close_the_batch(client, sessions, seeded):
    id = batch(sessions, seeded, 700)
    sale(client, items=[line(seeded, id, 100)])
    elsewhere = post(client, f'/batches/{id}/sold-elsewhere', {'quantity': '450', 'notes': 'Sold at the farm'})
    assert elsewhere.status_code == 200, elsewhere.text
    body = elsewhere.json()
    assert Decimal(body['remaining']) == Decimal('150') and Decimal(body['sold_elsewhere']) == Decimal('450')
    assert Decimal(body['received_on_notes']) == Decimal('100') and Decimal(body['sold_direct']) == 0
    assert body['elsewhere_history'][0]['by_staff'] is True
    closed = post(client, f'/batches/{id}/close', {'notes': ''})
    assert closed.status_code == 200, closed.text
    assert state(sessions, id) == (Decimal('100'), Decimal('600'), Decimal('0'), 'sold')
    assert post(client, f'/batches/{id}/close', {'notes': ''}).status_code == 409
    listed = client.get(API + '/supplier-batches/open', headers=OPS).json()
    assert id not in [row['id'] for row in listed]


def test_not_from_a_batch_is_saved_without_one(client, sessions, seeded):
    body = sale(client, items=[{**line(seeded, '', 5)}])
    assert body['items'][0]['supplier_batch_id'] is None and body['items'][0]['supplier_collection_id'] is None


def test_supplier_list_shows_batches_birds_and_money(client, sessions, seeded):
    id = batch(sessions, seeded, 300)
    sold = sale(client, items=[line(seeded, id, 60)])
    debt = receipt_debt(sessions, note_of(sold))
    assert post(client, f'/ledger/debts/{debt.id}/payments', {'amount': '100000', 'paid_on': TODAY, 'method': 'cash'}).status_code == 201
    row = next(r for r in client.get(API + '/suppliers', headers=OPS).json()['items'] if r['id'] == seeded['supplier'])
    assert row['batches_total'] == 1 and row['batches_open'] == 1 and Decimal(row['birds_left']) == Decimal('240')
    assert Decimal(row['birds_bought']) == Decimal('60')
    assert Decimal(row['paid_total']) == Decimal('100000') and Decimal(row['owed_total']) == Decimal('290000')
    assert row['last_activity'] == TODAY
