"""cPanel/Passenger entrypoint.

Passenger imports `application` from this file. It does not activate the
virtualenv, does not guarantee the working directory, and on some hosts
injects its own environment variables — so each of those is handled
explicitly below rather than left to chance.
"""
import glob
import os
import sys

APP_DIR = os.path.dirname(os.path.abspath(__file__))

# Passenger runs under the system Python, not the venv's, so the venv's
# packages are not importable until its site-packages is on the path. The
# Python version is discovered rather than hardcoded: pinning the wrong
# pythonX.Y here silently finds nothing and the imports below still fail.
for site_packages in sorted(
    glob.glob(os.path.join(APP_DIR, '.venv', 'lib', 'python3.*', 'site-packages'))
):
    if site_packages not in sys.path:
        sys.path.insert(0, site_packages)

if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

# Settings resolve relative paths (media_directory defaults to './media')
# against the working directory, which Passenger does not set for us.
os.chdir(APP_DIR)

# pydantic-settings reads .env too, but it will not override a variable that
# is already present in the process environment. Some panels inject empty or
# stale OMOTERRA_* values, which would then quietly win over the file — so
# the file is loaded first with override=True to settle the precedence.
try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv missing: fall back to pydantic-settings.
    pass
else:
    load_dotenv(os.path.join(APP_DIR, '.env'), override=True)

from a2wsgi import ASGIMiddleware
from app.main import app

application = ASGIMiddleware(app)
