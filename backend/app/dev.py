"""Serve the local Flutter browser build and API from one localhost origin."""
from pathlib import Path
from fastapi.staticfiles import StaticFiles
from .main import app
from .config import settings

if settings().environment != 'development':
    raise RuntimeError('The local preview server is development-only')

web_build = Path(__file__).resolve().parents[2] / 'mobile' / 'build' / 'web'
if not (web_build / 'index.html').exists():
    raise RuntimeError('Build the Flutter web target before starting app.dev')

app.mount('/', StaticFiles(directory=web_build, html=True), name='local-preview')
