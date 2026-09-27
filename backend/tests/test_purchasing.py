"""LPOs: drafting, issuing with stamp and signature, batches received,
payables, LPO stock in sales, losses and the demand board."""
from datetime import timedelta
from decimal import Decimal
from io import BytesIO

import pytest
from PIL import Image

from app import contracts as c, models as m, notifications as notes
from test_finance import API, OPS, STAFF, TODAY, key, post, receivable

TODAY_D = c.business_today()


def png():
    buffer = BytesIO()
    Image.new('RGB', (40, 20), (20, 40, 160)).save(buffer, 'PNG')
    return buffer.getvalue()


def upload(client, kind, headers=OPS):
    return client.post(API + f'/marks/{kind}', headers=headers, files={'file': ('mark.png', png(), 'image/png')})


def draft(client, seeded, headers=STAFF, **overrides):
    body = {'supplier_id': seeded['supplier'], 'lpo_date': TODAY, 'delivery_start': TODAY,
            'delivery_end': (TODAY_D + timedelta(days=3)).isoformat(), 'payment_terms_days': 2,
            'lines': [{'category': 'broilers', 'item': 'Broiler chickens', 'unit': 'bird', 'unit_price': '6500',
                       'specification': 'Live, 0.95 to 1.2 kg', 'min_weight_kg': '0.95', 'max_weight_kg': '1.2'}]}
    body.update(overrides)
    response = post(client, '/lpos', body, headers)
    assert response.status_code == 201, response.text
    return response.json()


@pytest.fixture
def marked(client):
    assert upload(client, 'stamp').status_code == 201
    assert upload(client, 'signature').status_code == 201


def issue(client, lpo, **body):
    response = post(client, f"/lpos/{lpo['id']}/issue", body)
    assert response.status_code == 200, response.text
    return response.json()


def receive(client, lpo, delivered, accepted, day=TODAY, headers=STAFF):
    line = lpo['lines'][0]['id']
    return post(client, f"/lpos/{lpo['id']}/receipts", {'received_on': day, 'lines': [
        {'lpo_line_id': line, 'delivered_quantity': delivered, 'accepted_quantity': accepted, 'average_weight_kg': '1.1'}]}, headers)


def test_only_admins_upload_marks_and_marks_are_not_served_as_plain_media(client, sessions):
    assert upload(client, 'stamp', STAFF).status_code == 403
    assert upload(client, 'stamp').status_code == 201
    with sessions() as db:
        media_id = db.query(m.DocumentMark).one().media_id
    assert client.get(API + f'/media/{media_id}', headers=STAFF).status_code == 404
    assert client.get(API + f'/media/{media_id}', headers=OPS).status_code == 404
    # A second upload replaces the first; the old one is kept for issued LPOs.
    assert upload(client, 'stamp').status_code == 201
    with sessions() as db:
        assert db.query(m.DocumentMark).filter(m.DocumentMark.retired_at.is_(None)).count() == 1


def test_staff_draft_admin_issue_numbers_and_notifies(client, seeded, sessions, marked):
    lpo = draft(client, seeded)
    assert lpo['status'] == 'draft' and lpo['lpo_number'].startswith('DRAFT-')
    assert lpo['supplier_snapshot']['name'] == 'Secret legal name'
    assert len(lpo['terms']) == 8 and 'shall be deemed void' in lpo['terms'][6]
    assert lpo['delivery_notes'][0].startswith('Supply to be made in batches during ')
    assert post(client, f"/lpos/{lpo['id']}/issue", {}, STAFF).status_code == 403
    issued = issue(client, lpo)
    assert issued['status'] == 'issued' and issued['lpo_number'] == f'LPO-OMO-{TODAY_D.year}-0001'
    assert issued['issuer_name'] == 'Test Admin' and issued['stamped'] is True
    # Frozen once issued.
    assert client.put(API + f"/lpos/{lpo['id']}", headers=OPS, json={**{k: lpo[k] for k in ('supplier_id', 'lpo_date',
        'delivery_start', 'delivery_end')}, 'lines': [{'item': 'x item', 'unit': 'bird', 'unit_price': '1'}]}).status_code == 409
    # The next one follows, and a paper LPO keeps its own number.
    carried = issue(client, draft(client, seeded), lpo_number=f'LPO-OMO-{TODAY_D.year}-0927')
    assert carried['lpo_number'].endswith('-0927')
    assert issue(client, draft(client, seeded))['lpo_number'].endswith('-0928')
    assert post(client, f"/lpos/{draft(client, seeded)['id']}/issue", {'lpo_number': carried['lpo_number']}).status_code == 409
    assert client.get(API + f"/lpos/{lpo['id']}/marks/stamp", headers=STAFF).status_code == 200
    with sessions() as db:
        assert db.query(m.Notification).filter_by(user_id=seeded['supplier'], kind='lpo_issued').count() == 3


