#!/bin/bash
set -e

. /docker-entrypoint-common.sh

# --- QUICK SET PRESETS ---
case "${QUICK_SET:-default}" in
  API)
    : ${PHP_MEMORY_LIMIT:=256M}
    : ${PHP_MAX_EXECUTION_TIME:=30}
    : ${PHP_UPLOAD_MAX_FILESIZE:=10M}
    : ${PHP_POST_MAX_SIZE:=10M}
    : ${APACHE_MAX_REQUEST_WORKERS:=150}
    : ${APACHE_KEEPALIVE_TIMEOUT:=5}
    : ${PHP_FPM_PM_MAX_CHILDREN:=50}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  SHOP)
    : ${PHP_MEMORY_LIMIT:=512M}
    : ${PHP_MAX_EXECUTION_TIME:=60}
    : ${PHP_UPLOAD_MAX_FILESIZE:=20M}
    : ${PHP_POST_MAX_SIZE:=20M}
    : ${APACHE_MAX_REQUEST_WORKERS:=100}
    : ${APACHE_KEEPALIVE_TIMEOUT:=5}
    : ${PHP_FPM_PM_MAX_CHILDREN:=30}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  STATIC)
    : ${PHP_MEMORY_LIMIT:=128M}
    : ${PHP_MAX_EXECUTION_TIME:=15}
    : ${PHP_UPLOAD_MAX_FILESIZE:=2M}
    : ${PHP_POST_MAX_SIZE:=2M}
    : ${APACHE_MAX_REQUEST_WORKERS:=200}
    : ${APACHE_KEEPALIVE_TIMEOUT:=2}
    : ${PHP_FPM_PM_MAX_CHILDREN:=10}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  CMS)
    : ${PHP_MEMORY_LIMIT:=384M}
    : ${PHP_MAX_EXECUTION_TIME:=90}
    : ${PHP_UPLOAD_MAX_FILESIZE:=64M}
    : ${PHP_POST_MAX_SIZE:=64M}
    : ${APACHE_MAX_REQUEST_WORKERS:=100}
    : ${APACHE_KEEPALIVE_TIMEOUT:=5}
    : ${PHP_FPM_PM_MAX_CHILDREN:=25}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  *)
    : ${PHP_MEMORY_LIMIT:=256M}
    : ${PHP_MAX_EXECUTION_TIME:=60}
    : ${PHP_UPLOAD_MAX_FILESIZE:=20M}
    : ${PHP_POST_MAX_SIZE:=20M}
    : ${APACHE_MAX_REQUEST_WORKERS:=150}
    : ${APACHE_KEEPALIVE_TIMEOUT:=5}
    : ${PHP_FPM_PM_MAX_CHILDREN:=20}
    : ${EXPOSE_SERVER_SOFTWARE:=on}
    ;;
esac

# --- DEFAULTS ---
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
APACHE_MAX_REQUEST_WORKERS=${APACHE_MAX_REQUEST_WORKERS:-150}
APACHE_KEEPALIVE=${APACHE_KEEPALIVE:-On}
APACHE_KEEPALIVE_TIMEOUT=${APACHE_KEEPALIVE_TIMEOUT:-5}
APACHE_MAX_KEEPALIVE_REQUESTS=${APACHE_MAX_KEEPALIVE_REQUESTS:-100}
PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "Configuring Apache + PHP-FPM with QUICK_SET=${QUICK_SET:-default}"

set_timezone
configure_php
configure_fpm

# --- Configure Apache ---
PORTS_CONF="/etc/apache2/ports.conf"
[ -f "$PORTS_CONF" ] && sed -i "s/Listen [0-9]*/Listen $WEB_PORT/" "$PORTS_CONF"

SITE_CONF="/etc/apache2/sites-enabled/000-default.conf"
[ -f "$SITE_CONF" ] && sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:$WEB_PORT>/" "$SITE_CONF"

MPM_CONF="/etc/apache2/mods-available/mpm_event.conf"
[ -f "$MPM_CONF" ] && sed -i "s/MaxRequestWorkers.*/MaxRequestWorkers $APACHE_MAX_REQUEST_WORKERS/" "$MPM_CONF"

APACHE_CONF="/etc/apache2/apache2.conf"
if [ -f "$APACHE_CONF" ]; then
    if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
        if ! grep -q "ServerTokens" "$APACHE_CONF"; then
            printf '\nServerTokens Prod\nServerSignature Off\n' >> "$APACHE_CONF"
        else
            sed -i "s/ServerTokens.*/ServerTokens Prod/"     "$APACHE_CONF"
            sed -i "s/ServerSignature.*/ServerSignature Off/" "$APACHE_CONF"
        fi
    fi
    if ! grep -q "^KeepAlive" "$APACHE_CONF"; then
        printf '\nKeepAlive %s\nKeepAliveTimeout %s\nMaxKeepAliveRequests %s\n' \
            "$APACHE_KEEPALIVE" "$APACHE_KEEPALIVE_TIMEOUT" "$APACHE_MAX_KEEPALIVE_REQUESTS" \
            >> "$APACHE_CONF"
    else
        sed -i "s/^KeepAlive .*/KeepAlive $APACHE_KEEPALIVE/"                       "$APACHE_CONF"
        sed -i "s/^KeepAliveTimeout .*/KeepAliveTimeout $APACHE_KEEPALIVE_TIMEOUT/" "$APACHE_CONF"
        sed -i "s/^MaxKeepAliveRequests .*/MaxKeepAliveRequests $APACHE_MAX_KEEPALIVE_REQUESTS/" "$APACHE_CONF"
    fi
fi

echo "Configuration applied:"
echo "   TZ: $TZ | WEB_PORT: $WEB_PORT"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   Apache workers: $APACHE_MAX_REQUEST_WORKERS | KeepAlive: ${APACHE_KEEPALIVE_TIMEOUT}s"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Server tokens: $EXPOSE_SERVER_SOFTWARE"

run_custom_hook
start_fpm

echo "Starting Apache..."
service apache2 start

start_cron_if_installed

echo "Tailing logs..."
tail -f /var/log/apache2/access.log /var/log/apache2/error.log /var/log/php-fpm/error.log
