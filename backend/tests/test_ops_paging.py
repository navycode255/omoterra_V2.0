"""Operations lists page and search in the database, and never hide work
(docs/plan-high-priority-gaps.md, phase 3)."""
from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select

from app import models as m

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def ops(client, path):
    response = client.get('/api/v1/ops' + path, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def volume(sessions, seeded, orders=500, settlements=300):
    """`orders` orders, the first `settlements` of them settled. The oldest
    settlement is still unpaid; every newer one is paid. Every fifth order
    carries stock from a second supplier, Kilimo Bora Farms."""
    start = m.now() - timedelta(days=orders)
    with sessions.begin() as db:
        other = m.User(phone='+255712345690', roles=['supplier'], name='Kilimo owner', region='Arusha')
        db.add(other); db.flush()
        db.add(m.SupplierProfile(user_id=other.id, legal_name='Kilimo Bora Farms Ltd', public_alias='Kilimo Bora Farms',
            internal_pickup_address='Arusha farm', status='approved', categories=['goats'], region='Arusha'))
        goats = m.Listing(supplier_id=other.id, category='goats', unit_type='animal', specs={}, region='Arusha',
            quantity_total=1000, farmer_asking_price_per_unit=100000, supplier_payout_price_per_unit=90000,
            buyer_price_per_unit=120000, listing_status='live', last_confirmed_at=m.now(),
            confirmation_due_at=m.now() + timedelta(hours=48), approved_at=m.now())
        db.add(goats); db.flush()
        kilimo = []
        for n in range(orders):
            at = start + timedelta(days=n)
            ours = n % 5 == 0
            listing, supplier = (goats.id, other.id) if ours else (seeded['listing'], seeded['supplier'])
            order = m.Order(buyer_id=seeded['buyer'], delivery_snapshot={'region': 'Dar'}, preferred_delivery_date='2027-01-01',
                payment_method='pay_on_delivery', internal_status='completed' if n < orders - 20 else 'reserved',
                expected_quantity=1, total_amount=12000, idempotency_key=f'volume-{n}', created_at=at)
            db.add(order); db.flush()
            item = m.OrderItem(order_id=order.id, listing_id=listing, quantity=1, unit_price=12000, subtotal=12000,
                asking_snapshot=10000, payout_snapshot=9000, created_at=at)
            db.add(item); db.flush()
            if ours:
                kilimo.append(order.id)
            if n < settlements:
                db.add(m.Settlement(supplier_id=supplier, order_item_id=item.id, farmer_asking_price_per_unit=10000,
                    supplier_payout_price_per_unit=9000, commission_amount_per_unit=1000, quantity=1, total_payable=9000,
                    status='pending' if n == 0 else 'paid', paid_at=None if n == 0 else at,
                    payment_reference=None if n == 0 else f'PAY-{n}', created_at=at))
        oldest = db.scalar(select(m.Settlement.id).where(m.Settlement.status == 'pending'))
    return {'kilimo_orders': kilimo, 'oldest_unpaid': oldest, 'kilimo': other.id}


def test_oldest_unpaid_settlement_is_on_the_first_page(client, sessions, seeded):
    seen = volume(sessions, seeded)
    body = ops(client, '/settlements')
    assert body['total'] == 300
    assert body['page'] == 1 and body['page_size'] == 50
    assert body['actionable'] == 1
    # Unpaid work leads the page even though it is the oldest row of 300.
    assert body['items'][0]['id'] == seen['oldest_unpaid']
    assert body['items'][0]['status'] == 'pending'
    assert body['counts'] == {'all': 300, 'pending': 1, 'paid': 299}
    assert Decimal(body['totals']['pending']) == Decimal('9000')
    assert Decimal(body['totals']['paid']) == Decimal('9000') * 299
    # History pages behind it are paid rows only, newest first, and never repeat.
    second = ops(client, '/settlements?page=2&page_size=100')
    assert all(row['status'] == 'paid' for row in second['items'])
    ids = [row['id'] for page in (1, 2, 3) for row in ops(client, f'/settlements?page={page}&page_size=100')['items']]
    assert len(ids) == len(set(ids)) == 300


def test_searching_a_supplier_finds_all_their_orders(client, sessions, seeded):
    seen = volume(sessions, seeded)
    found = []
    for page in (1, 2):
        body = ops(client, f'/orders?q=kilimo%20bora&page={page}&page_size=100')
        assert body['total'] == 100
        found += [row['id'] for row in body['items']]
    assert sorted(found) == sorted(seen['kilimo_orders'])
    # The legal name, a category and an order reference find them too.
    assert ops(client, '/orders?q=Bora%20Farms%20Ltd')['total'] == 100
    assert ops(client, '/orders?q=goat')['total'] == 100
    ref = 'OR-' + seen['kilimo_orders'][0].replace('-', '')[:6].upper()
    assert seen['kilimo_orders'][0] in [row['id'] for row in ops(client, f'/orders?q={ref}')['items']]
    # Settlements search the same way.
    assert ops(client, '/settlements?q=kilimo')['total'] == 60


def test_orders_in_progress_are_never_paged_away(client, sessions, seeded):
    volume(sessions, seeded)
    body = ops(client, '/orders?page_size=5')
    assert body['total'] == 500 and body['actionable'] == 20
    assert len(body['items']) == 25
    assert all(row['internal_status'] == 'reserved' for row in body['items'][:20])
    # Oldest open order first.
    created = [row['created_at'] for row in body['items'][:20]]
    assert created == sorted(created)
    assert len(ops(client, '/orders?page=2&page_size=5')['items']) == 5
    open_only = ops(client, '/orders?status=open')
    assert open_only['total'] == 20 and len(open_only['items']) == 20
    assert open_only['counts']['open'] == 20 and open_only['counts']['delivered'] == 480


def test_page_size_is_capped_and_filters_combine(client, sessions, seeded):
    volume(sessions, seeded, orders=150, settlements=0)
    body = ops(client, '/orders?status=delivered&page_size=500')
    assert body['page_size'] == 100 and len(body['items']) == 100 and body['total'] == 130
    assert ops(client, '/orders?status=delivered&q=kilimo')['total'] == 26
    assert client.get('/api/v1/ops/orders?page=0', headers=OPS).status_code == 422


def test_every_ops_list_speaks_the_contract(client, sessions, seeded):
    volume(sessions, seeded, orders=10, settlements=5)
    for path in ['/orders', '/settlements', '/payments', '/listings', '/requests', '/requirements',
                 '/business-opportunities', '/suppliers', '/buyers', '/buyer-crm', '/ratings']:
        body = ops(client, path + '?q=a')
        assert {'items', 'total', 'page', 'page_size', 'actionable'} <= set(body), path
        body = ops(client, path)
        assert body['page'] == 1 and body['total'] >= len(body['items']), path
    suppliers = ops(client, '/suppliers?q=kilimo')
    assert [row['legal_name'] for row in suppliers['items']] == ['Kilimo Bora Farms Ltd']
    listings = ops(client, '/listings?q=arusha')
    assert listings['total'] == 1 and listings['items'][0]['category'] == 'goats'
    assert ops(client, f"/listings/{listings['items'][0]['id']}")['region'] == 'Arusha'
    buyers = ops(client, '/buyer-crm?q=buyer%20test')
    assert [row['business_name'] for row in buyers['items']] == ['Buyer Test']
    assert buyers['items'][0]['crm_record'] is False


def test_stock_awaiting_review_leads_the_supply_list(client, sessions, seeded):
    with sessions.begin() as db:
        for n in range(120):
            db.add(m.Listing(supplier_id=seeded['supplier'], category='broilers', unit_type='bird', specs={}, region='Pwani',
                quantity_total=10, farmer_asking_price_per_unit=10000, listing_status='sold_out',
                created_at=m.now() - timedelta(minutes=n)))
        waiting = m.Listing(supplier_id=seeded['supplier'], category='broilers', unit_type='bird', specs={}, region='Pwani',
            quantity_total=10, farmer_asking_price_per_unit=10000, listing_status='pending_review',
            created_at=m.now() - timedelta(days=90))
        stale = db.get(m.Listing, seeded['listing'])
        stale.confirmation_due_at = m.now() - timedelta(hours=1)
        db.add(waiting); db.flush()
        waiting_id = waiting.id
    body = ops(client, '/listings')
    assert body['actionable'] == 2
    assert body['items'][0]['id'] == waiting_id
    assert body['items'][1]['id'] == seeded['listing']
    assert body['counts']['needs_confirmation'] == 1 and body['counts']['live'] == 0
    assert body['counts']['sold_out'] == 120
