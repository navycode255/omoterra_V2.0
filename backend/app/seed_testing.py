"""Explicit, repeat-safe local testing scenarios. Never run against production."""
from datetime import date, timedelta
from decimal import Decimal
import uuid
from sqlalchemy import select
from .config import settings
from .db import Session
from . import models as m, contracts as c, services as s, inventory as inv


def fixed(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, 'omoterra-local-testing/' + name))


def run():
    if settings().environment != 'development':
        raise RuntimeError('Testing scenarios are development-only')
    with Session.begin() as db:
        s.commerce_lock(db)
        if db.get(m.Idempotency, 'local-testing-scenarios-v2'):
            print('Testing scenarios already exist; existing records were left unchanged.')
            return
        buyer_id, supplier_id = fixed('buyer'), fixed('supplier')
        for id, phone, name, roles in [(buyer_id, '+255700000001', 'Omoterra Test Account', ['buyer', 'supplier']), (supplier_id, '+255700000002', 'Sample Farm Account', ['supplier'])]:
            existing = db.scalar(select(m.User).where(m.User.phone == phone))
            if existing and existing.id != id:
                raise RuntimeError('A testing phone is already in use; no records were changed')
            if not db.get(m.User, id):
                db.add(m.User(id=id, phone=phone, name=name, roles=roles, region='Dar es Salaam', language='en', buyer_type='restaurant' if 'buyer' in roles else None))
        db.flush()
        for id, alias in [(buyer_id, 'Sample Coast Farm'), (supplier_id, 'Sample Green Pastures')]:
            if not db.get(m.SupplierProfile, id):
                db.add(m.SupplierProfile(user_id=id, legal_name='Local testing profile', internal_pickup_address='Sample pickup point for local testing only', public_alias=alias, alias_approved=True))
        address = m.Address(id=fixed('address'), user_id=buyer_id, label='Test delivery', recipient_name='Test Recipient', phone='+255700000001', region='Dar es Salaam', district_area='Mikocheni', address_text='Sample delivery address — local testing only')
        db.add(address)
        db.flush()
        listing_ids = {}
        specs = {
            'broilers': {'avg_weight_kg': '2.1', 'breed_type': 'Cobb 500', 'age_weeks': '6', 'live_or_dressed': 'live', 'ready_date': date.today().isoformat()},
            'local_chicken': {'avg_weight_kg': '1.6', 'breed_type': 'Local', 'age_weeks': '16', 'live_or_dressed': 'live', 'ready_date': date.today().isoformat()},
            'goats': {'weight_range': '25–35 kg', 'breed': 'Local', 'sex': 'mixed', 'approx_age': '18 months', 'ready_date': date.today().isoformat()},
            'cattle': {'weight_range': '280–350 kg', 'breed': 'Zebu', 'sex': 'male', 'approx_age': '3 years', 'ready_date': date.today().isoformat()},
            'chicken_meat': {'cut_type': 'Whole dressed chicken', 'chilled_or_frozen': 'chilled', 'slaughter_date': date.today().isoformat()},
            'beef': {'cut_type': 'Mixed cuts', 'chilled_or_frozen': 'chilled', 'slaughter_date': date.today().isoformat()},
            'goat_meat': {'cut_type': 'Mixed cuts', 'chilled_or_frozen': 'chilled', 'slaughter_date': date.today().isoformat()},
        }
        prices = {'broilers': 11000, 'local_chicken': 18000, 'goats': 165000, 'cattle': 1400000, 'chicken_meat': 12000, 'beef': 14000, 'goat_meat': 16000}
        for owner, prefix in [(supplier_id, 'market'), (buyer_id, 'own')]:
            for category in specs:
                price = Decimal(prices[category])
                row = m.Listing(id=fixed(prefix + category), supplier_id=owner, category=category, unit_type=c.UNITS[category], specs=specs[category], region='Pwani' if category in ['broilers', 'goats'] else 'Dar es Salaam', quantity_total=300 if category not in ['goats', 'cattle'] else 40, farmer_asking_price_per_unit=price * Decimal('.85'), supplier_payout_price_per_unit=price * Decimal('.80'), buyer_price_per_unit=price, listing_status='live', approved_at=m.now(), last_confirmed_at=m.now(), confirmation_due_at=m.now() + timedelta(hours=48))
                db.add(row); db.flush()
                inv.movement(db, row, 'opening_balance', (Decimal(0), Decimal(0), Decimal(0)), f'testing-opening:{row.id}', 'Sample opening stock for local testing')
                listing_ids[prefix + category] = row.id
        for index, stage in enumerate(['reserved', 'pickup_scheduled', 'in_transit', 'delivered', 'completed', 'cancelled']):
            category = ['broilers', 'local_chicken', 'goats', 'beef', 'chicken_meat', 'goat_meat'][index]
            hold = s.reserve(db, buyer_id, c.Reserve(listing_id=listing_ids['market' + category], quantity=2 if category == 'goats' else 10))
            order = s.checkout(db, buyer_id, c.Checkout(reservation_id=hold.id, delivery_address_id=address.id, preferred_delivery_date=date.today() + timedelta(days=1), payment_method='pay_on_delivery'), f'testing-order-{index}')
            if stage == 'cancelled':
                s.advance(db, order, c.Progress(internal_status='cancelled'))
            elif stage != 'reserved':
                for target in ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']:
                    s.advance(db, order, c.Progress(internal_status=target, expected_collection_date=date.today(), actual_quantity=order.expected_quantity, rejected_quantity=0))
                    if target == stage: break
                if stage == 'completed':
                    # Explicit local fixture of an ops-reconciled cash receipt; no provider call.
                    payment = db.scalar(select(m.Payment).where(m.Payment.order_id == order.id))
                    payment.received_amount = order.total_amount
                    payment.status = order.payment_status = 'paid'
                    payment.paid_at = m.now()
                    db.add(m.PaymentReceipt(payment_id=payment.id, amount=order.total_amount, reference=f'LOCAL-TEST-RECEIPT-{index}'))
                    s.advance(db, order, c.Progress(internal_status='completed'))
        # A delivered order for the test account's own supplier view/payouts.
        other_address = m.Address(user_id=supplier_id, label='Fixture address', recipient_name='Sample buyer', phone='+255700000002', region='Pwani', district_area='Kibaha', address_text='Local testing address')
        db.add(other_address); db.flush()
        for i in range(2):
            hold = s.reserve(db, supplier_id, c.Reserve(listing_id=listing_ids['ownbroilers'], quantity=15))
            order = s.checkout(db, supplier_id, c.Checkout(reservation_id=hold.id, delivery_address_id=other_address.id, preferred_delivery_date=date.today(), payment_method='pay_on_delivery'), f'testing-supplier-order-{i}')
            for stage in ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']:
                s.advance(db, order, c.Progress(internal_status=stage, actual_quantity=15, rejected_quantity=0, expected_collection_date=date.today()))
            if i == 1:
                item = db.scalar(select(m.OrderItem).where(m.OrderItem.order_id == order.id))
                payout = db.scalar(select(m.Settlement).where(m.Settlement.order_item_id == item.id))
                payout.status, payout.paid_at, payout.payment_reference = 'paid', m.now(), 'LOCAL-TEST-SUPPLIER-PAYMENT'
        own = db.get(m.Listing, listing_ids['ownbroilers'])
        before = inv.balances(own)
        own.quantity_sold += 20
        sale = m.StockSale(listing_id=own.id, supplier_id=buyer_id, source='external', quantity=20, unit_price=10000, sold_at=m.now(), note='Sample market sale — local testing')
        db.add(sale)
        inv.movement(db, own, 'sale_external', before, 'testing-external-sale', 'Sample market sale — local testing', buyer_id)
        before = inv.balances(own); own.quantity_total -= 2
        inv.movement(db, own, 'correction', before, 'testing-count-correction', 'Sample correction: opening count was two too high', buyer_id)
        before = inv.balances(own); own.quantity_total += 30
        inv.movement(db, own, 'stock_added', before, 'testing-add-stock', 'Sample receipt of another thirty birds', buyer_id)
        s.reserve(db, supplier_id, c.Reserve(listing_id=own.id, quantity=12))
        for category, status in [('local_chicken', 'needs_confirmation'), ('goats', 'pending_review'), ('cattle', 'paused')]:
            listing = db.get(m.Listing, listing_ids['own' + category]); listing.listing_status = status
            if status == 'needs_confirmation': listing.confirmation_due_at = m.now() - timedelta(hours=1)
            if status == 'pending_review': listing.approved_at = None; listing.buyer_price_per_unit = listing.supplier_payout_price_per_unit = None
        for i, status in enumerate(['submitted', 'sourcing', 'supply_found', 'confirmed']):
            db.add(m.SourcingRequest(buyer_id=buyer_id, category='broilers', unit_type='bird', quantity=100 + i * 50, weight_or_size_requirement='2 kg or more', needed_by_date=(date.today() + timedelta(days=7)).isoformat(), delivery_area='Dar es Salaam', status=status, notes='Sample request for local testing'))
        db.add(m.BusinessOpportunity(buyer_id=buyer_id, business_type='chicken_shop', area='Mikocheni', budget_range='TZS 2–5 million', has_premises=False, wants_stock=True, target_start_date='Within one month', internal_notes='Local testing sample'))
        db.add(m.Idempotency(key='local-testing-scenarios-v2', fingerprint='development-only', resource_id=buyer_id))
    print('Testing account: +255700000001. Use the development OTP shown by the app.')
    print('Includes buyer orders, requests, supplier stock, sales, corrections, history and payouts.')


if __name__ == '__main__':
    run()
