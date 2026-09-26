"""Supplier video: YouTube links today, uploads to Omoterra's channel later.

Every supplier has at most one video. It is either a link to an existing
YouTube video, or (once a publisher is configured) a file operations uploads,
which the server publishes to Omoterra's YouTube channel. YouTube credentials
live only in the backend environment; nothing here is ever sent to a browser.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol
from urllib.parse import parse_qs, urlparse

from .i18n import fail

from .config import settings

VIDEO_ID = re.compile(r'^[A-Za-z0-9_-]{11}$')
YOUTUBE_HOSTS = {'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'youtu.be', 'www.youtube-nocookie.com', 'youtube-nocookie.com'}
ACCEPTED_UPLOAD_TYPES = {'video/mp4', 'video/quicktime', 'video/webm', 'video/x-matroska', 'video/3gpp'}


def youtube_id(url: str) -> str:
    """Return the video ID from any common YouTube URL form, or raise 422."""
    raw = url.strip()
    if VIDEO_ID.match(raw):
        return raw
    parsed = urlparse(raw if '://' in raw else f'https://{raw}')
    host = (parsed.hostname or '').lower()
    candidate = ''
    if host in YOUTUBE_HOSTS:
        parts = [part for part in parsed.path.split('/') if part]
        if host == 'youtu.be' and parts:
            candidate = parts[0]
        elif parts[:1] == ['watch']:
            candidate = parse_qs(parsed.query).get('v', [''])[0]
        elif len(parts) >= 2 and parts[0] in ('shorts', 'embed', 'live', 'v'):
            candidate = parts[1]
    if not VIDEO_ID.match(candidate):
        fail('err.paste_youtube_video_link_example', 422)
    return candidate


def youtube_urls(video_id: str) -> dict[str, str]:
    return {
        'youtube_video_id': video_id,
        'youtube_url': f'https://www.youtube.com/watch?v={video_id}',
        'thumbnail_url': f'https://i.ytimg.com/vi/{video_id}/hqdefault.jpg',
    }


@dataclass
class PublishedVideo:
    youtube_video_id: str
    status: str  # 'processing' while YouTube transcodes, then 'ready'


class VideoPublisher(Protocol):
    enabled: bool

    def publish(self, path: Path, title: str, supplier_id: str) -> PublishedVideo:
        """Upload a validated temporary file to Omoterra's YouTube channel."""
        ...


class DisabledVideoPublisher:
    """No channel is connected yet: uploads are refused before any file is
    accepted, and operations attach a YouTube link instead."""
    enabled = False

    def publish(self, path: Path, title: str, supplier_id: str) -> PublishedVideo:
        fail('err.video_uploads_are_not_switched', 503)


def publisher() -> VideoPublisher:
    # A YouTube adapter (OAuth refresh token held in the backend environment,
    # resumable upload to the Omoterra channel) plugs in here. Until one exists
    # the setting must stay 'disabled'; Settings.validate_runtime enforces it.
    if settings().video_provider == 'disabled':
        return DisabledVideoPublisher()
    raise RuntimeError(f'Unknown video provider {settings().video_provider!r}')
