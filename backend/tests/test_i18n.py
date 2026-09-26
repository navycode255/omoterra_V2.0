"""Server messages in Kiswahili: notifications by the recipient's language,
errors by the signed-in user's language or Accept-Language."""
import ast
import re
import string
from pathlib import Path
from typing import get_args

from app import i18n, models as m
from app.contracts import Category
from test_commerce import headers, order
from test_notifications import inbox, pushes, register  # noqa: F401  (fixture)

APP = Path(__file__).resolve().parents[1] / 'app'
KEY = re.compile(r"""['"]((?:err|notify|category|role)\.[a-z0-9_.]+)['"]""")


def set_language(sessions, user_id, lang):
    with sessions.begin() as db:
        db.get(m.User, user_id).language = lang


def test_every_english_key_has_swahili_with_same_placeholders():
    assert set(i18n.EN) == set(i18n.SW)
    fields = lambda text: {f for _, f, _, _ in string.Formatter().parse(text) if f}
    for key, text in i18n.EN.items():
        assert i18n.SW[key].strip(), key
        assert fields(text) == fields(i18n.SW[key]), key


def test_every_category_and_role_is_in_the_catalogue():
    for value in get_args(Category):
        assert f'category.{value}' in i18n.EN
    for role in ('buyer', 'supplier'):
        assert f'role.{role}' in i18n.EN


def calls(name):
    """Every call to `name` (or `x.name`) in app/, with its file."""
    for path in APP.glob('*.py'):
        for node in ast.walk(ast.parse(path.read_text())):
            if isinstance(node, ast.Call):
                func = node.func
                if (isinstance(func, ast.Name) and func.id == name) or (isinstance(func, ast.Attribute) and func.attr == name):
                    yield path.name, node


def test_every_fail_and_notify_uses_a_catalogue_key():
    fails = [(f, n) for name in ('fail', 'error') for f, n in calls(name) if f != 'i18n.py']
    assert len(fails) > 150
    for file, node in fails:
        # A literal key, or `'a' if … else 'b'` of literal keys.
        keys = [node.args[0]] if not isinstance(node.args[0], ast.IfExp) else [node.args[0].body, node.args[0].orelse]
        for key in keys:
            assert isinstance(key, ast.Constant) and key.value in i18n.EN, (file, node.lineno)
    notifies = [(f, n) for f, n in calls('notify') if f != 'notifications.py']
    assert len(notifies) > 10
    for file, node in notifies:
        # The message is M('notify.…') or a name bound to one; both are
        # covered by the literal-key scan below, so only reject raw text.
        assert not isinstance(node.args[4], (ast.Constant, ast.JoinedStr)), (file, node.lineno)
    for file, node in calls('ValueError'):
        if file == 'contracts.py':
            assert node.args and isinstance(node.args[0], ast.Call) and node.args[0].func.id == 'M', (file, node.lineno)
    # Any quoted key anywhere in the app must exist (notification keys by
    # their title and body).
    for path in APP.glob('*.py'):
        if path.name == 'i18n.py':
            continue
        for key in KEY.findall(path.read_text()):
            if key.startswith('notify.') and key not in i18n.EN:
                assert f'{key}.title' in i18n.EN and f'{key}.body' in i18n.EN, (path.name, key)
            elif not key.startswith('notify.'):
                assert key in i18n.EN, (path.name, key)
    assert not list(calls('HTTPException'))[1:], 'raise errors through i18n.fail'


def test_unknown_language_or_key_falls_back():
    assert i18n.t('err.order_not_found', 'fr') == 'Order not found.'
    assert i18n.t('no.such.key', 'sw') == 'no.such.key'
    assert i18n.parse('sw-TZ,en;q=0.8') == 'sw' and i18n.parse('fr, en-GB') == 'en' and i18n.parse('') is None
    assert i18n.M('err.order_not_found') == 'Order not found.'


