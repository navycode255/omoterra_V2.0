"""Buyer search words: what a typed word means in terms of stock categories.

One table, in English and Swahili, so "kuku", "chicken" and "broilers" all
find the same stock. `GET /listings` matches every word a buyer types against
the categories below, the listing's region, and its breed or cut; a listing is
shown when each word matches one of those.
"""
from __future__ import annotations

import base64
import re
from datetime import datetime
from typing import get_args

from .i18n import fail
from sqlalchemy import Numeric, cast, func, or_, tuple_

from . import models as m
from .contracts import Category

CATEGORIES = frozenset(get_args(Category))
BIRDS = frozenset({'broilers', 'local_chicken', 'layers'})
CHICKEN = BIRDS | {'chicken_meat'}
MEAT = frozenset({'chicken_meat', 'beef', 'goat_meat'})

# Whole words (after normalising: lower case, no apostrophes) and the
# categories they mean. Multi-word phrases are looked up before single words.
SYNONYMS: dict[str, frozenset[str]] = {
    # Chicken
    'kuku': CHICKEN, 'chicken': CHICKEN, 'chickens': CHICKEN, 'poultry': CHICKEN,
    'broiler': frozenset({'broilers'}), 'broilers': frozenset({'broilers'}),
    'kuku wa nyama': frozenset({'broilers'}),
    'local chicken': frozenset({'local_chicken'}), 'kienyeji': frozenset({'local_chicken'}),
    'kuku wa kienyeji': frozenset({'local_chicken'}), 'chotara': frozenset({'local_chicken'}),
    'layer': frozenset({'layers'}), 'layers': frozenset({'layers'}),
    'kuku wa mayai': frozenset({'layers'}), 'chicken meat': frozenset({'chicken_meat'}),
    'nyama ya kuku': frozenset({'chicken_meat'}),
    # Goats
    'mbuzi': frozenset({'goats', 'goat_meat'}), 'goat': frozenset({'goats', 'goat_meat'}),
    'goats': frozenset({'goats', 'goat_meat'}),
    'goat meat': frozenset({'goat_meat'}), 'nyama ya mbuzi': frozenset({'goat_meat'}),
    'mutton': frozenset({'goat_meat'}),
    # Cattle
    'ngombe': frozenset({'cattle', 'beef'}), 'cattle': frozenset({'cattle', 'beef'}),
    'cow': frozenset({'cattle', 'beef'}), 'cows': frozenset({'cattle', 'beef'}),
    'bull': frozenset({'cattle'}), 'fahali': frozenset({'cattle'}),
    'beef': frozenset({'beef'}), 'nyama ya ngombe': frozenset({'beef'}),
    # Eggs
    'mayai': frozenset({'eggs'}), 'yai': frozenset({'eggs'}),
    'egg': frozenset({'eggs'}), 'eggs': frozenset({'eggs'}),
    # Meat and livestock in general
    'nyama': MEAT, 'meat': MEAT,
    'mifugo': frozenset({'goats', 'cattle'}) | BIRDS, 'livestock': frozenset({'goats', 'cattle'}) | BIRDS,
}

# Joining words that say nothing about the stock ("nyama ya mbuzi").
STOPWORDS = frozenset({'ya', 'wa', 'la', 'za', 'na', 'cha', 'kwa', 'and', 'of', 'the', 'for', 'in'})

_APOSTROPHES = re.compile(r"[’'`´]")
_SEPARATORS = re.compile(r'[^\w]+')


def normalise(text: str) -> str:
    """Lower case, apostrophes dropped ("ng'ombe" → "ngombe"), punctuation to spaces."""
    return ' '.join(_SEPARATORS.sub(' ', _APOSTROPHES.sub('', text.lower())).split())


def _prefix_categories(word: str) -> frozenset[str]:
    """Partly typed words ("kuk", "goa", "chick") match the words they start."""
    if len(word) < 3:
        return frozenset()
    found = set()
    for key, categories in SYNONYMS.items():
        if any(part.startswith(word) for part in key.split()):
            found |= categories
    for category in CATEGORIES:
        if any(part.startswith(word) for part in category.split('_')):
            found.add(category)
    return frozenset(found)


