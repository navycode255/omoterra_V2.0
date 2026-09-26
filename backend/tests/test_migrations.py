import os
import shutil
import threading
import uuid
import pytest
from sqlalchemy import create_engine, inspect, text
from app import migrations
from app.db import Base


@pytest.fixture
def fresh_engine():
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_migrate_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    yield engine
    engine.dispose()
    with admin.begin() as db:
        db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    admin.dispose()


def names(status):
    return {name: how for name, how in status}


def test_fresh_database_gets_every_migration_in_order(fresh_engine):
    applied = migrations.apply(fresh_engine)
    assert applied == [path.name for path in migrations.files()]
    assert '003a_repair_partial_managed_demand.sql' not in applied
    assert set(names(migrations.status(fresh_engine)).values()) == {'applied'}


def test_migrated_database_matches_the_models(fresh_engine):
    """The schema the migrations build must have every table and column the
    code uses; a gap here is the drift that took production down before."""
    migrations.apply(fresh_engine)
    actual = inspect(fresh_engine)
    missing = []
    for table in Base.metadata.sorted_tables:
        if not actual.has_table(table.name):
            missing.append(table.name)
            continue
        columns = {column['name'] for column in actual.get_columns(table.name)}
        missing += [f'{table.name}.{column.name}' for column in table.columns if column.name not in columns]
    assert missing == []


def test_second_start_applies_nothing(fresh_engine):
    migrations.apply(fresh_engine)
    assert migrations.apply(fresh_engine) == []


def test_hand_migrated_database_is_adopted_without_rerunning(fresh_engine):
    # A database migrated by hand up to 004, with no record of it.
    for path in migrations.files()[:4]:
        with fresh_engine.begin() as db:
            migrations.run_sql(db, migrations._TRANSACTION_LINE.sub('', path.read_text()))
    applied = migrations.apply(fresh_engine)
    status = names(migrations.status(fresh_engine))
    assert [status[f] for f in ('001_initial.sql', '002_inventory_history.sql',
                                '003_managed_demand.sql', '004_supplier_onboarding.sql')] == ['detected'] * 4
    assert applied == [path.name for path in migrations.files()[4:]]


def test_failed_migration_rolls_back_and_stops(fresh_engine, tmp_path, monkeypatch):
    for path in migrations.files():
        shutil.copy(path, tmp_path / path.name)
    (tmp_path / '999_broken.sql').write_text(
        'BEGIN;\nCREATE TABLE half_done (id INT);\nSELECT no_such_function();\nCOMMIT;\n')
    monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
    with pytest.raises(migrations.MigrationError, match='999_broken.sql'):
        migrations.apply(fresh_engine)
    with fresh_engine.connect() as db:
        assert db.execute(text("SELECT to_regclass('half_done')")).scalar() is None
    status = names(migrations.status(fresh_engine))
    assert status['999_broken.sql'] == 'pending'
    assert status['009_operator_accounts.sql'] == 'applied'


def test_two_servers_starting_together_apply_each_file_once(fresh_engine):
    results, errors = [], []

    def start():
        try:
            results.append(migrations.apply(fresh_engine))
        except Exception as exc:  # noqa: BLE001
            errors.append(exc)

    threads = [threading.Thread(target=start) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert errors == []
    assert sorted(len(r) for r in results) == [0, len(migrations.files())]


def test_percent_signs_in_a_migration_are_just_text(fresh_engine, tmp_path, monkeypatch):
    (tmp_path / '001_percent.sql').write_text(
        "BEGIN;\nCREATE TABLE notes (v text);\nINSERT INTO notes VALUES ('50% off');\n"
        "UPDATE notes SET v = v || '!' WHERE v LIKE '50%';\nCOMMIT;\n")
    monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
    assert migrations.apply(fresh_engine) == ['001_percent.sql']
    with fresh_engine.connect() as db:
        assert db.execute(text('SELECT v FROM notes')).scalar() == '50% off!'


def test_media_references_are_backfilled_from_existing_records(fresh_engine, tmp_path, monkeypatch):
    # A database at 018 with photos already saved on stock, then 019 arrives.
    files = migrations.files()
    for path in files:
        shutil.copy(path, tmp_path / path.name)
    later = [path for path in files if path.name >= '019']
    for path in later:
        (tmp_path / path.name).unlink()
    monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
    migrations.apply(fresh_engine)
    photo, video, gone = (str(uuid.uuid4()) for _ in range(3))
    from app import models as m
    # Core inserts through the model tables, so column defaults are filled in.
    with fresh_engine.begin() as db:
        # Plain SQL: the model has columns later migrations add (e.g. 020's PIN).
        db.execute(text("""INSERT INTO users (id, phone, name, region, language, roles, deleted, created_at)
            VALUES ('u1', '+255700000001', '', '', 'en', '["supplier"]', false, now())"""))
        for id in (photo, video):
            db.execute(m.MediaAsset.__table__.insert().values(id=id, owner_id='u1', storage_name=id))
        db.execute(m.Listing.__table__.insert().values(id='l1', supplier_id='u1', category='broilers', unit_type='bird',
            specs={}, region='Pwani', quantity_total=1, farmer_asking_price_per_unit=1,
            photos=[f'/media/{photo}', f'/media/{gone}'], video=f'/media/{video}'))
    for path in later:
        shutil.copy(path, tmp_path / path.name)
    migrations.apply(fresh_engine)
    with fresh_engine.connect() as db:
        rows = set(db.execute(text('SELECT media_id, owner_table, owner_id FROM media_references')))
    assert rows == {(photo, 'listings', 'l1'), (video, 'listings', 'l1')}
