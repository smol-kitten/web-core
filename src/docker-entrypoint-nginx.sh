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
    : ${NGINX_WORKER_CONNECTIONS:=2048}
    : ${NGINX_KEEPALIVE_TIMEOUT:=30}
    : ${PHP_FPM_PM_MAX_CHILDREN:=50}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  SHOP)
    : ${PHP_MEMORY_LIMIT:=512M}
    : ${PHP_MAX_EXECUTION_TIME:=60}
    : ${PHP_UPLOAD_MAX_FILESIZE:=20M}
    : ${PHP_POST_MAX_SIZE:=20M}
    : ${NGINX_WORKER_CONNECTIONS:=1024}
    : ${NGINX_KEEPALIVE_TIMEOUT:=65}
    : ${PHP_FPM_PM_MAX_CHILDREN:=30}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  STATIC)
    : ${PHP_MEMORY_LIMIT:=128M}
    : ${PHP_MAX_EXECUTION_TIME:=15}
    : ${PHP_UPLOAD_MAX_FILESIZE:=2M}
    : ${PHP_POST_MAX_SIZE:=2M}
    : ${NGINX_WORKER_CONNECTIONS:=4096}
    : ${NGINX_KEEPALIVE_TIMEOUT:=15}
    : ${PHP_FPM_PM_MAX_CHILDREN:=10}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  CMS)
    : ${PHP_MEMORY_LIMIT:=384M}
    : ${PHP_MAX_EXECUTION_TIME:=90}
    : ${PHP_UPLOAD_MAX_FILESIZE:=64M}
    : ${PHP_POST_MAX_SIZE:=64M}
    : ${NGINX_WORKER_CONNECTIONS:=1024}
    : ${NGINX_KEEPALIVE_TIMEOUT:=65}
    : ${PHP_FPM_PM_MAX_CHILDREN:=25}
    : ${EXPOSE_SERVER_SOFTWARE:=off}
    ;;
  *)
    : ${PHP_MEMORY_LIMIT:=256M}
    : ${PHP_MAX_EXECUTION_TIME:=60}
    : ${PHP_UPLOAD_MAX_FILESIZE:=20M}
    : ${PHP_POST_MAX_SIZE:=20M}
    : ${NGINX_WORKER_CONNECTIONS:=1024}
    : ${NGINX_KEEPALIVE_TIMEOUT:=65}
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
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}
NGINX_KEEPALIVE_TIMEOUT=${NGINX_KEEPALIVE_TIMEOUT:-65}
NGINX_CLIENT_MAX_BODY_SIZE=${NGINX_CLIENT_MAX_BODY_SIZE:-${PHP_UPLOAD_MAX_FILESIZE}}
PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "Configuring nginx + PHP-FPM with QUICK_SET=${QUICK_SET:-default}"

set_timezone
configure_php
configure_fpm

# --- Configure Nginx ---
NGINX_CONF="/etc/nginx/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
    sed -i "s/worker_connections [0-9]*;/worker_connections $NGINX_WORKER_CONNECTIONS;/" "$NGINX_CONF"
    sed -i "s/keepalive_timeout [0-9]*;/keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT;/"   "$NGINX_CONF"
    if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
        grep -q "server_tokens off;" "$NGINX_CONF" || \
            sed -i '/http {/a \    server_tokens off;' "$NGINX_CONF"
    fi
fi

SITE_CONF="/etc/nginx/sites-enabled/nginx.conf"
if [ -f "$SITE_CONF" ]; then
    sed -i "s/listen [0-9]*/listen $WEB_PORT/" "$SITE_CONF"
    if ! grep -q "client_max_body_size" "$SITE_CONF"; then
        sed -i "/server {/a \    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;" "$SITE_CONF"
    else
        sed -i "s/client_max_body_size .*/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/" "$SITE_CONF"
    fi
    if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
        grep -q "server_tokens off;" "$SITE_CONF" || \
            sed -i "/server {/a \    server_tokens off;" "$SITE_CONF"
    fi
fi

echo "Configuration applied:"
echo "   TZ: $TZ | WEB_PORT: $WEB_PORT"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   Nginx connections: $NGINX_WORKER_CONNECTIONS | Keepalive: ${NGINX_KEEPALIVE_TIMEOUT}s"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Server tokens: $EXPOSE_SERVER_SOFTWARE"

run_custom_hook
start_fpm

echo "Starting Nginx..."
service nginx start

start_cron_if_installed

echo "Tailing logs..."
tail -f /var/log/nginx/access.log /var/log/nginx/error.log /var/log/php-fpm/error.log
