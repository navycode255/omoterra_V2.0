from datetime import timedelta

from sqlalchemy import select

from app import models as m
from app.config import settings
from app.media import prune_unused_media
from test_commerce import headers
from test_stock_media_location import photo


def stored(tmp_path, url):
    return (tmp_path / f"{url.removeprefix('/media/')}.jpg").exists()


def asset(sessions, url):
    with sessions() as db:
        return db.get(m.MediaAsset, url.removeprefix('/media/'))


def test_removing_a_stock_photo_deletes_its_file(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    keep, drop = photo(client), photo(client)
    media = f"/api/v1/supplier/stock/{seeded['listing']}/media"
    assert client.put(media, headers=headers('supplier'), json={'photos': [keep, drop], 'video': None}).status_code == 200
    # Taking a saved photo back only marks it; the save is what lets it go.
    assert client.delete(f'/api/v1{drop}', headers=headers('supplier')).status_code == 204
    assert stored(tmp_path, drop)
    assert client.put(media, headers=headers('supplier'), json={'photos': [keep], 'video': None}).status_code == 200
    assert not stored(tmp_path, drop) and asset(sessions, drop) is None
    assert stored(tmp_path, keep) and asset(sessions, keep)


def test_an_unsaved_upload_is_deleted_at_once_and_only_by_its_owner(client, sessions, tmp_path):
    settings().media_directory = str(tmp_path)
    url = photo(client)
    assert client.delete(f'/api/v1{url}', headers=headers('buyer')).status_code == 204
    assert stored(tmp_path, url)
    assert client.delete(f'/api/v1{url}', headers=headers('supplier')).status_code == 204
    assert not stored(tmp_path, url) and asset(sessions, url) is None
    # Deleting twice is harmless.
    assert client.delete(f'/api/v1{url}', headers=headers('supplier')).status_code == 204


def test_hourly_prune_removes_only_old_unused_uploads(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    old, fresh, used = photo(client), photo(client), photo(client)
    client.put(f"/api/v1/supplier/stock/{seeded['listing']}/media", headers=headers('supplier'), json={'photos': [used], 'video': None})
    with sessions.begin() as db:
        for url in (old, used):
            db.get(m.MediaAsset, url.removeprefix('/media/')).created_at = m.now() - timedelta(days=2)
    with sessions.begin() as db:
        assert prune_unused_media(db) == 1
    assert not stored(tmp_path, old)
    assert stored(tmp_path, fresh) and stored(tmp_path, used)


def test_buyer_sees_a_photo_only_while_its_listing_is_live(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    url = photo(client)
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).photos = [url]
    assert client.get(f'/api/v1{url}', headers=headers('buyer')).status_code == 200
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).confirmation_due_at = m.now() - timedelta(minutes=1)
    assert client.get(f'/api/v1{url}', headers=headers('buyer')).status_code == 404


def refs(sessions):
    with sessions() as db:
        return {(row.media_id, row.owner_table) for row in db.scalars(select(m.MediaReference))}


def test_references_follow_every_kind_of_media_field(client, sessions, seeded, tmp_path):
    from app.media import in_use
    settings().media_directory = str(tmp_path)
    in_list, as_video, on_request, loose = photo(client), photo(client), photo(client), photo(client)
    id = lambda url: url.removeprefix('/media/')
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.photos, listing.video = [in_list], as_video
        request = m.SourcingRequest(buyer_id=seeded['buyer'], category='broilers', unit_type='bird', quantity=5,
            needed_by_date='2027-01-01', delivery_area='Dar', reference_photo=on_request)
        db.add(request)
    assert refs(sessions) == {(id(in_list), 'listings'), (id(as_video), 'listings'), (id(on_request), 'buyer_requirements')}
    with sessions() as db:
        assert all(in_use(db, url) for url in (in_list, as_video, on_request)) and not in_use(db, loose)
    # Editing a field swaps its references; other writes leave them alone.
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.video, listing.quantity_total = None, listing.quantity_total + 1
    with sessions.begin() as db:
        db.delete(db.get(m.SourcingRequest, request.id))
    assert refs(sessions) == {(id(in_list), 'listings')}


def test_a_stray_url_never_breaks_a_save(client, sessions, seeded):
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).photos = ['/media/00000000-0000-0000-0000-000000000000', 'https://elsewhere/x.jpg']
    assert refs(sessions) == set()


def test_a_large_phone_photo_is_decoded_small_and_kept_at_1600px(client, tmp_path):
    from io import BytesIO
    from PIL import Image
    settings().media_directory = str(tmp_path)
    raw = BytesIO(); Image.new('RGB', (4000, 3000), (40, 120, 60)).save(raw, 'JPEG')
    response = client.post('/api/v1/media', headers=headers('supplier'), files={'file': ('p.jpg', raw.getvalue(), 'image/jpeg')})
    assert response.status_code == 200, response.text
    with Image.open(tmp_path / f"{response.json()['id']}.jpg") as saved:
        assert saved.size == (1600, 1200)
