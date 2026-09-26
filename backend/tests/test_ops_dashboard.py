from decimal import Decimal
from test_commerce import headers, order, reserve

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def ops(client, path):
    return client.get('/api/v1/ops' + path, headers=OPS)


def test_ops_endpoints_reject_mobile_sessions(client, seeded):
    for path in ['/summary', '/payments', '/suppliers', '/buyers']:
        assert ops(client, path).status_code == 200
        assert client.get('/api/v1/ops' + path, headers=headers()).status_code == 403


def test_summary_counts_attention_items(client, sessions, seeded):
    order(sessions, seeded)
    body = ops(client, '/summary').json()
    assert body['orders_today'] == 1
    assert Decimal(body['sales_today']) == Decimal('48000.00')
    # Gross margin is buyer price less supplier payout, never the asking price.
    assert Decimal(body['gross_margin_today']) == Decimal('12000.00')
    assert body['attention']['orders_in_progress'] == 1
    assert body['attention']['listings_pending_review'] == 0
    assert body['attention']['payments_pending'] == 1


def test_summary_excludes_cancelled_orders_from_sales(client, sessions, seeded):
    id = order(sessions, seeded)
    client.post(f'/api/v1/ops/orders/{id}/progress', headers={**OPS, 'Idempotency-Key': 'cancel-key'},
        json={'internal_status': 'cancelled'})
    body = ops(client, '/summary').json()
    assert Decimal(body['sales_today']) == 0
    assert body['attention']['orders_in_progress'] == 0


def test_payments_list_exposes_balance_for_reconciliation(client, sessions, seeded):
    id = order(sessions, seeded)
    body = ops(client, '/payments').json()
    assert body['total'] == 1 and body['actionable'] == 1
    rows = body['items']
    assert len(rows) == 1
    row = rows[0]
    assert row['order_id'] == id
    assert row['method'] == 'pay_on_delivery'
    assert row['status'] == 'pending'
    assert Decimal(row['balance']) == Decimal(row['amount'])
    assert row['buyer_name'] == 'Buyer Test'


def test_suppliers_list_is_internal_only_and_never_buyer_facing(client, sessions, seeded):
    rows = ops(client, '/suppliers').json()['items']
    assert len(rows) == 1
    row = rows[0]
    assert row['legal_name'] == 'Secret legal name'
    assert row['public_alias'] == 'Green Pastures'
    assert row['live_listings'] == 1
    # The same supplier identity must stay hidden on the buyer surface.
    listing = client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).json()
    assert 'Secret legal name' not in str(listing)
    assert 'Secret farm address' not in str(listing)


def test_buyers_list_never_leaks_to_supplier_surface(client, sessions, seeded):
    order(sessions, seeded)
    rows = ops(client, '/buyers').json()['items']
    row = next(r for r in rows if r['name'] == 'Buyer Test')
    assert row['order_count'] == 1
    assert row['buyer_type'] is None or isinstance(row['buyer_type'], str)
    # Supplier-facing reservation views must not carry buyer identity.
    supplier_view = client.get('/api/v1/supplier/orders', headers=headers('supplier')).json()
    assert 'Buyer Test' not in str(supplier_view)
    assert '+255712345678' not in str(supplier_view)
    assert 'Secret buyer address' not in str(supplier_view)


def test_buyer_detail_includes_addresses_for_delivery_scheduling(client, sessions, seeded):
    body = ops(client, f"/buyers/{seeded['buyer']}").json()
    assert body['name'] == 'Buyer Test'
    assert len(body['addresses']) == 1
    assert body['addresses'][0]['address_text'] == 'Secret buyer address'


def test_supplier_detail_lists_stock_and_settlements(client, sessions, seeded):
    body = ops(client, f"/suppliers/{seeded['supplier']}").json()
    assert body['legal_name'] == 'Secret legal name'
    assert body['internal_pickup_address'] == 'Secret farm address'
    assert len(body['listings']) == 1
    assert body['settlements'] == []


def test_cancel_releases_reserved_stock_exactly(client, sessions, seeded):
    from app import models as m
    id = order(sessions, seeded, quantity=4)
    with sessions() as db:
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 4
    response = client.post(f'/api/v1/ops/orders/{id}/progress', headers={**OPS, 'Idempotency-Key': 'ops-cancel-1'},
        json={'internal_status': 'cancelled'})
    assert response.status_code == 200
    with sessions() as db:
        listing = db.get(m.Listing, seeded['listing'])
        assert listing.quantity_reserved == 0
        assert listing.quantity_sold == 0
        assert listing.quantity_available == 10


def test_dashboard_aggregates_kpis_trend_batches_and_activity(client, sessions, seeded):
    from datetime import date, timedelta
    from app import models as m
    order(sessions, seeded)
    today = date.today()
    with sessions.begin() as db:
        common = dict(supplier_id=seeded['supplier'], category='broilers', initial_quantity=100, current_quantity=100,
            expected_ready_date=(today + timedelta(days=10)).isoformat())
        db.add_all([m.SupplierBatch(**common, status='growing', approved_at=m.now()),
            m.SupplierBatch(**common, status='growing'),
            m.SupplierBatch(**common, status='completed', approved_at=m.now()),
            m.SupplierBatch(**common, status='cancelled')])
    body = ops(client, '/dashboard').json()
    assert body['kpis']['active_suppliers'] == 1 and body['kpis']['approved_suppliers'] == 1
    assert body['kpis']['active_batches'] == 2
    assert body['kpis']['open_orders'] == 1
    assert body['batch_status'] == {'live': 1, 'pending': 1, 'completed': 1}
    # Supplies recorded this month: the seeded listing plus the four batches.
    assert body['supply_trend']['months'][today.month - 1] == 5
    assert body['trading']['orders'] == 1
    assert Decimal(body['trading']['gross_margin']) == Decimal('12000.00')
    assert body['recent_orders'][0]['buyer'] == 'Buyer Test'
    assert body['recent_suppliers'][0]['name'] == 'Green Pastures'
    kinds = [row['kind'] for row in body['recent_activity']]
    assert 'order_created' in kinds and 'batch_created' in kinds
    assert len(body['recent_activity']) <= 6


def test_dashboard_period_excludes_older_records_and_rejects_reversed_range(client, sessions, seeded):
    order(sessions, seeded)
    body = ops(client, '/dashboard?start=2020-01-01&end=2020-01-31').json()
    assert body['trading']['orders'] == 0
    assert body['recent_orders'] == [] and body['recent_suppliers'] == [] and body['recent_activity'] == []
    # Current-state figures do not depend on the chosen period.
    assert body['kpis']['open_orders'] == 1
    assert ops(client, '/dashboard?start=2020-02-01&end=2020-01-01').status_code == 422
