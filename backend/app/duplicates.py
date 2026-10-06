"""Duplicate money entries (build plan M2.6, audit F11).

An idempotency key protects one request from being applied twice. It does
not stop the same real transaction being typed in again with a new key, for
example the same M-Pesa code on a second "Pay supplier". Two guards do that:

1. A transaction reference is claimed once. Its identity is
   (provider, account, reference):
   - provider: the payment method (mpesa, airtel_money, bank_transfer,
     cheque, cash...). App receipts and payouts record no method; their
     provider is unknown ('').
   - account: the money account it went through (M2.3), '' when none.
     Mobile-money codes (M-Pesa, Airtel Money, Mixx by Yas, HaloPesa) are
     unique across the whole network, so for them the account is ignored:
     a code is claimed once per provider whichever wallet it went through
     (finance owner, 6 October).
   - reference: trimmed, spaces removed, upper-cased ("qab 12x " = "QAB12X").
   `money_references` holds one row per claimed reference, with a unique
   index on that triple while the claim is live: the database itself refuses
   a second one. The API also treats an unknown provider or a missing account
   as matching any, since it cannot tell them apart, and names the earlier
   record in its answer.

   Claimed: standalone ledger payments, supplier transfers, supplier refunds,
   customer payments, app receipts, app payout attempts and their refunds
   (M2.7: each attempt claims its own reference; a failed one keeps it). Not claimed: allocations
   (they carry no new money), account fees (a charge carries the code of the
   transaction it was charged on), transfers between Omoterra's own accounts
   (the same code on both sides) and provider-confirmed pay-now payments
   (already unique by `provider_transaction_id`).

   A claim is released only when its record stops counting as money: a
   standalone payment reversed as entered in error, or a customer payment
   whose allocations are all reversed. Supplier transfers, refunds and
   payouts are permanent (rule R3), and so are their claims.

2. With no reference, a possible duplicate (same party, same amount, same
   day, same direction) is refused unless the request says it is a separate
   payment and gives a reason. The override is kept in `duplicate_overrides`
   with who decided and why.

History: migration 043 claims, for each identity, the earliest existing
record only. Older records sharing one are historical duplicates: they keep
counting as before and are listed by the exception report (R6: they are
explained with evidence, never silently removed).
"""
from __future__ import annotations

import re
from collections import defaultdict

from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError

from . import models as m
from .i18n import fail

MR = m.MoneyReference
# Records whose own provider is not recorded. (Payout attempts record their
# method when staff give it; attempts migrated from before M2.7 have none,
# so their provider is unknown and matches any.)
PROVIDERLESS = ('payment_receipts', 'settlements')
# Providers whose transaction codes are unique network-wide.
MOBILE_MONEY = ('mpesa', 'airtel_money', 'mixx_by_yas', 'halopesa')
# Cash book rows that never claim a reference (see the module notes).
UNCLAIMED = ('account_fees', 'payments')

PROVIDER_NAMES = {'cash': 'Cash', 'mpesa': 'M-Pesa', 'airtel_money': 'Airtel Money', 'mixx_by_yas': 'Mixx by Yas',
    'halopesa': 'HaloPesa', 'bank_transfer': 'Bank transfer', 'cheque': 'Cheque', 'other': 'Other', '': 'App'}
RECORD_NAMES = {'ledger_payments': 'payment', 'supplier_payments': 'supplier transfer',
    'transfer_events': 'supplier refund', 'buyer_payments': 'customer payment', 'payment_receipts': 'app order receipt',
    'settlements': 'app payout', 'buyer_order_payments': 'order deposit',
    'settlement_transfers': 'app payout', 'settlement_refunds': 'app payout refund'}


def normalise(reference):
    """The comparable form of a transaction reference: no spaces, upper case."""
    return re.sub(r'\s+', '', reference or '').upper()


def provider_of(source_table, method):
    return '' if source_table in PROVIDERLESS else (method or '')


def account_key_of(provider, account):
    return '' if account is None or provider in MOBILE_MONEY else account.id


def _matches(provider, account_key):
    """Live claims that cannot be told apart from this identity: the same
    provider and account, or one of them unknown."""
    where = [MR.released_at.is_(None)]
    if provider:
        where.append(MR.provider.in_((provider, '')))
    if account_key:
        where.append(MR.account_key.in_((account_key, '')))
    return and_(*where)


def describe(db, source_table, source_id):
    """The earlier record in words, for the error message."""
    from .reporting import CASH
    row = db.execute(select(CASH).where(CASH.c.source_table == source_table, CASH.c.id == source_id)).first()
    name = RECORD_NAMES.get(source_table, source_table)
    if row is None:
        return f'{name} {source_id[:8].upper()}'
    who = f" {'from' if row.flow == 'in' else 'to'} {row.party_name}" if row.party_name else ''
    return f"{name} of TZS {row.amount:,.0f}{who} on {row.paid_on:%d %b %Y} ({source_id[:8].upper()})"


def claim(db, source_table, source_id, method, account, reference, flow, operator=None):
    """Claim a new record's transaction reference, or refuse it naming the
    record that already holds it. No reference: nothing to claim."""
    value = normalise(reference)
    if not value:
        return None
    provider = provider_of(source_table, method)
    account_key = account_key_of(provider, account)
    held = db.scalars(select(MR).where(MR.reference == value, _matches(provider, account_key))
        .order_by(MR.created_at)).all()
    if any(row.source_table == source_table and row.source_id == source_id for row in held):
        return None
    if held:
        earlier = held[0]
        fail('err.reference_already_recorded', 409, reference=value,
            provider=PROVIDER_NAMES.get(provider, provider), record=describe(db, earlier.source_table, earlier.source_id))
    row = MR(provider=provider, account_key=account_key, reference=value, flow=flow, source_table=source_table,
        source_id=source_id, recorded_by=operator.id if operator else None)
    try:
        with db.begin_nested():
            db.add(row)
            db.flush()
    except IntegrityError:
        # Entered at the same moment by someone else: the index refused it.
        fail('err.reference_already_recorded', 409, reference=value,
            provider=PROVIDER_NAMES.get(provider, provider), record='another entry made at the same time')
    return row


