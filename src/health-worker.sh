#!/bin/bash
# Daily health-check daemon.
# Started as a background process by the entrypoint when HEALTH_WORKER=true.
# Logs recommendations to stdout where they appear in `docker logs`.

INTERVAL=${HEALTH_WORKER_INTERVAL:-86400}
INTERNAL_PORT=${WEB_PORT:-80}

_report() {
    local TS
    TS=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    local ISSUES=0
    local RECS=""

    echo ""
    echo "======== [health-worker] ${TS} ========"

    # --- Memory ---
    if [ -f /proc/meminfo ]; then
        local TOTAL AVAIL USED PCT
        TOTAL=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo)
        AVAIL=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
        USED=$(( TOTAL - AVAIL ))
        PCT=$(( USED * 100 / TOTAL ))
        echo "  Memory:      ${PCT}% used  (${USED} / ${TOTAL} kB)"
        if [ "$PCT" -gt 90 ]; then
            echo "  [WARN] Memory pressure: ${PCT}% used"
            RECS="${RECS}\n  - Reduce PHP_FPM_PM_MAX_CHILDREN or WORKER_MEMORY_MB, or add RAM"
            ISSUES=$(( ISSUES + 1 ))
        elif [ "$PCT" -gt 75 ]; then
            echo "  [INFO] Memory utilisation is high (${PCT}%) — monitor closely"
        fi
    fi

    # --- Load average ---
    if [ -f /proc/loadavg ]; then
        local LOAD1 CORES LOAD_INT
        LOAD1=$(awk '{print $1}' /proc/loadavg)
        CORES=$(nproc 2>/dev/null || echo 1)
        LOAD_INT=$(echo "$LOAD1" | cut -d. -f1)
        echo "  Load avg:    ${LOAD1} (${CORES} cores)"
        if [ "$LOAD_INT" -gt $(( CORES * 2 )) ] 2>/dev/null; then
            echo "  [WARN] Load average is very high relative to core count"
            RECS="${RECS}\n  - Consider scaling horizontally or reducing concurrent workloads"
            ISSUES=$(( ISSUES + 1 ))
        fi
    fi

    # --- Disk space ---
    local DISK_PCT
    DISK_PCT=$(df /var/www/html 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}')
    if [ -n "$DISK_PCT" ]; then
        echo "  Disk (/var/www/html): ${DISK_PCT}% used"
        if [ "$DISK_PCT" -gt 90 ] 2>/dev/null; then
            echo "  [CRITICAL] Disk almost full!"
            RECS="${RECS}\n  - Free disk space immediately"
            ISSUES=$(( ISSUES + 1 ))
        elif [ "$DISK_PCT" -gt 75 ] 2>/dev/null; then
            echo "  [INFO] Disk usage is high (${DISK_PCT}%)"
        fi
    fi

    # --- PHP-FPM process count ---
    local FPM_MAX FPM_ACTIVE
    FPM_MAX=$(grep -m1 '^pm.max_children' /usr/local/php8.4/etc/php-fpm.d/www.conf 2>/dev/null | awk '{print $3}')
    FPM_ACTIVE=$(pgrep -c "php-fpm: pool" 2>/dev/null || echo "?")
    if [ -n "$FPM_MAX" ]; then
        echo "  PHP-FPM:     ${FPM_ACTIVE} processes (max_children=${FPM_MAX})"
        if [ "$FPM_ACTIVE" = "$FPM_MAX" ] 2>/dev/null; then
            echo "  [WARN] PHP-FPM pool at maximum capacity"
            RECS="${RECS}\n  - Increase PHP_FPM_PM_MAX_CHILDREN if RAM allows"
            ISSUES=$(( ISSUES + 1 ))
        fi
    fi

    # --- PHP-FPM status page (optional, available when OTEL or health enabled) ---
    if command -v curl >/dev/null 2>&1; then
        local FPM_JSON
        FPM_JSON=$(curl -sf "http://127.0.0.1:${INTERNAL_PORT}/php-fpm-status?json" 2>/dev/null || true)
        if [ -n "$FPM_JSON" ]; then
            local MAX_REACHED QUEUE
            MAX_REACHED=$(echo "$FPM_JSON" | grep -o '"max children reached":[0-9]*' | cut -d: -f2 || echo 0)
            QUEUE=$(echo "$FPM_JSON"       | grep -o '"listen queue":[0-9]*'          | cut -d: -f2 || echo 0)
            [ "${MAX_REACHED:-0}" -gt 0 ] 2>/dev/null && {
                echo "  [WARN] PHP-FPM max_children was hit ${MAX_REACHED} times since last restart"
                RECS="${RECS}\n  - Increase PHP_FPM_PM_MAX_CHILDREN"
                ISSUES=$(( ISSUES + 1 ))
            }
            [ "${QUEUE:-0}" -gt 0 ] 2>/dev/null && {
                echo "  [WARN] PHP-FPM listen queue has ${QUEUE} requests waiting"
                ISSUES=$(( ISSUES + 1 ))
            }
        fi
    fi

    # --- PHP error log scan ---
    local PHP_LOG="/var/log/php-fpm/error.log"
    if [ -f "$PHP_LOG" ]; then
        local ERR_COUNT
        ERR_COUNT=$(grep -cE "\[ERROR\]|\[FATAL\]|\[CRITICAL\]" "$PHP_LOG" 2>/dev/null || echo 0)
        echo "  PHP-FPM errors (log total): ${ERR_COUNT}"
        if [ "$ERR_COUNT" -gt 500 ] 2>/dev/null; then
            echo "  [WARN] PHP-FPM error log has ${ERR_COUNT} errors — review $PHP_LOG"
            RECS="${RECS}\n  - Check PHP-FPM error log: $PHP_LOG"
            ISSUES=$(( ISSUES + 1 ))
        fi
    fi

    # --- OPcache efficiency ---
    if command -v php >/dev/null 2>&1; then
        local HIT
        HIT=$(php -r '
            if (function_exists("opcache_get_status")) {
                $s = opcache_get_status(false);
                if ($s && isset($s["opcache_statistics"]["opcache_hit_rate"])) {
                    printf("%.0f", $s["opcache_statistics"]["opcache_hit_rate"]);
                }
            }
        ' 2>/dev/null || true)
        if [ -n "$HIT" ] && [ "$HIT" -gt 0 ] 2>/dev/null; then
            echo "  OPcache hit rate: ${HIT}%"
            if [ "$HIT" -lt 80 ] 2>/dev/null; then
                echo "  [INFO] OPcache hit rate is below 80%"
                RECS="${RECS}\n  - Increase PHP_OPCACHE_MAX_FILES (current: $(php -r 'echo ini_get("opcache.max_accelerated_files");' 2>/dev/null))"
            fi
        fi
    fi

    # --- Summary ---
    echo "  ---"
    if [ "$ISSUES" -eq 0 ]; then
        echo "  All checks passed. Container is healthy."
    else
        echo "  ${ISSUES} issue(s) detected. Recommendations:"
        echo -e "$RECS"
    fi
    echo "=================================================="
}

# Initial delay to let services start
sleep 60

while true; do
    _report
    sleep "$INTERVAL"
done
