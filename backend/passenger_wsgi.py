"""cPanel/Passenger entrypoint.

Passenger imports `application` from this file. It does not activate a
virtualenv, does not guarantee the working directory, and on some hosts
injects its own environment variables — so each of those is handled
explicitly below rather than left to chance.

If this file raises, Apache serves a bare 500 with no explanation. The app
import is wrapped so the reason is written to stderr, which Passenger routes
to the account's error log, while the browser gets only a generic message:
this endpoint is public, so it must not disclose paths, configuration or
tracebacks that can carry connection strings.
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
# Both locations app/config.py searches, nearest first: beside the app, then
# the account home one level up. The sibling automob-api deployment keeps its
# file at ~/.env, so the parent is a real location here, not a guess.
_ENV_FILES = (os.path.join(APP_DIR, '.env'),
              os.path.join(os.path.dirname(APP_DIR), '.env'))
_ENV_FOUND = [path for path in _ENV_FILES if os.path.exists(path)]

try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv missing: fall back to pydantic-settings.
    pass
else:
    # Loaded furthest-first so the file nearest the app wins on conflicts,
    # matching the order config.py resolves them in.
    for _env_file in reversed(_ENV_FOUND):
        load_dotenv(_env_file, override=True)

# With no .env anywhere the app silently falls back to development defaults:
# a localhost database, a placeholder OTP secret and an empty ops token. That
# starts and serves 200, so a missing file looks like a healthy deployment
# while pointing at the wrong database. Say so loudly in the log.
if not _ENV_FOUND and not os.environ.get('OMOTERRA_DATABASE_URL'):
    print('WARNING: no .env found at ' + ' or '.join(_ENV_FILES) +
          ', and no OMOTERRA_DATABASE_URL in the environment. The app will '
          'start with development defaults and will NOT be using your '
          'production database.', file=sys.stderr)
    sys.stderr.flush()


def _failed_app(message):
    """Return a WSGI app that reports a startup failure generically.

    The message is deliberately free of paths, configuration and traceback
    text: this responds on a public URL, and startup tracebacks routinely
    carry the database URL, which embeds its password.
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

    # Diagnostics go to stderr, which Passenger writes to the account's error
    # log — readable by the deployer, not by the public. The browser gets a
    # generic message so a failed start cannot disclose credentials.
    print('Omoterra failed to start.', file=sys.stderr)
    print(f'python: {sys.version}', file=sys.stderr)
    print(f'executable: {sys.executable}', file=sys.stderr)
    print(f'app dir: {APP_DIR}', file=sys.stderr)
    print(f'cwd: {os.getcwd()}', file=sys.stderr)
    print(f'.env present: {os.path.exists(os.path.join(APP_DIR, ".env"))}',
          file=sys.stderr)
    print(f'site-packages: {list(_candidate_site_packages()) or "NONE"}',
          file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    sys.stderr.flush()

    application = _failed_app(
        'Omoterra is not available. The application failed to start; '
        'the reason has been written to the server error log.\n')