def test_swahili_supplier_gets_order_notification_in_swahili(client, sessions, seeded, pushes):
    set_language(sessions, seeded['supplier'], 'sw')
    register(client, 'supplier')
    order(sessions, seeded)
    note = inbox(client, 'supplier')['items'][0]
    assert note['title'] == 'Oda mpya ya bidhaa yako'
    assert note['body'] == 'Mnunuzi ameagiza kuku wa nyama (kiasi 4). Omoterra itapanga kuja kuchukua mzigo.'
    assert (pushes.sent[0]['title'], pushes.sent[0]['body']) == (note['title'], note['body'])
    # The English buyer is unaffected.
    set_language(sessions, seeded['buyer'], 'en')
    id = order(sessions, seeded, 1, 'checkout-key-0002')
    moved = client.post(f'/api/v1/ops/orders/{id}/progress', headers={
        'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin', 'Idempotency-Key': 'progress-sw-01'},
        json={'internal_status': 'pickup_scheduled', 'expected_collection_date': '2027-01-05'})
    assert moved.status_code == 200, moved.text
    assert inbox(client, 'buyer')['items'][0]['title'] == 'Order being prepared'
    collect = [n for n in inbox(client, 'supplier')['items'] if n['kind'] == 'collection_scheduled'][0]
    assert collect['body'] == 'Omoterra itakuja kuchukua kuku wa nyama (kiasi 1) tarehe 2027-01-05.'


def test_error_follows_user_language_then_accept_language(client, sessions, seeded):
    missing = '/api/v1/orders/does-not-exist'
    # The saved language wins over the header...
    english = client.get(missing, headers={**headers('buyer'), 'Accept-Language': 'sw'})
    assert english.status_code == 404 and english.json() == {'detail': 'This record is unavailable.'}
    set_language(sessions, seeded['buyer'], 'sw')
    swahili = client.get(missing, headers=headers('buyer'))
    assert swahili.status_code == 404 and swahili.json() == {'detail': 'Rekodi hii haipatikani.'}
    # ...and signed out, the header chooses.
    expired = client.get('/api/v1/me', headers={'Authorization': 'Bearer nope', 'Accept-Language': 'sw-TZ,en;q=0.5'})
    assert expired.status_code == 401 and expired.json() == {'detail': 'Muda wako wa kuingia umeisha. Ingia tena.'}
    assert client.get('/api/v1/me', headers={'Authorization': 'Bearer nope'}).json() == {
        'detail': 'Your session has expired. Sign in again.'}


def test_swahili_errors_with_values_and_business_rules(client, sessions, seeded):
    set_language(sessions, seeded['supplier'], 'sw')
    set_language(sessions, seeded['buyer'], 'sw')
    reserve = lambda role, quantity, key: client.post('/api/v1/reservations', headers=headers(role, key),
        json={'listing_id': seeded['listing'], 'quantity': quantity})
    # The supplier has no buyer role; the role name is translated too.
    response = reserve('supplier', '1', 'reserve-sw-0001')
    assert response.status_code == 403 and response.json() == {'detail': 'Washa huduma ya mnunuzi kwenye Akaunti kwanza.'}
    response = reserve('buyer', '50', 'reserve-sw-0002')
    assert response.status_code == 409, response.text
    assert response.json() == {'detail': i18n.SW['err.requested_quantity_no_longer_available']}


def test_validation_message_in_swahili(client, sessions, seeded):
    body = {'name': 'Mnunuzi', 'region': 'Dar', 'roles': ['buyer']}
    english = client.put('/api/v1/me', headers=headers('buyer'), json=body)
    assert english.status_code == 422 and english.json()['detail'][0]['msg'] == 'Value error, Choose a buyer type'
    set_language(sessions, seeded['buyer'], 'sw')
    swahili = client.put('/api/v1/me', headers=headers('buyer'), json=body)
    assert swahili.status_code == 422 and swahili.json()['detail'][0]['msg'] == 'Chagua aina ya mnunuzi'


def test_staff_paths_stay_english(client):
    response = client.get('/api/v1/ops/orders/missing', headers={
        'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin', 'Accept-Language': 'sw'})
    assert response.status_code == 404 and response.json()['detail'] == 'Order not found.'
