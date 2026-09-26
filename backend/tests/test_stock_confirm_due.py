from datetime import timedelta
from app import models as m
from test_commerce import headers


def listing(db, supplier, status, due_in_hours, quantity=10):
    row = m.Listing(supplier_id=supplier, category='broilers', unit_type='bird', specs={}, region='Pwani',
        quantity_total=quantity, farmer_asking_price_per_unit=10000, supplier_payout_price_per_unit=9000,
        buyer_price_per_unit=12000, listing_status=status, approved_at=m.now(),
        last_confirmed_at=m.now() - timedelta(hours=40), confirmation_due_at=m.now() + timedelta(hours=due_in_hours))
    db.add(row); db.flush()
    return row.id


def test_one_tap_confirms_only_stock_that_is_due(client, sessions, seeded):
    with sessions.begin() as db:
        # seeded listing is live and due in 48h: not due yet
        hidden = listing(db, seeded['supplier'], 'live', -2)       # lapsed
        soon = listing(db, seeded['supplier'], 'live', 5)          # due within 12h
        paused = listing(db, seeded['supplier'], 'paused', -2)     # chosen pause: leave alone
        empty = listing(db, seeded['supplier'], 'live', -2, quantity=0)
    due = {row['id'] for row in client.get('/api/v1/supplier/stock/due', headers=headers('supplier')).json()}
    assert due == {hidden, soon}
    confirmed = client.post('/api/v1/supplier/stock/confirm-due', headers=headers('supplier', 'confirm-due-01'))
    assert confirmed.status_code == 200, confirmed.text
    assert confirmed.json() == {'confirmed': 2}
    retried = client.post('/api/v1/supplier/stock/confirm-due', headers=headers('supplier', 'confirm-due-01'))
    assert retried.json() == {'confirmed': 2}
    assert client.get('/api/v1/supplier/stock/due', headers=headers('supplier')).json() == []
    with sessions() as db:
        assert db.get(m.Listing, hidden).listing_status == 'live'
        assert db.get(m.Listing, hidden).confirmation_due_at > m.now() + timedelta(hours=40)
        assert db.get(m.Listing, paused).listing_status == 'paused'
    # Buyers can see the lapsed stock again.
    assert client.get(f'/api/v1/listings/{hidden}', headers=headers()).status_code == 200


def test_other_suppliers_stock_is_untouched(client, sessions, seeded):
    with sessions.begin() as db:
        stranger = m.User(phone='+255712340009', roles=['supplier'], name='Other')
        db.add(stranger); db.flush()
        db.add(m.SupplierProfile(user_id=stranger.id, legal_name='O', internal_pickup_address='x', status='approved'))
        theirs = listing(db, stranger.id, 'live', -2)
    client.post('/api/v1/supplier/stock/confirm-due', headers=headers('supplier', 'confirm-due-02'))
    with sessions() as db:
        assert db.get(m.Listing, theirs).confirmation_due_at < m.now()  # not extended


def test_reminder_opens_the_confirm_question(sessions, seeded, monkeypatch):
    from app import notifications as notes
    from app.reminders import remind_stale_stock
    monkeypatch.setattr(notes, 'dispatch', lambda job: job())
    with sessions.begin() as db:
        row = db.get(m.Listing, seeded['listing'])
        row.confirmation_due_at = m.now() + timedelta(hours=3)
    with sessions.begin() as db:
        remind_stale_stock(db)
        note = db.query(m.Notification).one()
        assert note.link == f"/stock/{seeded['listing']}?confirm=1"
