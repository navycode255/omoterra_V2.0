"""cPanel/Passenger entrypoint.

Passenger imports `application` from this file. It does not activate a
virtualenv, does not guarantee the working directory, and on some hosts
injects its own environment variables — so each of those is handled
explicitly below rather than left to chance.

If this file raises, Apache serves a bare 500 and the reason only appears in
the host's error log, so the import of the app itself is wrapped to turn a
startup failure into a readable response instead of a silent one.
"""
import glob
import os
import sys

APP_DIR = os.path.dirname(os.path.abspath(__file__))


def _candidate_site_packages():
    """Every plausible site-packages for this account, best guess first.

    cPanel's "Setup Python App" builds its own virtualenv under ~/virtualenv
    and runs Passenger with that interpreter, while the deployment guide also
    creates a local .venv. Which one is live depends on how the app was
    registered, so both are searched rather than assuming either.
    """
    home = os.path.expanduser('~')
    app_name = os.path.basename(APP_DIR)
    patterns = [
        os.path.join(APP_DIR, '.venv', 'lib', 'python3.*', 'site-packages'),
        os.path.join(home, 'virtualenv', app_name, '*', 'lib',
                     'python3.*', 'site-packages'),
        os.path.join(home, 'virtualenv', '*', '*', 'lib',
                     'python3.*', 'site-packages'),
    ]
    for pattern in patterns:
        for path in sorted(glob.glob(pattern)):
            yield path


for site_packages in _candidate_site_packages():
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


def _diagnostic_app(message):
    """Serve the startup failure instead of a bare Apache 500.

    Without this the only record is the host's error log, which is awkward to
    reach from a phone or a browser tab.
    """
    body = message.encode()

    def application(environ, start_response):
        start_response('500 Internal Server Error',
                       [('Content-Type', 'text/plain; charset=utf-8'),
                        ('Content-Length', str(len(body)))])
        return [body]

    return application


try:
    from a2wsgi import ASGIMiddleware
    from app.main import app

    application = ASGIMiddleware(app)
except Exception:  # noqa: BLE001 - report any startup failure, not just imports
    import traceback

    application = _diagnostic_app(
        'Omoterra failed to start.\n\n'
        f'python: {sys.version}\n'
        f'executable: {sys.executable}\n'
        f'app dir: {APP_DIR}\n'
        f'cwd: {os.getcwd()}\n'
        f'.env present: {os.path.exists(os.path.join(APP_DIR, ".env"))}\n'
        f'site-packages found: {list(_candidate_site_packages()) or "NONE"}\n\n'
        f'{traceback.format_exc()}')
