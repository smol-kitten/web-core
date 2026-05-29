#!/bin/bash
set -e

. /docker-entrypoint-common.sh

# -----------------------------------------------------------------------
# QUICK_SET presets
# -----------------------------------------------------------------------
case "${QUICK_SET:-default}" in
  AUTO)
    . /docker-auto-tune.sh
    auto_tune
    ;;
  API)
    : "${PHP_MEMORY_LIMIT:=256M}"
    : "${PHP_MAX_EXECUTION_TIME:=30}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=10M}"
    : "${PHP_POST_MAX_SIZE:=10M}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=50}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    ;;
  SHOP)
    : "${PHP_MEMORY_LIMIT:=512M}"
    : "${PHP_MAX_EXECUTION_TIME:=60}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=20M}"
    : "${PHP_POST_MAX_SIZE:=20M}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=30}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    : "${SESSION_COOKIE_SECURE:=On}"
    ;;
  STATIC)
    : "${PHP_MEMORY_LIMIT:=128M}"
    : "${PHP_MAX_EXECUTION_TIME:=15}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=2M}"
    : "${PHP_POST_MAX_SIZE:=2M}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=10}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    ;;
  CMS)
    : "${PHP_MEMORY_LIMIT:=384M}"
    : "${PHP_MAX_EXECUTION_TIME:=90}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=64M}"
    : "${PHP_POST_MAX_SIZE:=64M}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=25}"
    : "${EXPOSE_SERVER_SOFTWARE:=off}"
    ;;
  *)
    : "${PHP_MEMORY_LIMIT:=256M}"
    : "${PHP_MAX_EXECUTION_TIME:=60}"
    : "${PHP_UPLOAD_MAX_FILESIZE:=20M}"
    : "${PHP_POST_MAX_SIZE:=20M}"
    : "${PHP_FPM_PM_MAX_CHILDREN:=20}"
    : "${EXPOSE_SERVER_SOFTWARE:=on}"
    ;;
esac

# -----------------------------------------------------------------------
# Defaults
# -----------------------------------------------------------------------
TZ=${TZ:-UTC}
WEB_PORT=${WEB_PORT:-80}

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

PHP_EXPOSE=${PHP_EXPOSE:-Off}
PHP_DISABLE_DANGEROUS_FUNCTIONS=${PHP_DISABLE_DANGEROUS_FUNCTIONS:-false}
SECURITY_HEADERS=${SECURITY_HEADERS:-true}
FORCE_HTTPS=${FORCE_HTTPS:-false}
CSP_HEADER=${CSP_HEADER:-""}

PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "Configuring Caddy + PHP-FPM | QUICK_SET=${QUICK_SET:-default}"

set_timezone
configure_php
configure_security_php
configure_fpm

# -----------------------------------------------------------------------
# Configure Caddyfile
# -----------------------------------------------------------------------
CADDYFILE="/etc/caddy/Caddyfile"

if [ "$SECURITY_HEADERS" = "false" ] && [ -f "$CADDYFILE" ]; then
    sed -i '/X-Content-Type-Options/d' "$CADDYFILE"
    sed -i '/X-Frame-Options/d'        "$CADDYFILE"
    sed -i '/Referrer-Policy/d'         "$CADDYFILE"
    sed -i '/Permissions-Policy/d'      "$CADDYFILE"
fi

if [ "$FORCE_HTTPS" = "true" ] && [ -f "$CADDYFILE" ]; then
    sed -i '/auto_https off/d' "$CADDYFILE"
fi

if [ -n "$CSP_HEADER" ] && [ -f "$CADDYFILE" ]; then
    grep -q "Content-Security-Policy" "$CADDYFILE" || \
        sed -i "/header {/a \\\t\tContent-Security-Policy \"${CSP_HEADER}\"" "$CADDYFILE"
fi

echo "Configuration applied:"
echo "   TZ: $TZ | WEB_PORT: $WEB_PORT | PHP expose: $PHP_EXPOSE"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Security headers: $SECURITY_HEADERS | HTTPS: $FORCE_HTTPS"
echo "   Health worker: ${HEALTH_WORKER:-true} | Telemetry: ${OTEL_ENABLED:-false}"

run_custom_hook
start_fpm

start_cron_if_installed
start_background_workers

echo "Starting Caddy..."
exec caddy run --config /etc/caddy/Caddyfile
