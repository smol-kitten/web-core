#!/bin/bash
set -e

. /docker-entrypoint-common.sh

# -----------------------------------------------------------------------
# QUICK_SET presets — sets sensible defaults; explicit env vars override
# -----------------------------------------------------------------------
case "${QUICK_SET:-default}" in
  AUTO)
    # Resource calculator sets values from hardware + traffic hints
    . /docker-auto-tune.sh
    auto_tune
    ;;
  API)
    : "${PHP_MEMORY_LIMIT:=256M}"
    : "${PHP_MAX_EXECUTION_TIME:=30}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=10M}"
    : "${PHP_POST_MAX_SIZE:=10M}"
    : "${NGINX_WORKER_CONNECTIONS:=2048}"
    : "${NGINX_KEEPALIVE_TIMEOUT:=30}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=50}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    : "${RATE_LIMIT:=true}"
    ;;
  SHOP)
    : "${PHP_MEMORY_LIMIT:=512M}"
    : "${PHP_MAX_EXECUTION_TIME:=60}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=20M}"
    : "${PHP_POST_MAX_SIZE:=20M}"
    : "${NGINX_WORKER_CONNECTIONS:=1024}"
    : "${NGINX_KEEPALIVE_TIMEOUT:=65}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=30}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    : "${SESSION_COOKIE_SECURE:=On}"
    ;;
  STATIC)
    : "${PHP_MEMORY_LIMIT:=128M}"
    : "${PHP_MAX_EXECUTION_TIME:=15}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=2M}"
    : "${PHP_POST_MAX_SIZE:=2M}"
    : "${NGINX_WORKER_CONNECTIONS:=4096}"
    : "${NGINX_KEEPALIVE_TIMEOUT:=15}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=10}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    ;;
  CMS)
    : "${PHP_MEMORY_LIMIT:=384M}"
    : "${PHP_MAX_EXECUTION_TIME:=90}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=64M}"
    : "${PHP_POST_MAX_SIZE:=64M}"
    : "${NGINX_WORKER_CONNECTIONS:=1024}"
    : "${NGINX_KEEPALIVE_TIMEOUT:=65}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=25}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    ;;
  *)
    : "${PHP_MEMORY_LIMIT:=256M}"
    : "${PHP_MAX_EXECUTION_TIME:=60}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=20M}"
    : "${PHP_POST_MAX_SIZE:=20M}"
    : "${NGINX_WORKER_CONNECTIONS:=1024}"
    : "${NGINX_KEEPALIVE_TIMEOUT:=65}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=20}"
    : "${EXPOSE_SERVER_SOFTWARE:=on}"
    ;;
esac

# -----------------------------------------------------------------------
# Defaults for all remaining env vars
# -----------------------------------------------------------------------
TZ=${TZ:-UTC}
WEB_PORT=${WEB_PORT:-80}
EXPOSE_SERVER_SOFTWARE=${EXPOSE_SERVER_SOFTWARE:-on}

PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-256M}
PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-60}
PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE:-20M}
PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-20M}
PHP_MAX_INPUT_VARS=${PHP_MAX_INPUT_VARS:-1000}
PHP_DISPLAY_ERRORS=${PHP_DISPLAY_ERRORS:-Off}
PHP_LOG_ERRORS=${PHP_LOG_ERRORS:-On}
DISABLE_FUNCTIONS=${DISABLE_FUNCTIONS:-""}
ALLOW_URL_FOPEN=${ALLOW_URL_FOPEN:-On}
SESSION_COOKIE_SECURE=${SESSION_COOKIE_SECURE:-Off}
SESSION_COOKIE_HTTPONLY=${SESSION_COOKIE_HTTPONLY:-On}
PHP_OPCACHE_ENABLE=${PHP_OPCACHE_ENABLE:-1}
PHP_OPCACHE_MEMORY=${PHP_OPCACHE_MEMORY:-128}
PHP_OPCACHE_MAX_FILES=${PHP_OPCACHE_MAX_FILES:-10000}

# Security
PHP_EXPOSE=${PHP_EXPOSE:-Off}
PHP_SESSION_STRICT=${PHP_SESSION_STRICT:-On}
PHP_DISABLE_DANGEROUS_FUNCTIONS=${PHP_DISABLE_DANGEROUS_FUNCTIONS:-false}
SECURITY_HEADERS=${SECURITY_HEADERS:-true}
FORCE_HTTPS=${FORCE_HTTPS:-false}
CSP_HEADER=${CSP_HEADER:-""}
RATE_LIMIT=${RATE_LIMIT:-false}
RATE_LIMIT_RPS=${RATE_LIMIT_RPS:-10}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST:-20}

