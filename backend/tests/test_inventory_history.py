from concurrent.futures import ThreadPoolExecutor
from datetime import date
from decimal import Decimal
import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError
from app import models as m, services as s, contracts as c
from test_commerce import headers, reserve, order


def sell(client, seeded, quantity='2', key='external-sale-001'):
    return client.post(f"/api/v1/supplier/stock/{seeded['listing']}/sales", headers=headers('supplier', key), json={'quantity': quantity, 'sold_on': date.today().isoformat(), 'unit_price': '9500', 'note': 'Local market sale'})


def test_correction_preserves_sold_and_creates_history(client, sessions, seeded):
    sale = sell(client, seeded)
    assert sale.status_code == 200
    response = client.post(f"/api/v1/supplier/stock/{seeded['listing']}/corrections", headers=headers('supplier', 'correction-key'), json={'counted_on_hand': '7', 'reason': 'Original count was one too high'})
    assert response.status_code == 200
    assert Decimal(response.json()['quantity_total']) == 9
    assert Decimal(response.json()['quantity_sold']) == 2
    assert Decimal(response.json()['quantity_available']) == 7
    with sessions() as db:
        assert len(db.scalars(select(m.StockSale)).all()) == 1
        correction = db.scalar(select(m.StockMovement).where(m.StockMovement.kind == 'correction'))
        assert correction.total_delta == -1 and correction.sold_delta == 0


def test_external_sale_retries_deduct_once_and_do_not_create_settlements(client, sessions, seeded):
    first, again = sell(client, seeded), sell(client, seeded)
    assert first.status_code == again.status_code == 200
    assert first.json()['id'] == again.json()['id']
    assert sell(client, seeded, '3').status_code == 409
    with sessions() as db:
        assert db.get(m.Listing, seeded['listing']).quantity_sold == 2
        assert len(db.scalars(select(m.StockSale)).all()) == 1
        assert db.scalar(select(m.Settlement)) is None
        assert db.scalar(select(m.Payment)) is None


def test_reserved_stock_cannot_be_sold_elsewhere_or_corrected_away(client, sessions, seeded):
    reserve(sessions, seeded, 8)
    assert sell(client, seeded, '3').status_code == 409
    response = client.post(f"/api/v1/supplier/stock/{seeded['listing']}/corrections", headers=headers('supplier'), json={'counted_on_hand': '7', 'reason': 'Physical stock recount'})
    assert response.status_code == 409
    with sessions() as db:
        row = db.get(m.Listing, seeded['listing'])
        assert row.quantity_reserved == 8 and row.quantity_sold == 0 and row.quantity_total == 10


def test_sales_and_corrections_are_immutable_in_database(client, sessions, seeded):
    sell(client, seeded)
    for table in ['stock_sales', 'stock_movements']:
        with pytest.raises(DBAPIError, match='append-only'), sessions.begin() as db:
            db.execute(text(f'DELETE FROM {table}'))
        with pytest.raises(DBAPIError, match='append-only'), sessions.begin() as db:
            db.execute(text(f'UPDATE {table} SET created_at = now()'))


def test_incoming_stock_is_separate_from_correction(client, sessions, seeded):
    response = client.post(f"/api/v1/supplier/stock/{seeded['listing']}/additions", headers=headers('supplier'), json={'quantity': '5', 'reason': 'Five birds received in same batch'})
    assert response.status_code == 200
    assert Decimal(response.json()['quantity_available']) == 15
    with sessions() as db:
        event = db.scalar(select(m.StockMovement).where(m.StockMovement.kind == 'stock_added'))
        assert event.total_delta == 5 and event.sold_delta == 0


def test_history_balances_reconcile_and_hide_buyer_identity(client, sessions, seeded):
    hold = reserve(sessions, seeded, 3)
    client.delete(f'/api/v1/reservations/{hold}', headers=headers())
    sell(client, seeded)
    response = client.get(f"/api/v1/supplier/stock/{seeded['listing']}/history", headers=headers('supplier'))
    assert response.status_code == 200
    assert 'buyer_id' not in response.text and seeded['buyer'] not in response.text
    events = response.json()
    with sessions() as db:
        row = db.get(m.Listing, seeded['listing'])
        for field in ['total', 'reserved', 'sold']:
            assert sum(Decimal(event[field + '_delta']) for event in events) == getattr(row, 'quantity_' + field)
    assert client.get(f"/api/v1/supplier/stock/{seeded['listing']}/history", headers=headers()).status_code == 403


def test_omoterra_delivery_records_one_automatic_sale(client, sessions, seeded):
    id = order(sessions, seeded)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        for status in ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']:
            s.advance(db, row, c.Progress(internal_status=status, actual_quantity=3, rejected_quantity=1))
        s.advance(db, row, c.Progress(internal_status='delivered'))
        sales = db.scalars(select(m.StockSale)).all()
        assert len(sales) == 1 and sales[0].source == 'omoterra' and sales[0].quantity == 3
    response = client.get('/api/v1/supplier/sales', headers=headers('supplier'))
    assert response.json()[0]['unit_price'] is None
    assert 'buyer' not in response.text and 'order_item_id' not in response.text


def test_old_quantity_overwrite_is_rejected(client, seeded):
    response = client.patch(f"/api/v1/supplier/stock/{seeded['listing']}", headers=headers('supplier'), json={'action': 'update', 'quantity_total': '8'})
    assert response.status_code == 422


def test_two_simultaneous_sales_cannot_oversell(client, sessions, seeded):
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda key: sell(client, seeded, '7', key), ['concurrent-sale-a', 'concurrent-sale-b']))
    assert sorted(r.status_code for r in responses) == [200, 409]
    with sessions() as db:
        row = db.get(m.Listing, seeded['listing'])
        assert row.quantity_sold == 7 and row.quantity_available == 3


def test_reversing_mistaken_external_sale_preserves_original_and_returns_stock(client, sessions, seeded):
    original = sell(client, seeded).json()
    url = f"/api/v1/supplier/sales/{original['id']}/reverse"
    response = client.post(url, headers=headers('supplier', 'reverse-sale-key'), json={'reason': 'Entered the wrong stock batch'})
    assert response.status_code == 200 and response.json()['status'] == 'reversed'
    assert client.post(url, headers=headers('supplier', 'reverse-sale-key'), json={'reason': 'Entered the wrong stock batch'}).status_code == 200
    assert client.post(url, headers=headers('supplier', 'other-reverse-key'), json={'reason': 'Entered the wrong stock batch'}).status_code == 409
    with sessions() as db:
        row = db.get(m.Listing, seeded['listing'])
        assert row.quantity_sold == 0 and row.quantity_available == 10
        assert db.get(m.StockSale, original['id']).quantity == 2
        assert len(db.scalars(select(m.StockSaleReversal)).all()) == 1
        assert db.scalar(select(m.StockMovement).where(m.StockMovement.kind == 'sale_reversed')).sold_delta == -2
