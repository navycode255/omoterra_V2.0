"""M1.3 (audit F02, decision D3): known, free and unknown buying costs, and
opening stock.

- A sale line's cost is known, free (a known zero an admin approved with a
  reason) or unknown. Unknown is not zero (rule R5): the sale has no final
  margin and every period containing it is "Provisional: buying costs
  incomplete", with the sales and revenue affected.
- Opening stock is stock held before the system, valued by the finance
  owner: a receipt with a value and no payable. Selling from it gives a
  known cost; it never goes below zero.
- An admin gives an unknown line a cost later (opening stock, an evidenced
  cost, or free), writing a financial adjustment before and after.
"""
import os
import uuid
from decimal import Decimal

import pytest
from sqlalchemy import create_engine, select, text

from app import finance_exceptions as fx, migrations, models as m, reporting as rp
from test_finance import API, OPS, STAFF, TODAY, post, sale

PROVISIONAL = 'Provisional: buying costs incomplete'


def get(client, path, headers=OPS, **params):
    response = client.get(API + path, params=params, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def profit(client):
    return get(client, '/finance/profit', start=TODAY, end=TODAY)


def opening(client, quantity='50', headers=OPS, **values):
    body = {'category': 'local_chicken', 'unit': 'bird', 'quantity': quantity, 'as_of': TODAY,
            'evidence': 'Counted 50 kienyeji at the Tegeta pen; bought at 6,000 each in September',
            'valued_by': 'Maternus Joshua', **values}
    if 'unit_cost' not in values and 'total_value' not in values:
        body['unit_cost'] = '6000'
    return post(client, '/opening-stock', body, headers)


def unknown_sale(client, quantity='3', price='7000'):
    return sale(client, items=[{'category': 'local_chicken', 'unit': 'bird', 'quantity': quantity,
        'unit_price': price, 'cost_unknown': True}])


def resolve(client, body, item, request, headers=OPS):
    return post(client, f"/sales/{body['id']}/items/{item['id']}/cost", request, headers)


def debts(sessions):
    with sessions() as db:
        return db.scalars(select(m.LedgerDebt)).all()


# ---- R5: unknown is never a final margin --------------------------------------

def test_an_unknown_cost_is_never_a_final_margin(client, sessions, engine, monkeypatch):
    from app import db as app_db
    # The report reads one snapshot through the app's engine.
    monkeypatch.setattr(app_db, 'engine', engine)
    known = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '7000',
        'supplier_name': 'Mzee Juma', 'unit_cost': '5000'}])
    body = unknown_sale(client)
    # API: the sale and its line have no margin, only "cost unknown".
    assert body['margin'] is None and body['cost_state'] == 'unknown' and body['unknown_cost_lines'] == 1
    assert body['items'][0]['cost_state'] == 'unknown' and body['items'][0]['margin'] is None
    assert body['items'][0]['unit_cost'] is None and Decimal(body['cost_amount']) == 0
    assert Decimal(known['margin']) == Decimal('20000') and known['cost_state'] == 'known'
    # Profit: provisional, with how many sales and how much revenue.
    report = profit(client)
    assert report['provisional'] is True and report['provisional_label'] == PROVISIONAL
    assert report['unknown_cost'] == {'lines': 1, 'sales': 1, 'revenue': '21000.00'}
    [today] = report['days']
    assert today['provisional'] is True and today['unknown_cost_lines'] == 1
    # The unknown line adds nothing to cost of goods, never a zero cost row.
    assert Decimal(report['stock_cost']) == Decimal('50000')
    rows = get(client, '/finance/rows', metric='cost_of_goods', start=TODAY, end=TODAY)['items']
    assert {r['cost_state'] for r in rows} == {'known', 'unknown'}
    # Finance overview, Sales and Reports carry the same flag.
    summary = get(client, '/finance/summary')
    assert summary['profit_today']['provisional'] and summary['profit_month']['provisional']
    assert summary['profit_selected']['unknown_cost']['sales'] == 1
    sales = get(client, '/sales', start=TODAY, end=TODAY)['summary']
    assert sales['provisional'] is True and sales['unknown_cost'] == {'lines': 1, 'sales': 1, 'revenue': '21000.00'}
    report = get(client, '/finance/reports', start=TODAY, end=TODAY)
    assert report['provisional'] is True and report['provisional_label'] == PROVISIONAL
    [chicken] = [p for p in report['products'] if p['category'] == 'local_chicken']
    assert chicken['gross_margin'] is None and chicken['unknown_lines'] == 1
    assert report['forecast'] is None and any(PROVISIONAL in issue for issue in report['forecast_blockers'])
    # The exception report lists it from cost_state.
    with sessions() as db:
        assert [r['sale_item_id'] for r in fx.unknown_cost_lines(db)['records']] == [body['items'][0]['id']]
    listed = get(client, '/finance/unknown-costs')
    assert listed['summary'] == {'lines': 1, 'sales': 1, 'revenue': '21000.00'}
    assert listed['items'][0]['sale_number'] == body['sale_number']


