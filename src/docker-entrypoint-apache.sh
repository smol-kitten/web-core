#!/bin/bash
set -e

#######################################################
# Apache + PHP-FPM Entrypoint with Environment Config
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
    # Default balanced config
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

# Apache settings
APACHE_MAX_REQUEST_WORKERS=${APACHE_MAX_REQUEST_WORKERS:-150}
APACHE_KEEPALIVE=${APACHE_KEEPALIVE:-On}
APACHE_KEEPALIVE_TIMEOUT=${APACHE_KEEPALIVE_TIMEOUT:-5}
APACHE_MAX_KEEPALIVE_REQUESTS=${APACHE_MAX_KEEPALIVE_REQUESTS:-100}

# PHP-FPM settings
PHP_FPM_PM=${PHP_FPM_PM:-dynamic}
PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-20}
PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-5}
PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-10}

echo "🐾 Configuring apache + PHP-FPM with QUICK_SET=${QUICK_SET:-default}"

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

# --- Configure Apache ---
# Update ports.conf for WEB_PORT
PORTS_CONF="/etc/apache2/ports.conf"
if [ -f "$PORTS_CONF" ]; then
  sed -i "s/Listen [0-9]*/Listen $WEB_PORT/" "$PORTS_CONF"
fi

# Update site config for port
SITE_CONF="/etc/apache2/sites-enabled/000-default.conf"
if [ -f "$SITE_CONF" ]; then
  sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:$WEB_PORT>/" "$SITE_CONF"
fi

# Apache MPM event configuration
MPM_CONF="/etc/apache2/mods-available/mpm_event.conf"
if [ -f "$MPM_CONF" ]; then
  sed -i "s/MaxRequestWorkers.*/MaxRequestWorkers $APACHE_MAX_REQUEST_WORKERS/" "$MPM_CONF"
fi

# Apache security/performance config
APACHE_CONF="/etc/apache2/apache2.conf"
if [ -f "$APACHE_CONF" ]; then
  # Server tokens
  if [ "$EXPOSE_SERVER_SOFTWARE" = "off" ]; then
    if ! grep -q "ServerTokens" "$APACHE_CONF"; then
      echo "ServerTokens Prod" >> "$APACHE_CONF"
      echo "ServerSignature Off" >> "$APACHE_CONF"
    else
      sed -i "s/ServerTokens.*/ServerTokens Prod/" "$APACHE_CONF"
      sed -i "s/ServerSignature.*/ServerSignature Off/" "$APACHE_CONF"
    fi
  fi
  
  # KeepAlive settings
  if ! grep -q "KeepAlive" "$APACHE_CONF"; then
    echo "KeepAlive $APACHE_KEEPALIVE" >> "$APACHE_CONF"
    echo "KeepAliveTimeout $APACHE_KEEPALIVE_TIMEOUT" >> "$APACHE_CONF"
    echo "MaxKeepAliveRequests $APACHE_MAX_KEEPALIVE_REQUESTS" >> "$APACHE_CONF"
  else
    sed -i "s/KeepAlive .*/KeepAlive $APACHE_KEEPALIVE/" "$APACHE_CONF"
    sed -i "s/KeepAliveTimeout .*/KeepAliveTimeout $APACHE_KEEPALIVE_TIMEOUT/" "$APACHE_CONF"
    sed -i "s/MaxKeepAliveRequests .*/MaxKeepAliveRequests $APACHE_MAX_KEEPALIVE_REQUESTS/" "$APACHE_CONF"
  fi
fi

echo "✅ Configuration applied:"
echo "   TZ: $TZ"
echo "   WEB_PORT: $WEB_PORT"
echo "   PHP Memory: $PHP_MEMORY_LIMIT | Execution: ${PHP_MAX_EXECUTION_TIME}s | Upload: $PHP_UPLOAD_MAX_FILESIZE"
echo "   Apache workers: $APACHE_MAX_REQUEST_WORKERS | KeepAlive: ${APACHE_KEEPALIVE_TIMEOUT}s"
echo "   PHP-FPM: $PHP_FPM_PM (max_children=$PHP_FPM_PM_MAX_CHILDREN)"
echo "   Server tokens: $EXPOSE_SERVER_SOFTWARE"

# Start services
service php8.4-fpm start
service apache2 start

# Keep container running and stream logs
tail -f /var/log/apache2/access.log /var/log/apache2/error.log
