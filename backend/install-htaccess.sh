#!/bin/bash
# Installs the Apache config that proxies the subdomain to the uvicorn
# process started by restart-omoterra.sh.
#
# Takes the document root as its argument, because it differs per host and
# writing to a path that does not exist fails silently enough to look like
# success:
#
#   ./install-htaccess.sh ~/public_html/omoterra
set -u

DOCROOT="${1:-}"
PORT="8011"

if [ -z "$DOCROOT" ]; then
    echo "usage: $0 <document-root>" >&2
    echo "" >&2
    echo "Find it with:  ls -la ~/public_html/" >&2
    exit 1
fi

if [ ! -d "$DOCROOT" ]; then
    echo "Refusing to write: $DOCROOT is not a directory." >&2
    echo "Pass the subdomain's real document root." >&2
    exit 1
fi

TARGET="$DOCROOT/.htaccess"

if [ -f "$TARGET" ]; then
    backup="$TARGET.backup.$(date +%Y%m%d%H%M%S)"
    cp "$TARGET" "$backup"
    echo "Existing .htaccess backed up to $backup"
fi

cat > "$TARGET" <<HTACCESS
# Deny application files first, before anything is proxied or served. On
# this host the document root IS the application directory, so without
# these rules Apache hands out source, logs and the dependency lock to
# anyone who asks. Ordering matters: these must precede the rewrite.
<FilesMatch "\\.(py|pyc|env|lock|sh|log|pid|broken|example|md)\$">
    Require all denied
</FilesMatch>

# Dot-files (.env, .env.backup, .git/...) in any form.
<FilesMatch "^\\.">
    Require all denied
</FilesMatch>

RedirectMatch 404 ^/(app|migrations|tests|logs|media|\\.venv|\\.git)(/|\$)

RewriteEngine On

# Hand every remaining path to the ASGI app, including /health and
# /api/v1/*.
RewriteCond %{REQUEST_URI} !^/\\.well-known/
RewriteRule ^(.*)\$ http://127.0.0.1:$PORT/\$1 [P,QSA,L]

<IfModule mod_proxy.c>
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https" env=HTTPS
</IfModule>

Options -Indexes
HTACCESS

if [ ! -s "$TARGET" ]; then
    echo "Wrote $TARGET but it is empty — check permissions." >&2
    exit 1
fi

echo "Installed $TARGET ($(wc -l < "$TARGET") lines)"
echo ""
echo "Apache must be reachable and the app running on port $PORT."
echo "Verify with:"
echo "  curl -sS -o /dev/null -w 'public: HTTP %{http_code}\\n' https://omoterra.jopex.co.tz/health"
echo ""
echo "A 500 here usually means mod_proxy is not enabled on this host; a 404"
echo "means Apache is not reading this file, so the document root is wrong."
