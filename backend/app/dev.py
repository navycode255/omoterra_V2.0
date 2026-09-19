"""Serve the local Flutter browser build and API from one localhost origin."""
from pathlib import Path
import os
from urllib.parse import urlparse
import httpx
from fastapi import FastAPI, Request, Response
from fastapi.staticfiles import StaticFiles
from .config import settings

if settings().environment != 'development':
    raise RuntimeError('The local preview server is development-only')

upstream = os.getenv('OMOTERRA_DEV_API_UPSTREAM', '').rstrip('/')
if upstream:
    if urlparse(upstream).hostname not in {'localhost', '127.0.0.1'}:
        raise RuntimeError('The preview proxy only connects to a local API')
    app = FastAPI(docs_url=None, redoc_url=None)

    @app.api_route('/api/v1/{path:path}', methods=['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'])
    async def proxy(path: str, request: Request):
        headers = {key: value for key, value in request.headers.items()
                   if key.lower() not in {'host', 'connection', 'content-length'}}
        async with httpx.AsyncClient(timeout=30) as client:
            result = await client.request(request.method, f'{upstream}/api/v1/{path}',
                params=request.query_params, headers=headers, content=await request.body())
        return Response(result.content, status_code=result.status_code,
            headers={key: value for key, value in result.headers.items()
                     if key.lower() not in {'content-length', 'content-encoding', 'transfer-encoding', 'connection'}})
else:
    from .main import app

web_build = Path(__file__).resolve().parents[2] / 'mobile' / 'build' / 'web'
if not (web_build / 'index.html').exists():
    raise RuntimeError('Build the Flutter web target before starting app.dev')

app.mount('/', StaticFiles(directory=web_build, html=True), name='local-preview')
