from datetime import date
from decimal import Decimal

from app.supplier_payment_sms import message


def test_supplier_receipt_message_english_and_swahili():
    paid_on = date(2026, 9, 29)
    english = message(Decimal('18500'), paid_on, 'mpesa', 'MPESA-01', 'en', True)
    swahili = message(Decimal('7000'), paid_on, 'bank_transfer', 'BANK-01', 'sw', True)

    assert english == (
        'Omoterra payment receipt: TZS 18,500 was paid to your account on 2026-09-29 via M-Pesa. '
        'Reference: MPESA-01. Thank you for supplying Omoterra.'
    )
    assert swahili == (
        'Risiti ya malipo ya Omoterra: TZS 7,000 imelipwa kwenye akaunti yako tarehe 2026-09-29 '
        'kupitia uhamisho wa benki. Kumbukumbu: BANK-01. Asante kwa kusambaza bidhaa kwa Omoterra.'
    )


def test_supplier_receipt_can_omit_thank_you_and_reference():
    text = message(Decimal('9000'), date(2026, 9, 29), 'cash', '', 'sw', False)
    assert text == (
        'Risiti ya malipo ya Omoterra: TZS 9,000 imelipwa kwenye akaunti yako tarehe 2026-09-29 kupitia taslimu.'
    )