def release(db, source_table, source_id, reason=''):
    """The record stopped counting as money: its reference may be used again."""
    for row in db.scalars(select(MR).where(MR.source_table == source_table, MR.source_id == source_id,
            MR.released_at.is_(None))):
        row.released_at, row.release_reason = m.now(), reason[:500]
    db.flush()


def follow(db, from_table, from_id, to_table, to_id):
    """A movement now counted from another record (an old supplier payment
    wrapped in its transfer): its claim goes with it."""
    for row in db.scalars(select(MR).where(MR.source_table == from_table, MR.source_id == from_id)):
        row.source_table, row.source_id = to_table, to_id
    db.flush()


# ---- possible duplicates without a reference -----------------------------------

def possible_duplicate(db, flow, amount, paid_on, supplier_id=None, buyer_profile_id=None, party_name=''):
    """The earliest counted money movement with the same party, amount, day
    and direction, or None. (source_table, id)."""
    from .reporting import CASH, COUNTED
    D = m.LedgerDebt
    query = (select(CASH.c.source_table, CASH.c.id).select_from(CASH).outerjoin(D, D.id == CASH.c.debt_id)
        .where(COUNTED, CASH.c.flow == flow, CASH.c.amount == amount, CASH.c.paid_on == paid_on,
               CASH.c.source_table.not_in(UNCLAIMED)))
    if supplier_id:
        query = query.where(CASH.c.supplier_id == supplier_id)
    elif buyer_profile_id:
        query = query.where(D.buyer_profile_id == buyer_profile_id)
    else:
        query = query.where(CASH.c.supplier_id.is_(None), D.buyer_profile_id.is_(None),
            func.lower(CASH.c.party_name) == (party_name or '').casefold())
    return db.execute(query.order_by(CASH.c.created_at).limit(1)).first()


def check_possible(db, data, flow, amount, paid_on, **party):
    """Refuse a possible duplicate entered without a reference, unless the
    request says it is a separate payment and why. Returns the earlier
    record when overridden, so `record_override` can keep the decision."""
    if normalise(getattr(data, 'reference', '')):
        return None
    earlier = possible_duplicate(db, flow, amount, paid_on, **party)
    if earlier is None:
        return None
    if not getattr(data, 'duplicate_override', False):
        fail('err.possible_duplicate_payment', 409, record=describe(db, earlier.source_table, earlier.id))
    if len((getattr(data, 'duplicate_reason', '') or '').strip()) < 3:
        fail('err.duplicate_override_reason', 422)
    return earlier


def record_override(db, earlier, source_table, source_id, data, flow, amount, paid_on, operator):
    if earlier is None:
        return None
    row = m.DuplicateOverride(source_table=source_table, source_id=source_id, earlier_table=earlier.source_table,
        earlier_id=earlier.id, flow=flow, amount=amount, paid_on=paid_on, reason=data.duplicate_reason.strip(),
        overridden_by=operator.id if operator else None)
    db.add(row)
    db.flush()
    return row


# ---- history (exception report) ---------------------------------------------------

def historical_duplicates(db):
    """Counted money movements that share a transaction identity, as the
    claims define it: each group is one reference entered more than once."""
    from .reporting import CASH, COUNTED
    AA = m.AccountAssignment
    rows = db.execute(select(CASH.c.source_table, CASH.c.id, CASH.c.flow, CASH.c.paid_on, CASH.c.amount,
            CASH.c.method, CASH.c.reference, CASH.c.party_name, CASH.c.created_at, AA.account_id)
        .select_from(CASH).outerjoin(AA, and_(AA.source_table == CASH.c.source_table, AA.source_id == CASH.c.id))
        .where(COUNTED, CASH.c.reference != '', CASH.c.source_table.not_in(UNCLAIMED))
        .order_by(CASH.c.created_at)).all()
    by_reference = defaultdict(list)
    for row in rows:
        value = normalise(row.reference)
        if value:
            by_reference[value].append(row)
    groups = []
    for value, entries in by_reference.items():
        if len(entries) < 2:
            continue
        # Group entries that cannot be told apart (same provider and account,
        # or one of them unknown), keeping the earliest first.
        pending = list(entries)
        while pending:
            first, rest = pending[0], pending[1:]
            same = [first] + [r for r in rest if _alike(first, r)]
            pending = [r for r in rest if r not in same]
            if len(same) > 1:
                groups.append({'reference': value, 'provider': provider_of(first.source_table, first.method),
                    'records': [{'source_table': r.source_table, 'id': r.id, 'flow': r.flow, 'paid_on': r.paid_on,
                        'amount': r.amount, 'method': r.method, 'account_id': r.account_id or '',
                        'party': r.party_name, 'reference': r.reference} for r in same]})
    return groups


def _alike(a, b):
    pa, pb = provider_of(a.source_table, a.method), provider_of(b.source_table, b.method)
    ka = '' if pa in MOBILE_MONEY else a.account_id or ''
    kb = '' if pb in MOBILE_MONEY else b.account_id or ''
    return (not pa or not pb or pa == pb) and (not ka or not kb or ka == kb)