def categories_for(word: str) -> frozenset[str]:
    """The categories one normalised word or phrase means; empty if none."""
    word = normalise(word)
    if word in SYNONYMS:
        return SYNONYMS[word]
    if word.replace(' ', '_') in CATEGORIES:
        return frozenset({word.replace(' ', '_')})
    return _prefix_categories(word) if ' ' not in word else frozenset()


def terms(query: str) -> list[tuple[str, frozenset[str]]]:
    """Splits a buyer's search into terms, each with the categories it means.

    Known phrases ("nyama ya mbuzi", "local chicken") stay together; joining
    words are dropped. A listing matches when every term matches its category,
    region or breed.
    """
    words = [w for w in normalise(query).split()]
    result = []
    i = 0
    while i < len(words):
        # Longest known phrase starting here (phrases are at most 4 words).
        for size in range(min(4, len(words) - i), 1, -1):
            phrase = ' '.join(words[i:i + size])
            if phrase in SYNONYMS:
                result.append((phrase, SYNONYMS[phrase]))
                i += size
                break
        else:
            if words[i] not in STOPWORDS:
                result.append((words[i], categories_for(words[i])))
            i += 1
    return result


# --- The listing query -----------------------------------------------------

CONDITIONS = {'live': 'live_or_dressed', 'dressed': 'live_or_dressed',
              'chilled': 'chilled_or_frozen', 'frozen': 'chilled_or_frozen'}
# Spec fields a buyer may name when searching: bird breed, animal breed, meat cut.
TYPE_SPECS = ('breed_type', 'breed', 'cut_type')
_NUMBER = r'[0-9]+(?:\.[0-9]+)?'


def _contains(text: str) -> str:
    """An ILIKE pattern matching `text` anywhere, with wildcards taken literally."""
    return '%' + text.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'


def _spec(name):
    return m.Listing.specs[name].as_string()


def matching(query, q: str = ''):
    """Adds the buyer's search words to a listings query (see `terms`)."""
    for word, categories in terms(q):
        pattern = _contains(word)
        options = [m.Listing.region.ilike(pattern, escape='\\')]
        options += [_spec(name).ilike(pattern, escape='\\') for name in TYPE_SPECS]
        if categories:
            options.append(m.Listing.category.in_(sorted(categories)))
        query = query.where(or_(*options))
    return query


def filtered(query, *, region=None, max_price=None, min_price=None, ready_by=None,
             condition=None, min_weight=None, max_weight=None):
    """The Explore screen's filters, applied in SQL so paging stays correct."""
    if region and region.strip():
        query = query.where(m.Listing.region.ilike(_contains(region.strip()), escape='\\'))
    if min_price is not None:
        query = query.where(m.Listing.buyer_price_per_unit >= min_price)
    if max_price is not None:
        query = query.where(m.Listing.buyer_price_per_unit <= max_price)
    if ready_by is not None:
        # ISO dates compare correctly as text.
        ready = func.coalesce(_spec('ready_date'), _spec('slaughter_date'))
        query = query.where(ready.is_not(None), ready != '', ready <= ready_by.isoformat())
    if condition:
        query = query.where(_spec(CONDITIONS[condition]) == condition)
    if min_weight is not None or max_weight is not None:
        # "2.1" (bird average) or "250-300 kg" (animal range): the first number
        # is the low end, the last the high end; ranges overlapping the filter match.
        weight = func.coalesce(_spec('avg_weight_kg'), _spec('weight_range'))
        low = cast(func.substring(weight, _NUMBER), Numeric)
        high = cast(func.substring(weight, f'({_NUMBER})[^0-9]*$'), Numeric)
        query = query.where(low.is_not(None))
        if min_weight is not None:
            query = query.where(high >= min_weight)
        if max_weight is not None:
            query = query.where(low <= max_weight)
    return query


def encode_cursor(listing) -> str:
    raw = f'{listing.created_at.isoformat()}|{listing.id}'
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip('=')


def after_cursor(query, cursor: str):
    """Continues a newest-first listing query after the cursor's listing."""
    try:
        raw = base64.urlsafe_b64decode(cursor + '=' * (-len(cursor) % 4)).decode()
        created, id = raw.split('|', 1)
        created_at = datetime.fromisoformat(created)
    except (ValueError, UnicodeDecodeError):
        fail('err.page_results_expired_search_again', 422)
    return query.where(tuple_(m.Listing.created_at, m.Listing.id) < tuple_(created_at, id))
