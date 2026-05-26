#!/bin/bash
# Shared entrypoint functions sourced by nginx and apache entrypoints.
# Caller must export all PHP_* / PHP_FPM_* / TZ env vars before sourcing.

set_timezone() {
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "$TZ" > /etc/timezone
}

configure_php() {
    local ini="/usr/local/php8.4/etc/php.ini"
    [ -f "$ini" ] || return 0

    sed -i "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/"                         "$ini"
    sed -i "s/^max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/"         "$ini"
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/"     "$ini"
    sed -i "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE}/"                       "$ini"
    sed -i "s/^max_input_vars = .*/max_input_vars = ${PHP_MAX_INPUT_VARS}/"                    "$ini"
    sed -i "s/^display_errors = .*/display_errors = ${PHP_DISPLAY_ERRORS}/"                   "$ini"
    sed -i "s/^log_errors = .*/log_errors = ${PHP_LOG_ERRORS}/"                               "$ini"
    sed -i "s/^allow_url_fopen = .*/allow_url_fopen = ${ALLOW_URL_FOPEN}/"                    "$ini"
    sed -i "s/^session.cookie_secure = .*/session.cookie_secure = ${SESSION_COOKIE_SECURE}/"   "$ini"
    sed -i "s/^session.cookie_httponly = .*/session.cookie_httponly = ${SESSION_COOKIE_HTTPONLY}/" "$ini"

    if [ -n "$DISABLE_FUNCTIONS" ]; then
        sed -i "s/^disable_functions = .*/disable_functions = ${DISABLE_FUNCTIONS}/" "$ini"
    fi

    sed -i "s/^opcache.enable=.*/opcache.enable=${PHP_OPCACHE_ENABLE}/"                         "$ini"
    sed -i "s/^opcache.memory_consumption=.*/opcache.memory_consumption=${PHP_OPCACHE_MEMORY}/" "$ini"
    sed -i "s/^opcache.max_accelerated_files=.*/opcache.max_accelerated_files=${PHP_OPCACHE_MAX_FILES}/" "$ini"
}

configure_fpm() {
    local pool="/usr/local/php8.4/etc/php-fpm.d/www.conf"
    [ -f "$pool" ] || return 0

    sed -i "s/^pm = .*/pm = ${PHP_FPM_PM}/"                                          "$pool"
    sed -i "s/^pm.max_children = .*/pm.max_children = ${PHP_FPM_PM_MAX_CHILDREN}/"   "$pool"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = ${PHP_FPM_PM_START_SERVERS}/" "$pool"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = ${PHP_FPM_PM_MIN_SPARE_SERVERS}/" "$pool"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = ${PHP_FPM_PM_MAX_SPARE_SERVERS}/" "$pool"
}

run_custom_hook() {
    if [ -f "/docker-entrypoint-custom.sh" ]; then
        echo "Executing custom entrypoint hook: /docker-entrypoint-custom.sh"
        /bin/bash /docker-entrypoint-custom.sh
    fi
}

start_fpm() {
    echo "Starting PHP-FPM..."
    /usr/local/bin/php-fpm --fpm-config /usr/local/php8.4/etc/php-fpm.conf --daemonize
}

start_cron_if_installed() {
    if command -v cron >/dev/null 2>&1; then
        echo "Starting Cron..."
        service cron start
    fi
}
