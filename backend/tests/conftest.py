import os
import uuid

# Tests build their schema from the models; never touch a real database's
# migrations when the app starts under TestClient.
os.environ['OMOTERRA_AUTO_MIGRATE'] = 'false'
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.db import Base, database
from app.main import app
from app import models as m
from app.config import settings
from fastapi.testclient import TestClient

# CI sets OMOTERRA_REQUIRE_DB=1: a missing database is then an error instead
# of a quiet skip, and any skipped test fails the run. Locally, without a
# database, the database tests still skip.
REQUIRE_DB = os.environ.get('OMOTERRA_REQUIRE_DB', '').strip().lower() in ('1', 'true', 'yes')
_skipped = []


def pytest_configure(config):
    if REQUIRE_DB and not os.environ.get('OMOTERRA_TEST_DATABASE_URL'):
        raise pytest.UsageError('OMOTERRA_REQUIRE_DB is set but OMOTERRA_TEST_DATABASE_URL is not')


def pytest_runtest_logreport(report):
    if report.skipped:
        _skipped.append(report.nodeid)


# A whole module skipped while importing (pytest.importorskip) is reported
# at collection, not as a test run.
def pytest_collectreport(report):
    if report.skipped:
        _skipped.append(report.nodeid)


def pytest_sessionfinish(session, exitstatus):
    if REQUIRE_DB and _skipped and session.exitstatus == 0:
        session.exitstatus = pytest.ExitCode.TESTS_FAILED


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    if REQUIRE_DB and _skipped:
        terminalreporter.section('OMOTERRA_REQUIRE_DB')
        terminalreporter.write_line(f'{len(_skipped)} test(s) skipped; every test must run when OMOTERRA_REQUIRE_DB=1:', red=True)
        for nodeid in _skipped[:50]:
            terminalreporter.write_line(f'  {nodeid}')


@pytest.fixture(scope='session')
def engine():
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    engine = create_engine(url)
    # Dedicated schema keeps other applications and tables untouched.
    schema = 'omoterra_tests_' + uuid.uuid4().hex
    with engine.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine.dispose()
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    Base.metadata.create_all(engine)
    from app.migrate_inventory import install_history_guards
    install_history_guards(engine)
    yield engine
    with engine.begin() as db:
        db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    engine.dispose()


@pytest.fixture
def sessions(engine):
    # One statement for every table: far faster than a TRUNCATE per table.
    tables = ', '.join(f'"{table.name}"' for table in Base.metadata.sorted_tables)
    with engine.begin() as connection:
        connection.execute(text(f'TRUNCATE {tables} CASCADE'))
    return sessionmaker(engine, expire_on_commit=False)


@pytest.fixture
def seeded(sessions):
    from datetime import timedelta
    with sessions.begin() as db:
        buyer = m.User(phone='+255712345678', roles=['buyer'], name='Buyer Test', region='Dar')
        other = m.User(phone='+255712345679', roles=['buyer'], name='Other Buyer', region='Dar')
        supplier = m.User(phone='+255712345680', roles=['supplier'], name='Private Supplier', region='Pwani')
        db.add_all([buyer, other, supplier]); db.flush()
        db.add(m.SupplierProfile(user_id=supplier.id, legal_name='Secret legal name', internal_pickup_address='Secret farm address', public_alias='Green Pastures', alias_approved=True, status='approved', categories=['broilers'], district='Kibaha', production_profile={'broilers': {'capacity': '2000', 'unit': 'bird', 'frequency': 'every 6 weeks'}}, production_frequency='every 6 weeks'))
        listing = m.Listing(supplier_id=supplier.id, category='broilers', unit_type='bird', specs={'avg_weight_kg': '2', 'breed_type': 'Broiler', 'age_weeks': '6', 'live_or_dressed': 'live', 'ready_date': '2027-01-01'}, region='Pwani', quantity_total=10, farmer_asking_price_per_unit=10000, supplier_payout_price_per_unit=9000, buyer_price_per_unit=12000, listing_status='live', last_confirmed_at=m.now(), confirmation_due_at=m.now() + timedelta(hours=48), approved_at=m.now())
        address = m.Address(user_id=buyer.id, label='Home', recipient_name='Private Buyer', phone=buyer.phone, region='Dar', district_area='Kinondoni', address_text='Secret buyer address')
        db.add_all([listing, address]); db.flush()
        return {'buyer': buyer.id, 'other': other.id, 'supplier': supplier.id, 'listing': listing.id, 'address': address.id}


@pytest.fixture
def client(sessions, seeded):
    from datetime import timedelta
    from app.auth import digest
    def override():
        with sessions() as db:
            with db.begin():
                yield db
    app.dependency_overrides[database] = override
    settings().ops_token = 'test-operator-secret'
    with sessions.begin() as db:
        for role in ['buyer', 'supplier', 'other']:
            db.add(m.AuthSession(user_id=seeded[role], token_hash=digest(role), expires_at=m.now() + timedelta(days=1)))
        # Operators signed in to the dashboard: send X-Operator-Session
        # 'ops-admin' or 'ops-staff' alongside the service token.
        for role in ['admin', 'staff']:
            operator = m.Operator(phone=f"+25571000000{'1' if role == 'admin' else '2'}", name=f'Test {role.title()}', role=role)
            db.add(operator); db.flush()
            seeded[f'operator_{role}'] = operator.id
            db.add(m.OperatorSession(operator_id=operator.id, token_hash=digest(f'ops-{role}'), expires_at=m.now() + timedelta(days=1)))
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def second_admin(client, sessions, seeded):
    """Another admin signed in to the dashboard (decision D9: approvals come
    from a second admin). Send X-Operator-Session 'ops-admin-2'."""
    from datetime import timedelta
    from app.auth import digest
    with sessions.begin() as db:
        operator = m.Operator(phone='+255710000003', name='Second Admin', role='admin')
        db.add(operator); db.flush()
        db.add(m.OperatorSession(operator_id=operator.id, token_hash=digest('ops-admin-2'),
            expires_at=m.now() + timedelta(days=1)))
        seeded['operator_admin_2'] = operator.id
    return {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin-2'}
