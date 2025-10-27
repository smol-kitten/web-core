#!/bin/bash
set -e

#######################################################
# NGINX + PHP-FPM Entrypoint with Environment Config
#######################################################

# --- QUICK SET PRESETS ---
# API: optimized for API workloads (higher concurrency, small buffers)
# SHOP: e-commerce (moderate concurrency, session handling)
# STATIC: static content (high concurrency, minimal PHP)
# CMS: content management (balanced, caching friendly)
# Default: balanced general-purpose

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
    # Default balanced config
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

# --- ENVIRONMENT VARIABLES (can override QUICK_SET) ---
# Timezone
TZ=${TZ:-UTC}
export TZ
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone

# Web port
WEB_PORT=${WEB_PORT:-80}

# Server tokens (expose version info)
EXPOSE_SERVER_SOFTWARE=${EXPOSE_SERVER_SOFTWARE:-on}

# PHP settings
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-256M}
PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-60}
PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE:-20M}
PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-20M}
PHP_MAX_INPUT_VARS=${PHP_MAX_INPUT_VARS:-1000}
PHP_DISPLAY_ERRORS=${PHP_DISPLAY_ERRORS:-Off}
PHP_LOG_ERRORS=${PHP_LOG_ERRORS:-On}

# Privacy & Security
DISABLE_FUNCTIONS=${DISABLE_FUNCTIONS:-""}
ALLOW_URL_FOPEN=${ALLOW_URL_FOPEN:-On}
SESSION_COOKIE_SECURE=${SESSION_COOKIE_SECURE:-Off}
SESSION_COOKIE_HTTPONLY=${SESSION_COOKIE_HTTPONLY:-On}

# Performance
PHP_OPCACHE_ENABLE=${PHP_OPCACHE_ENABLE:-1}
PHP_OPCACHE_MEMORY=${PHP_OPCACHE_MEMORY:-128}
PHP_OPCACHE_MAX_FILES=${PHP_OPCACHE_MAX_FILES:-10000}

# Nginx settings
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}
NGINX_KEEPALIVE_TIMEOUT=${NGINX_KEEPALIVE_TIMEOUT:-65}
NGINX_CLIENT_MAX_BODY_SIZE=${NGINX_CLIENT_MAX_BODY_SIZE:-${PHP_UPLOAD_MAX_FILESIZE}}

# PHP-FPM settings
PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "🐾 Configuring nginx + PHP-FPM with QUICK_SET=${QUICK_SET:-default}"

# --- Configure PHP ---
PHP_INI="/etc/php/8.4/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
  sed -i "s/^memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" "$PHP_INI"
  sed -i "s/^max_execution_time = .*/max_execution_time = $PHP_MAX_EXECUTION_TIME/" "$PHP_INI"
  sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE/" "$PHP_INI"
  sed -i "s/^post_max_size = .*/post_max_size = $PHP_POST_MAX_SIZE/" "$PHP_INI"
  sed -i "s/^max_input_vars = .*/max_input_vars = $PHP_MAX_INPUT_VARS/" "$PHP_INI"
  sed -i "s/^display_errors = .*/display_errors = $PHP_DISPLAY_ERRORS/" "$PHP_INI"
  sed -i "s/^log_errors = .*/log_errors = $PHP_LOG_ERRORS/" "$PHP_INI"
  sed -i "s/^allow_url_fopen = .*/allow_url_fopen = $ALLOW_URL_FOPEN/" "$PHP_INI"
  sed -i "s/^session.cookie_secure = .*/session.cookie_secure = $SESSION_COOKIE_SECURE/" "$PHP_INI"
  sed -i "s/^session.cookie_httponly = .*/session.cookie_httponly = $SESSION_COOKIE_HTTPONLY/" "$PHP_INI"
  
  if [ -n "$DISABLE_FUNCTIONS" ]; then
    sed -i "s/^disable_functions = .*/disable_functions = $DISABLE_FUNCTIONS/" "$PHP_INI"
  fi
  
  # OPcache
  sed -i "s/^opcache.enable=.*/opcache.enable=$PHP_OPCACHE_ENABLE/" "$PHP_INI"
  sed -i "s/^opcache.memory_consumption=.*/opcache.memory_consumption=$PHP_OPCACHE_MEMORY/" "$PHP_INI"
  sed -i "s/^opcache.max_accelerated_files=.*/opcache.max_accelerated_files=$PHP_OPCACHE_MAX_FILES/" "$PHP_INI"
fi

# --- Configure PHP-FPM pool ---
FPM_POOL="/etc/php/8.4/fpm/pool.d/www.conf"
if [ -f "$FPM_POOL" ]; then
  sed -i "s/^pm = .*/pm = $PHP_FPM_PM/" "$FPM_POOL"
  sed -i "s/^pm.max_children = .*/pm.max_children = $PHP_FPM_PM_MAX_CHILDREN/" "$FPM_POOL"
  sed -i "s/^pm.start_servers = .*/pm.start_servers = $PHP_FPM_PM_START_SERVERS/" "$FPM_POOL"
  sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = $PHP_FPM_PM_MIN_SPARE_SERVERS/" "$FPM_POOL"
  sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = $PHP_FPM_PM_MAX_SPARE_SERVERS/" "$FPM_POOL"
fi

# --- Configure Nginx ---
NGINX_CONF="/etc/nginx/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
  sed -i "s/worker_connections [0-9]*;/worker_connections $NGINX_WORKER_CONNECTIONS;/" "$NGINX_CONF"
  sed -i "s/keepalive_timeout [0-9]*;/keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT;/" "$NGINX_CONF"
  
  # Server tokens
  if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
    if ! grep -q "server_tokens off;" "$NGINX_CONF"; then
      sed -i '/http {/a \    server_tokens off;' "$NGINX_CONF"
    fi
  fi
fi

# Update site config for port and body size
SITE_CONF="/etc/nginx/sites-enabled/nginx.conf"
if [ -f "$SITE_CONF" ]; then
  sed -i "s/listen [0-9]*/listen $WEB_PORT/" "$SITE_CONF"
  
  # Add client_max_body_size if not present
  if ! grep -q "client_max_body_size" "$SITE_CONF"; then
    sed -i "/server {/a \    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;" "$SITE_CONF"
  else
    sed -i "s/client_max_body_size .*/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/" "$SITE_CONF"
  fi
  
  # Server tokens in site
  if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
    if ! grep -q "server_tokens off;" "$SITE_CONF"; then
      sed -i "/server {/a \    server_tokens off;" "$SITE_CONF"
    fi
  fi
fi

echo "✅ Configuration applied:"
echo "   TZ: $TZ"
echo "   WEB_PORT: $WEB_PORT"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   Nginx connections: $NGINX_WORKER_CONNECTIONS | Keepalive: ${NGINX_KEEPALIVE_TIMEOUT}s"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Server tokens: $EXPOSE_SERVER_SOFTWARE"

# Start services
service php8.4-fpm start
service nginx start

# Keep container running and stream logs
tail -f /var/log/nginx/access.log /var/log/nginx/error.log