# Nginx
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}
NGINX_KEEPALIVE_TIMEOUT=${NGINX_KEEPALIVE_TIMEOUT:-65}
NGINX_CLIENT_MAX_BODY_SIZE=${NGINX_CLIENT_MAX_BODY_SIZE:-${PHP_UPLOAD_MAX_FILESIZE}}

# PHP-FPM
PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "Configuring nginx + PHP-FPM | QUICK_SET=${QUICK_SET:-default}"

set_timezone
configure_php
configure_security_php
configure_fpm

# -----------------------------------------------------------------------
# Configure Nginx
# -----------------------------------------------------------------------
NGINX_CONF="/etc/nginx/nginx.conf"
SITE_CONF="/etc/nginx/sites-enabled/nginx.conf"

if [ -f "$NGINX_CONF" ]; then
    sed -i "s/worker_connections [0-9]*/worker_connections $NGINX_WORKER_CONNECTIONS/"   "$NGINX_CONF"
    sed -i "s/keepalive_timeout [0-9]*/keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT/"     "$NGINX_CONF"

    # Rate limit zone — update the configured rate
    sed -i "s/rate=[0-9]*r\/s/rate=${RATE_LIMIT_RPS}r\/s/" "$NGINX_CONF" 2>/dev/null || true

    if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
        grep -q "server_tokens off;" "$NGINX_CONF" || \
            sed -i '/http {/a \    server_tokens off;' "$NGINX_CONF"
    fi
fi

if [ -f "$SITE_CONF" ]; then
    sed -i "s/listen [0-9]*/listen $WEB_PORT/" "$SITE_CONF"

    # Body size
    if ! grep -q "client_max_body_size" "$SITE_CONF"; then
        sed -i "/server {/a \    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;" "$SITE_CONF"
    else
        sed -i "s/client_max_body_size .*/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/" "$SITE_CONF"
    fi

    # Server tokens at site level
    if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
        grep -q "server_tokens off;" "$SITE_CONF" || \
            sed -i "/server {/a \    server_tokens off;" "$SITE_CONF"
    fi

    # Security headers (toggle)
    if [ "$SECURITY_HEADERS" = "false" ]; then
        sed -i '/add_header X-Content-Type-Options/d'  "$SITE_CONF"
        sed -i '/add_header X-XSS-Protection/d'        "$SITE_CONF"
        sed -i '/add_header X-Frame-Options/d'          "$SITE_CONF"
        sed -i '/add_header Referrer-Policy/d'          "$SITE_CONF"
        sed -i '/add_header Permissions-Policy/d'       "$SITE_CONF"
    fi

    # HSTS (only useful behind TLS terminator)
    if [ "$FORCE_HTTPS" = "true" ]; then
        grep -q "Strict-Transport-Security" "$SITE_CONF" || \
            sed -i "/server {/a \    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains; preload\" always;" "$SITE_CONF"
    fi

    # Content-Security-Policy (opt-in, empty = disabled)
    if [ -n "$CSP_HEADER" ]; then
        grep -q "Content-Security-Policy" "$SITE_CONF" || \
            sed -i "/server {/a \    add_header Content-Security-Policy \"${CSP_HEADER}\" always;" "$SITE_CONF"
    fi

    # Rate limiting (opt-in)
    if [ "$RATE_LIMIT" = "true" ]; then
        sed -i "s/# limit_req /limit_req /" "$SITE_CONF"
        sed -i "s/burst=[0-9]*/burst=${RATE_LIMIT_BURST}/" "$SITE_CONF"
    fi
fi

echo "Configuration applied:"
echo "   TZ: $TZ | WEB_PORT: $WEB_PORT | PHP expose: $PHP_EXPOSE"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   Nginx connections: $NGINX_WORKER_CONNECTIONS | Keepalive: ${NGINX_KEEPALIVE_TIMEOUT}s"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Security headers: $SECURITY_HEADERS | Rate limit: $RATE_LIMIT | HTTPS: $FORCE_HTTPS"
echo "   Health worker: ${HEALTH_WORKER:-true} | Telemetry: ${OTEL_ENABLED:-false}"

run_custom_hook
start_fpm

echo "Starting Nginx..."
service nginx start

start_cron_if_installed
start_background_workers

echo "Tailing logs..."
tail -f /var/log/nginx/access.log /var/log/nginx/error.log /var/log/php-fpm/error.log