def test_issuing_needs_the_stamp_and_the_admins_own_signature(client, seeded):
    lpo = draft(client, seeded)
    assert upload(client, 'stamp').status_code == 201
    no_signature = post(client, f"/lpos/{lpo['id']}/issue", {})
    assert no_signature.status_code == 422 and 'signature' in no_signature.json()['detail']
    assert client.get(API + f"/lpos/{lpo['id']}/marks/stamp", headers=OPS).status_code == 404


def test_batches_received_become_payables_due_by_terms(client, seeded, marked):
    lpo = issue(client, draft(client, seeded))
    outside = receive(client, lpo, '10', '10', day=(TODAY_D - timedelta(days=1)).isoformat())
    assert outside.status_code == 422
    assert receive(client, lpo, '10', '11').status_code == 422
    body = receive(client, lpo, '120', '115')
    assert body.status_code == 201, body.text
    lpo = body.json()
    receipt = lpo['receipts'][0]
    assert Decimal(receipt['amount']) == Decimal('747500.00')
    assert receipt['lines'][0]['rejected_quantity'] == '5.000'
    debt = receipt['debt']
    assert debt['source'] == 'lpo' and debt['supplier_id'] == seeded['supplier']
    assert debt['due_on'] == (TODAY_D + timedelta(days=2)).isoformat()
    assert Decimal(lpo['owed_value']) == Decimal('747500.00')
    assert lpo['lines'][0]['stock']['on_hand'] == '115.000'
    # The ledger owns payment; a paid receipt cannot be cancelled.
    assert post(client, f"/ledger/debts/{debt['id']}/payments", {'amount': '100000', 'paid_on': TODAY, 'method': 'mpesa'}).status_code == 201
    assert post(client, f"/ledger/debts/{debt['id']}/cancel", {'reason': 'x wrong'}).status_code == 409
    assert post(client, f"/lpos/receipts/{receipt['id']}/cancel", {'reason': 'Wrong count'}).status_code == 409


def test_fixed_quantity_cannot_be_over_accepted(client, seeded, marked):
    lpo = issue(client, draft(client, seeded, supply_basis='fixed', lines=[
        {'category': 'broilers', 'item': 'Broilers', 'unit': 'bird', 'unit_price': '6500', 'quantity': '100'}]))
    assert receive(client, lpo, '80', '80').status_code == 201
    over = receive(client, lpo, '30', '30')
    assert over.status_code == 422 and 'Still to deliver: 20' in over.json()['detail']
    missing = post(client, '/lpos', {'supplier_id': seeded['supplier'], 'lpo_date': TODAY, 'delivery_start': TODAY,
        'delivery_end': TODAY, 'supply_basis': 'fixed', 'lines': [{'item': 'Broilers', 'unit': 'bird', 'unit_price': '1'}]})
    assert missing.status_code == 422


