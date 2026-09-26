from datetime import timedelta
import pytest
from app import models as m, search
from app.contracts import UNITS

CHICKEN = {'broilers', 'local_chicken', 'layers', 'chicken_meat'}


# --- Words (no database) ---------------------------------------------------

@pytest.mark.parametrize('word, expected', [
    ('kuku', CHICKEN),
    ('chicken', CHICKEN),
    ('Kuku', CHICKEN),
    ('mbuzi', {'goats', 'goat_meat'}),
    ('goat', {'goats', 'goat_meat'}),
    ("ng'ombe", {'cattle', 'beef'}),
    ('ng’ombe', {'cattle', 'beef'}),
    ('ngombe', {'cattle', 'beef'}),
    ('cattle', {'cattle', 'beef'}),
    ('mayai', {'eggs'}),
    ('eggs', {'eggs'}),
    ('nyama', {'chicken_meat', 'beef', 'goat_meat'}),
    ('meat', {'chicken_meat', 'beef', 'goat_meat'}),
    ('beef', {'beef'}),
    ('broilers', {'broilers'}),
    ('kienyeji', {'local_chicken'}),
    ('layers', {'layers'}),
    ('local chicken', {'local_chicken'}),
    ('goat meat', {'goat_meat'}),
    ('chicken meat', {'chicken_meat'}),
])
def test_each_word_means_its_categories(word, expected):
    assert search.categories_for(word) == expected


def test_every_synonym_names_real_categories():
    for word, categories in search.SYNONYMS.items():
        assert categories and categories <= search.CATEGORIES, word
    assert search.CATEGORIES == set(UNITS)


def test_partly_typed_words_match():
    assert search.categories_for('kuk') == CHICKEN
    assert search.categories_for('mbu') == {'goats', 'goat_meat'}
    assert search.categories_for('ma') == set()  # too short to guess


def test_regions_and_breeds_are_not_categories():
    for word in ('pwani', 'kuroiler', 'arusha', 'dar'):
        assert search.categories_for(word) == set()


def test_phrases_stay_together_and_joining_words_drop():
    assert search.terms('nyama ya mbuzi') == [('nyama ya mbuzi', {'goat_meat'})]
    assert search.terms('Kuku  Pwani') == [('kuku', CHICKEN), ('pwani', frozenset())]
    assert search.terms('local chicken') == [('local chicken', {'local_chicken'})]
    assert search.terms('  ') == []


# --- Marketplace search (PostgreSQL) ----------------------------------------

REGIONS = ['Pwani', 'Dar es Salaam', 'Arusha', 'Mbeya', 'Dodoma']
BIRD_BREEDS = {'broilers': 'Cobb 500', 'local_chicken': 'Kuroiler', 'layers': 'Isa Brown'}


def specs(category, i):
    unit = UNITS[category]
    if unit == 'bird':
        return {'avg_weight_kg': str(1 + i % 3), 'breed_type': BIRD_BREEDS[category], 'age_weeks': '6',
                'live_or_dressed': 'live' if i % 2 else 'dressed', 'ready_date': f'2027-01-{1 + i % 28:02d}'}
    if unit == 'animal':
        low = 20 + i % 5 * 10 if category == 'goats' else 200 + i % 5 * 50
        return {'weight_range': f'{low}-{low + 10} kg', 'breed': 'Boer' if category == 'goats' else 'Zebu',
                'sex': 'male', 'approx_age': '1 year', 'ready_date': f'2027-02-{1 + i % 28:02d}'}
    if unit == 'kg':
        return {'cut_type': 'Whole', 'chilled_or_frozen': 'chilled' if i % 2 else 'frozen', 'slaughter_date': f'2027-01-{1 + i % 28:02d}'}
    return {'tray_size': '30', 'egg_size': 'large', 'ready_date': f'2027-01-{1 + i % 28:02d}'}


def listing(supplier, category, region, i, **values):
    return m.Listing(supplier_id=supplier, category=category, unit_type=UNITS[category], specs=specs(category, i), region=region,
                     quantity_total=10, farmer_asking_price_per_unit=1000 + i, supplier_payout_price_per_unit=900,
                     buyer_price_per_unit=1000 + i * 100, last_confirmed_at=m.now(), approved_at=m.now(),
                     created_at=m.now() - timedelta(minutes=i), **{'listing_status': 'live',
                     'confirmation_due_at': m.now() + timedelta(hours=48), **values})


@pytest.fixture
def market(sessions, seeded):
    """216 live listings across every category and five regions, plus stock a
    buyer must never see. Returns the expected id sets."""
    categories = sorted(UNITS)
    live = {}
    with sessions.begin() as db:
        # The fixture's own listing is taken off sale so counts are exact.
        db.get(m.Listing, seeded['listing']).listing_status = 'paused'
        hidden_supplier = m.User(phone='+255712345681', roles=['supplier'], name='Suspended', region='Pwani')
        db.add(hidden_supplier); db.flush()
        db.add(m.SupplierProfile(user_id=hidden_supplier.id, legal_name='Suspended', internal_pickup_address='Farm', status='suspended', categories=['local_chicken']))
        for i in range(216):
            row = listing(seeded['supplier'], categories[i % len(categories)], REGIONS[i % len(REGIONS)], i)
            db.add(row); db.flush()
            live[row.id] = row
        hidden = [
            listing(seeded['supplier'], 'local_chicken', 'Pwani', 300, listing_status='paused'),
            listing(seeded['supplier'], 'local_chicken', 'Pwani', 301, confirmation_due_at=m.now() - timedelta(hours=1)),
            listing(seeded['supplier'], 'local_chicken', 'Pwani', 302, listing_status='pending_review'),
            listing(hidden_supplier.id, 'local_chicken', 'Pwani', 303),
        ]
        db.add_all(hidden); db.flush()
        return {'live': {id: (r.category, r.region, dict(r.specs), r.buyer_price_per_unit) for id, r in live.items()},
                'hidden': {r.id for r in hidden} | {seeded['listing']}}


