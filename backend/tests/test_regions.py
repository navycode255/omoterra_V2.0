from app.contracts import canonical_region


def test_regions_are_stored_with_their_proper_spelling():
    assert canonical_region('Dar es salaam') == 'Dar es Salaam'
    assert canonical_region('  DAR ES  SALAAM ') == 'Dar es Salaam'
    assert canonical_region('pwani') == 'Pwani'
    assert canonical_region('zanzibar south & central') == 'Zanzibar South & Central'
    # Inside a longer place only Dar es Salaam is fixed; the rest is kept as typed.
    assert canonical_region('Mbezi, dar es salaam') == 'Mbezi, Dar es Salaam'
    assert canonical_region('Kibaha town') == 'Kibaha town'