def test_lpo_stock_sold_and_lost_counts_once_in_profit(client, seeded, marked):
    lpo = issue(client, draft(client, seeded))
    lpo = receive(client, lpo, '100', '100').json()
    line = lpo['lines'][0]['id']
    base = {'new_buyer': {'business_name': 'Mama Asha'}, 'sold_on': TODAY}
    both = post(client, '/sales', {**base, 'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '1',
        'unit_price': '9000', 'lpo_line_id': line, 'unit_cost': '1', 'supplier_id': seeded['supplier']}]})
    assert both.status_code == 422
    too_many = post(client, '/sales', {**base, 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '60', 'unit_price': '9000', 'lpo_line_id': line},
        {'category': 'broilers', 'unit': 'bird', 'quantity': '41', 'unit_price': '9000', 'lpo_line_id': line}]})
    assert too_many.status_code == 422 and 'Available: 40' in too_many.json()['detail']
    sold = post(client, '/sales', {**base, 'items': [
        {'category': 'broilers', 'unit': 'bird', 'quantity': '90', 'unit_price': '9000', 'lpo_line_id': line}]})
    assert sold.status_code == 201, sold.text
    sale = sold.json()
    # Cost from the LPO; no second payable to the supplier.
    assert Decimal(sale['cost_amount']) == Decimal('585000.00')
    assert [d['direction'] for d in sale['debts']] == ['receivable']
    lost = post(client, '/lpos/losses', {'lpo_line_id': line, 'lost_on': TODAY, 'quantity': '4', 'reason': 'died'})
    assert lost.status_code == 201
    assert post(client, '/lpos/losses', {'lpo_line_id': line, 'lost_on': TODAY, 'quantity': '7', 'reason': 'died'}).status_code == 422
    stock = lost.json()['lines'][0]['stock']
    assert (stock['sold'], stock['lost'], stock['on_hand']) == ('90.000', '4.000', '6.000')
    assert [row['on_hand'] for row in client.get(API + '/lpos/stock', headers=STAFF).json()] == ['6.000']
    profit = client.get(API + '/finance/profit', headers=OPS).json()
    assert Decimal(profit['sales']) == Decimal('810000.00')
    assert Decimal(profit['stock_cost']) == Decimal('585000.00')
    assert Decimal(profit['stock_lost']) == Decimal('26000.00')
    assert Decimal(profit['net_profit']) == Decimal('199000.00')
    # I owe the supplier for all 100 accepted, once.
    summary = client.get(API + '/finance/summary', headers=OPS).json()
    assert Decimal(summary['i_owe']['ledger']) == Decimal('650000.00')
    receipt = lost.json()['receipts'][0]
    assert post(client, f"/lpos/receipts/{receipt['id']}/cancel", {'reason': 'Wrong'}).status_code == 409


def test_demand_board_ranks_urgent_shortfalls_and_suggests_suppliers(client, seeded, marked):
    def requirement(quantity, days):
        response = post(client, '/requirements', {'buyer': {'business_name': 'Hotel', 'region': 'Dar es Salaam'},
            'category': 'broilers', 'quantity': quantity, 'unit_type': 'bird',
            'needed_by_date': (TODAY_D + timedelta(days=days)).isoformat(),
            'delivery_area': 'Mbezi', 'delivery_region': 'Pwani'}, OPS)
        assert response.status_code in (200, 201), response.text
        return response.json()['id']
    later = requirement('50', 20)
    soon = requirement('200', 2)
    board = client.get(API + '/lpos/demand', headers=STAFF).json()
    assert [row['id'] for row in board] == [soon, later]
    assert board[0]['urgency'] == 'urgent' and board[0]['short'] == '200.000'
    top = board[0]['suppliers'][0]
    assert top['supplier_id'] == seeded['supplier'] and 'In Pwani' in top['reasons']
    # A fixed-quantity LPO for it covers the shortfall.
    draft(client, seeded, demand_id=soon, supply_basis='fixed', lines=[
        {'category': 'broilers', 'item': 'Broilers', 'unit': 'bird', 'unit_price': '6500', 'quantity': '150'}])
    board = client.get(API + '/lpos/demand', headers=STAFF).json()
    assert board[0]['short'] == '50.000' and board[0]['on_lpo'] == '150.000'


def test_close_cancel_extend_and_acceptance(client, seeded, marked, monkeypatch):
    monkeypatch.setattr(notes, 'dispatch', lambda job: job())
    lpo = issue(client, draft(client, seeded))
    accepted = post(client, f"/lpos/{lpo['id']}/acceptance", {'accepted_on': TODAY, 'name': 'Antonia Anacleth'})
    assert accepted.status_code == 200 and accepted.json()['status'] == 'accepted'
    later = (TODAY_D + timedelta(days=10)).isoformat()
    assert post(client, f"/lpos/{lpo['id']}/extend", {'delivery_end': later, 'reason': 'Batch delayed'}, STAFF).status_code == 403
    extended = post(client, f"/lpos/{lpo['id']}/extend", {'delivery_end': later, 'reason': 'Batch delayed'})
    assert extended.json()['delivery_end'] == later and 'Batch delayed' in extended.json()['internal_notes']
    assert receive(client, lpo, '5', '5').status_code == 201
    assert post(client, f"/lpos/{lpo['id']}/cancel", {'reason': 'x no'}).status_code == 409
    closed = post(client, f"/lpos/{lpo['id']}/close", {'reason': 'Window over'})
    assert closed.json()['status'] == 'closed'
    assert receive(client, lpo, '5', '5').status_code == 409
    unused = draft(client, seeded)
    assert post(client, f"/lpos/{unused['id']}/cancel", {'reason': 'Not needed'}).json()['status'] == 'cancelled'
    listed = client.get(API + '/lpos?status=closed', headers=STAFF).json()
    assert [row['id'] for row in listed['items']] == [lpo['id']]