def headers():
    return {'Authorization': 'Bearer buyer'}


def everything(client, **params):
    """Walks every page and returns the ids in order."""
    ids, cursor, pages = [], None, 0
    while True:
        query = {'page_size': 50, **params, **({'cursor': cursor} if cursor else {})}
        response = client.get('/api/v1/listings', params=query, headers=headers())
        assert response.status_code == 200, response.text
        body = response.json()
        ids += [item['id'] for item in body['items']]
        cursor, pages = body['next_cursor'], pages + 1
        if not cursor:
            return ids, pages


def expect(market, test):
    return {id for id, (category, region, specs_, price) in market['live'].items() if test(category, region, specs_, price)}


def test_kuku_finds_all_chicken_across_pages(client, market):
    ids, pages = everything(client, q='kuku')
    assert set(ids) == expect(market, lambda c, *_: c in CHICKEN)
    assert len(ids) == len(set(ids)) and pages >= 2
    assert not set(ids) & market['hidden']


def test_region_search(client, market):
    ids, _ = everything(client, q='Pwani')
    assert set(ids) == expect(market, lambda c, r, *_: r == 'Pwani')


def test_breed_search(client, market):
    ids, _ = everything(client, q='kuroiler')
    assert set(ids) == expect(market, lambda c, r, sp, p: sp.get('breed_type') == 'Kuroiler')
    assert ids and not set(ids) & market['hidden']


def test_every_word_must_match(client, market):
    ids, _ = everything(client, q="ng'ombe arusha")
    assert set(ids) == expect(market, lambda c, r, *_: c in ('cattle', 'beef') and r == 'Arusha')
    ids, _ = everything(client, q='nyama ya mbuzi')
    assert set(ids) == expect(market, lambda c, *_: c == 'goat_meat')
    assert everything(client, q='kuku zzzz')[0] == []


def test_newest_first_without_gaps(client, market):
    ids, pages = everything(client)
    assert len(ids) == 216 and pages == 5
    # Created a minute apart in this order, newest first.
    assert ids == list(market['live'])


def test_filters_apply_on_the_server(client, market):
    ids, _ = everything(client, region='dar', max_price='5000')
    assert set(ids) == expect(market, lambda c, r, sp, p: r == 'Dar es Salaam' and p <= 5000)
    ids, _ = everything(client, q='kuku', condition='live')
    assert set(ids) == expect(market, lambda c, r, sp, p: c in CHICKEN and sp.get('live_or_dressed') == 'live')
    ids, _ = everything(client, condition='frozen')
    assert set(ids) == expect(market, lambda c, r, sp, p: sp.get('chilled_or_frozen') == 'frozen')
    ids, _ = everything(client, ready_by='2027-01-05')
    assert set(ids) == expect(market, lambda c, r, sp, p: (sp.get('ready_date') or sp.get('slaughter_date')) <= '2027-01-05')
    # Weight ranges overlap: goats 20-30 kg .. 60-70 kg; cattle 200-210 .. 400-410.
    ids, _ = everything(client, min_weight='45', max_weight='55')
    assert set(ids) == expect(market, lambda c, r, sp, p: c == 'goats' and sp['weight_range'] in ('40-50 kg', '50-60 kg'))
    ids, _ = everything(client, q='kuku', min_weight='3')
    assert set(ids) == expect(market, lambda c, r, sp, p: c in CHICKEN and float(sp.get('avg_weight_kg', 0)) >= 3)


def test_filters_and_paging_together(client, market):
    ids, pages = everything(client, q='kuku', region='Pwani', page_size=5)
    assert set(ids) == expect(market, lambda c, r, *_: c in CHICKEN and r == 'Pwani')
    assert pages >= 2


def test_legacy_list_without_paging(client, market):
    response = client.get('/api/v1/listings', params={'q': 'mayai'}, headers=headers())
    assert isinstance(response.json(), list) and len(response.json()) == 24
    assert {row['category'] for row in response.json()} == {'eggs'}


def test_bad_cursor_is_refused(client, market):
    response = client.get('/api/v1/listings', params={'page_size': 10, 'cursor': 'not-a-cursor'}, headers=headers())
    assert response.status_code == 422


def test_wildcards_are_literal(client, market):
    assert everything(client, region='%')[0] == []
    assert everything(client, region='_')[0] == []
    # Punctuation is not a search word; the whole market shows.
    assert len(everything(client, q='%')[0]) == 216
