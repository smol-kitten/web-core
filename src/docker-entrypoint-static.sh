#!/bin/bash
set -e

TZ=${TZ:-UTC}
WEB_PORT=${WEB_PORT:-80}
SPA_FALLBACK=${SPA_FALLBACK:-true}
SECURITY_HEADERS=${SECURITY_HEADERS:-true}
FORCE_HTTPS=${FORCE_HTTPS:-false}
CSP_HEADER=${CSP_HEADER:-""}

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
echo "$TZ" > /etc/timezone

SITE_CONF="/etc/nginx/sites-enabled/00-static.conf"

sed -i "s/listen [0-9]*/listen $WEB_PORT/" "$SITE_CONF"

if [ "$SPA_FALLBACK" = "false" ]; then
    sed -i 's|try_files \$uri \$uri/ /index\.html;|try_files $uri $uri/ =404;|' "$SITE_CONF"
fi

if [ "$SECURITY_HEADERS" = "false" ]; then
    sed -i '/add_header X-Content-Type-Options/d' "$SITE_CONF"
    sed -i '/add_header X-Frame-Options/d'        "$SITE_CONF"
    sed -i '/add_header Referrer-Policy/d'         "$SITE_CONF"
    sed -i '/add_header Permissions-Policy/d'      "$SITE_CONF"
fi

if [ "$FORCE_HTTPS" = "true" ]; then
    grep -q "Strict-Transport-Security" "$SITE_CONF" || \
        sed -i "/server {/a \    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains; preload\" always;" "$SITE_CONF"
fi

if [ -n "$CSP_HEADER" ]; then
    grep -q "Content-Security-Policy" "$SITE_CONF" || \
        sed -i "/server {/a \    add_header Content-Security-Policy \"${CSP_HEADER}\" always;" "$SITE_CONF"
fi

echo "Static server ready:"
echo "  Port: $WEB_PORT | SPA fallback: $SPA_FALLBACK | TZ: $TZ"
echo "  Security headers: $SECURITY_HEADERS | HTTPS: $FORCE_HTTPS"

if [ -f "/docker-entrypoint-custom.sh" ]; then
    echo "Executing custom entrypoint hook..."
    /bin/bash /docker-entrypoint-custom.sh
fi

exec nginx -g "daemon off;"