def test_a_period_without_unknown_costs_is_not_provisional(client):
    sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '7000',
        'unit_cost': '5000'}])
    report = profit(client)
    assert report['provisional'] is False and report['provisional_label'] is None
    assert report['unknown_cost'] == {'lines': 0, 'sales': 0, 'revenue': '0'}
    assert Decimal(report['gross_profit']) == Decimal('4000')


def test_paying_a_supplier_early_does_not_change_margin(client, seeded):
    body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '10', 'unit_price': '7500',
        'supplier_id': seeded['supplier'], 'unit_cost': '6500'}])
    before, report = Decimal(body['margin']), profit(client)
    assert before == Decimal('10000')
    # Paid at once, long before any due date, through a transfer.
    paid = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments",
        {'amount': '65000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'EARLY-1'})
    assert paid.status_code == 201, paid.text
    after = get(client, f"/sales/{body['id']}")
    assert Decimal(after['margin']) == before and Decimal(after['cost_amount']) == Decimal('65000')
    again = profit(client)
    for key in ('revenue', 'cost_of_goods', 'gross_profit', 'net_profit'):
        assert again[key] == report[key]
    assert again['provisional'] is False


# ---- opening stock (D3) ---------------------------------------------------------

def test_opening_stock_has_no_payable_and_sells_at_a_known_cost(client, sessions):
    assert opening(client, headers=STAFF).status_code == 403
    assert opening(client, unit_cost='6000', total_value='300000').status_code == 422
    assert opening(client, evidence='x').status_code == 422
    assert opening(client, quantity='2.5').status_code == 422  # whole birds
    created = opening(client, total_value='300000')
    assert created.status_code == 201, created.text
    stock = created.json()
    assert stock['receipt_number'].startswith('OS-') and stock['label'] == 'Opening stock'
    assert Decimal(stock['unit_cost']) == Decimal('6000') and Decimal(stock['amount']) == Decimal('300000')
    assert Decimal(stock['on_hand']) == 50 and stock['valued_by'] == 'Maternus Joshua'
    # No payable, no supplier debt, no money moved.
    assert debts(sessions) == []
    assert Decimal(get(client, '/finance/summary')['i_owe']['total']) == 0
    # Selling from it: a known cost and margin, still nobody owed.
    body = sale(client, items=[{'quantity': '20', 'unit_price': '8000', 'opening_stock_id': stock['id']}])
    [item] = body['items']
    assert item['cost_state'] == 'known' and item['opening_stock_id'] == stock['id']
    assert item['unit'] == 'bird' and item['category'] == 'local_chicken' and item['opening_stock_number'] == stock['receipt_number']
    assert Decimal(item['cost_total']) == Decimal('120000') and Decimal(body['margin']) == Decimal('40000')
    assert [d['direction'] for d in body['debts']] == ['receivable']
    report = profit(client)
    assert report['provisional'] is False and Decimal(report['gross_profit']) == Decimal('40000')
    assert Decimal(get(client, f"/opening-stock/{stock['id']}")['on_hand']) == 30
    with sessions() as db:
        [row] = [r for r in rp.stock_on_hand(db)['rows'] if r['source_table'] == 'opening_stock']
        assert row['quantity'] == 30 and row['amount'] == Decimal('180000')
    # It never goes below zero, also across lines of one sale.
    over = post(client, '/sales', {'new_buyer': {'business_name': 'Too many'}, 'sold_on': TODAY,
        'items': [{'quantity': '31', 'unit_price': '8000', 'opening_stock_id': stock['id']}]})
    assert over.status_code == 422 and 'Only 30' in over.text
    split = post(client, '/sales', {'new_buyer': {'business_name': 'Split'}, 'sold_on': TODAY, 'items': [
        {'quantity': '20', 'unit_price': '8000', 'opening_stock_id': stock['id']},
        {'quantity': '11', 'unit_price': '8000', 'opening_stock_id': stock['id']}]})
    assert split.status_code == 422
    # Sold in its unit, with no supplier or cost of its own.
    kg = post(client, '/sales', {'new_buyer': {'business_name': 'Kg'}, 'sold_on': TODAY,
        'items': [{'unit': 'kg', 'quantity': '1', 'unit_price': '8000', 'opening_stock_id': stock['id']}]})
    assert kg.status_code == 422
    priced = post(client, '/sales', {'new_buyer': {'business_name': 'Priced'}, 'sold_on': TODAY,
        'items': [{'quantity': '1', 'unit_price': '8000', 'opening_stock_id': stock['id'], 'unit_cost': '1'}]})
    assert priced.status_code == 422
    # A mistaken entry cannot be cancelled once sold from.
    assert post(client, f"/opening-stock/{stock['id']}/cancel", {'reason': 'Typed twice'}).status_code == 409
    listing = get(client, '/opening-stock')
    assert listing['total'] == 1 and Decimal(listing['summary']['value_on_hand']) == Decimal('180000')


def test_opening_stock_back_on_hand_or_lost_when_a_sale_is_cancelled(client):
    stock = opening(client, quantity='10').json()
    line = {'quantity': '4', 'unit_price': '8000', 'opening_stock_id': stock['id']}
    first = sale(client, items=[line])
    second = sale(client, new_buyer={'business_name': 'Second'}, items=[line])
    assert Decimal(get(client, f"/opening-stock/{stock['id']}")['on_hand']) == 2
    back = post(client, f"/sales/{first['id']}/cancel", {'reason': 'Buyer changed mind', 'goods': 'never_left'})
    assert back.status_code == 200, back.text
    lost = post(client, f"/sales/{second['id']}/cancel", {'reason': 'Birds escaped', 'goods': 'not_recovered'})
    assert lost.status_code == 200, lost.text
    detail = get(client, f"/opening-stock/{stock['id']}")
    assert Decimal(detail['on_hand']) == 6 and Decimal(detail['not_recovered']) == 4
    assert {mv['kind'] for mv in detail['movements']} == {'never_left', 'not_recovered'}
    # Not recovered is a stock loss at its opening cost.
    assert Decimal(profit(client)['stock_lost']) == Decimal('24000')
    # Editing a sale to sell fewer asks what happened to the rest (R2).
    third = sale(client, new_buyer={'business_name': 'Third'}, items=[line])
    edit = {'buyer_profile_id': third['buyer_profile_id'], 'sold_on': TODAY,
            'items': [{**line, 'quantity': '1'}]}
    assert client.put(API + f"/sales/{third['id']}", headers=OPS, json=edit).status_code == 422
    edited = client.put(API + f"/sales/{third['id']}", headers=OPS, json={**edit, 'goods': 'never_left'})
    assert edited.status_code == 200, edited.text
    assert Decimal(get(client, f"/opening-stock/{stock['id']}")['on_hand']) == 5


def test_a_mistaken_opening_entry_is_cancelled_with_a_reason(client, sessions):
    stock = opening(client).json()
    assert post(client, f"/opening-stock/{stock['id']}/cancel", {'reason': 'Typed twice'}, STAFF).status_code == 403
    done = post(client, f"/opening-stock/{stock['id']}/cancel", {'reason': 'Typed twice'})
    assert done.status_code == 200, done.text
    assert done.json()['cancelled_at'] and Decimal(done.json()['on_hand']) == 0
    assert get(client, '/opening-stock/available') == []
    with sessions() as db:
        [row] = db.scalars(select(m.FinancialAdjustment)).all()
        assert row.kind == 'opening_stock_cancelled' and row.entity_id == stock['id']


# ---- own stock in the sale form ---------------------------------------------------

def test_own_stock_needs_a_cost_opening_stock_or_cost_unknown(client):
    base = {'new_buyer': {'business_name': 'Own'}, 'sold_on': TODAY}
    line = {'category': 'local_chicken', 'unit': 'bird', 'quantity': '1', 'unit_price': '8000'}
    assert post(client, '/sales', {**base, 'items': [line]}).status_code == 422
    costed = post(client, '/sales', {**base, 'items': [{**line, 'unit_cost': '6000'}]})
    assert costed.status_code == 201, costed.text
    assert costed.json()['items'][0]['cost_state'] == 'known'
    assert [d['direction'] for d in costed.json()['debts']] == ['receivable']
    unknown = post(client, '/sales', {**base, 'items': [{**line, 'cost_unknown': True}]})
    assert unknown.json()['items'][0]['cost_state'] == 'unknown'
    # A cost of 0 is free stock, which only an admin records.
    assert post(client, '/sales', {**base, 'items': [{**line, 'unit_cost': '0'}]}).status_code == 422


# ---- giving an unknown line a cost later ------------------------------------------

def test_giving_a_cost_later_clears_provisional_and_writes_an_adjustment(client, sessions):
    stock = opening(client).json()
    body = unknown_sale(client)
    [item] = body['items']
    assert profit(client)['provisional'] is True
    request = {'how': 'opening_stock', 'opening_stock_id': stock['id'], 'reason': 'Sold from the Tegeta pen count'}
    assert resolve(client, body, item, request, STAFF).status_code == 403
    assert resolve(client, body, item, {**request, 'reason': ' '}).status_code == 422
    assert resolve(client, body, item, {**request, 'opening_stock_id': None}).status_code == 422
    done = resolve(client, body, item, request)
    assert done.status_code == 200, done.text
    after = done.json()
    assert after['cost_state'] == 'known' and Decimal(after['margin']) == Decimal('3000')
    assert after['items'][0]['opening_stock_id'] == stock['id'] and after['items'][0]['cost_state'] == 'known'
    report = profit(client)
    assert report['provisional'] is False and Decimal(report['gross_profit']) == Decimal('3000')
    assert Decimal(get(client, f"/opening-stock/{stock['id']}")['on_hand']) == 47
    assert debts(sessions) and all(d.direction == 'receivable' for d in debts(sessions))
    with sessions() as db:
        [row] = db.scalars(select(m.FinancialAdjustment)).all()
        assert row.kind == 'cost_resolved' and row.entity_type == 'sale_item' and row.entity_id == item['id']
        assert row.before['item']['cost_state'] == 'unknown' and row.before['item']['unit_cost'] is None
        assert row.after['item']['cost_state'] == 'known' and row.after['item']['unit_cost'] == '6000.00'
        assert row.before['sale_cost_amount'] == '0.00' and row.after['sale_cost_amount'] == '18000.00'
        assert row.linked_ids['opening_stock_id'] == stock['id']
        assert fx.unknown_cost_lines(db)['records'] == []
    assert after['cost_adjustments'][0]['kind'] == 'cost_resolved'
    # Already known: refused, never re-costed here.
    assert resolve(client, body, after['items'][0], request).status_code == 409


def test_an_evidenced_cost_needs_evidence_and_opens_no_debt(client, sessions):
    body = unknown_sale(client)
    [item] = body['items']
    request = {'how': 'cost', 'unit_cost': '5500', 'reason': 'Found the purchase receipt'}
    assert resolve(client, body, item, request).status_code == 422
    done = resolve(client, body, item, {**request, 'evidence': 'Receipt 0412 from Kariakoo market, 5,500 each'})
    assert done.status_code == 200, done.text
    assert Decimal(done.json()['margin']) == Decimal('4500') and profit(client)['provisional'] is False
    assert [d.direction for d in debts(sessions)] == ['receivable']
    with sessions() as db:
        [row] = db.scalars(select(m.FinancialAdjustment)).all()
        assert row.linked_ids['evidence'].startswith('Receipt 0412')


def test_free_needs_an_admin_and_a_reason(client, seeded, sessions):
    body = unknown_sale(client)
    [item] = body['items']
    request = {'how': 'free', 'reason': 'Complimentary birds from Antonia'}
    assert resolve(client, body, item, request, STAFF).status_code == 403
    assert resolve(client, body, item, {**request, 'reason': ''}).status_code == 422
    done = resolve(client, body, item, request)
    assert done.status_code == 200, done.text
    after = done.json()
    assert after['items'][0]['cost_state'] == 'free' and Decimal(after['items'][0]['unit_cost']) == 0
    assert Decimal(after['margin']) == Decimal('21000') and profit(client)['provisional'] is False
    # The debt correction "free stock" is the other admin path to free.
    supplied = sale(client, new_buyer={'business_name': 'Gift'}, items=[{'category': 'broilers', 'unit': 'bird',
        'quantity': '2', 'unit_price': '7000', 'supplier_id': seeded['supplier'], 'unit_cost': '5000'}])
    debt = next(d for d in supplied['debts'] if d['direction'] == 'payable')
    corrected = post(client, f"/ledger/debts/{debt['id']}/corrections", {'kind': 'free_stock', 'reason': 'Gift'})
    assert corrected.status_code == 200, corrected.text
    assert get(client, f"/sales/{supplied['id']}")['items'][0]['cost_state'] == 'free'
    # "Cost never existed" makes a line unknown again: provisional.
    other = sale(client, new_buyer={'business_name': 'Never'}, items=[{'category': 'broilers', 'unit': 'bird',
        'quantity': '2', 'unit_price': '7000', 'supplier_name': 'Mzee', 'unit_cost': '5000'}])
    debt = next(d for d in other['debts'] if d['direction'] == 'payable')
    assert post(client, f"/ledger/debts/{debt['id']}/corrections",
        {'kind': 'cost_never_existed', 'reason': 'Our own birds'}).status_code == 200
    after = get(client, f"/sales/{other['id']}")
    assert after['items'][0]['cost_state'] == 'unknown' and after['margin'] is None
    assert profit(client)['provisional'] is True


def test_an_edit_keeps_unknown_and_free_states(client, sessions):
    body = unknown_sale(client)
    line = {'category': 'local_chicken', 'unit': 'bird', 'quantity': '4', 'unit_price': '7000'}
    edit = {'buyer_profile_id': body['buyer_profile_id'], 'sold_on': TODAY}
    assert client.put(API + f"/sales/{body['id']}", headers=OPS, json={**edit, 'items': [line]}).status_code == 422
    kept = client.put(API + f"/sales/{body['id']}", headers=OPS, json={**edit, 'items': [{**line, 'cost_unknown': True}]})
    assert kept.status_code == 200 and kept.json()['items'][0]['cost_state'] == 'unknown'
    [item] = kept.json()['items']
    assert resolve(client, kept.json(), item, {'how': 'free', 'reason': 'Gift'}).status_code == 200
    again = client.put(API + f"/sales/{body['id']}", headers=OPS, json={**edit, 'items': [{**line, 'unit_cost': '0'}]})
    assert again.status_code == 200, again.text
    assert again.json()['items'][0]['cost_state'] == 'free' and Decimal(again.json()['margin']) == Decimal('28000')


# ---- backfill (migration 038) -----------------------------------------------------

@pytest.fixture
def at_037():
    """A database migrated to 037 (before cost states), then 038 on demand."""
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m038_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    later = [path for path in migrations.files() if path.name >= '038']
    original = migrations.files
    migrations.files = lambda: [path for path in original() if path.name < '038']
    try:
        migrations.apply(engine)
    finally:
        migrations.files = original
    yield engine, later
    engine.dispose()
    with admin.begin() as db:
        db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    admin.dispose()


def test_backfill_marks_known_unknown_and_recorded_free(at_037):
    engine, later = at_037
    with engine.begin() as db:
        db.execute(text("""INSERT INTO users (id, phone, name, region, language, roles, deleted, created_at)
            VALUES ('u1', '+255700000001', 'Antonia', '', 'en', '["supplier"]', false, now())"""))
        db.execute(text("INSERT INTO buyer_profiles (id, created_at, business_name) VALUES ('b1', now(), 'Mama Asha')"))
        for sale_id in ('s1', 's2', 's3'):
            db.execute(text(f"""INSERT INTO sales (id, created_at, sale_number, sold_on, buyer_profile_id, buyer_name,
                total_amount) VALUES ('{sale_id}', now(), 'SL-{sale_id}', current_date, 'b1', 'Mama Asha', 1000)"""))
        def line(id, sale_id, cost, supplier=None, name=''):
            db.execute(text("""INSERT INTO sale_items (id, created_at, sale_id, position, description, unit, quantity,
                unit_price, subtotal, supplier_id, supplier_name, unit_cost, cost_total) VALUES (:id, now(), :sale, 1,
                'Birds', 'bird', 1, 1000, 1000, :supplier, :name, :cost, :cost)"""),
                {'id': id, 'sale': sale_id, 'supplier': supplier, 'name': name, 'cost': cost})
        line('known', 's1', 800, 'u1')
        line('own', 's1', None)
        line('free_listed', 's2', 0, 'u1')     # named in the free-stock correction
        line('free_edited', 's3', 0, None, 'Tegeta Sokoni')  # re-created by an edit
        line('zero_no_approval', 's1', 0, None, 'Mzee')
        for id, sale_id, before, items in (
                ('a1', 's2', '{"debt": {"supplier_id": "u1", "party_name": "Antonia"}}', '["free_listed"]'),
                ('a2', 's3', '{"debt": {"supplier_id": null, "party_name": "tegeta sokoni"}}', '["gone"]')):
            db.execute(text(f"""INSERT INTO financial_adjustments (id, created_at, kind, entity_type, entity_id, sale_id,
                reason, before, after, linked_ids) VALUES ('{id}', now(), 'free_stock', 'ledger_debt', 'd-{id}',
                '{sale_id}', 'Gift from the supplier', '{before}', '{{}}', '{{"item_ids": {items}}}')"""))
        # A cost-never-existed line from M1.4: no cost at all.
        line('never', 's2', None)
    assert migrations.apply(engine) == [path.name for path in later]
    with engine.connect() as db:
        states = dict(db.execute(text('SELECT id, cost_state FROM sale_items')).all())
    assert states == {'known': 'known', 'own': 'unknown', 'free_listed': 'free', 'free_edited': 'free',
                      'zero_no_approval': 'unknown', 'never': 'unknown'}
    # The database itself refuses a "known" line without a cost.
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError), engine.begin() as db:
        db.execute(text("UPDATE sale_items SET cost_state = 'known' WHERE id = 'own'"))
    with pytest.raises(IntegrityError), engine.begin() as db:
        db.execute(text("UPDATE sale_items SET cost_state = 'free' WHERE id = 'known'"))
