#!/bin/bash
# Resource-aware settings calculator.
# Sourced by entrypoints when QUICK_SET=AUTO.
# Sets PHP-FPM/webserver defaults from hardware + traffic hints.
# User-provided env vars always take precedence (set via := not =).

auto_tune() {
    local CORES TOTAL_RAM_MB AVAIL_MB
    CORES=$(nproc 2>/dev/null || echo 1)
    TOTAL_RAM_MB=$(awk '/^MemTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 512)

    local WORKER_MB=${WORKER_MEMORY_MB:-32}
    local RESERVE=${RESERVE_RAM_PERCENT:-30}
    local RPM=${EXPECTED_REQUESTS_PER_MIN:-0}
    local USERS=${EXPECTED_CONCURRENT_USERS:-0}

    AVAIL_MB=$(( TOTAL_RAM_MB * (100 - RESERVE) / 100 ))
    [ "$AVAIL_MB" -lt 64 ] && AVAIL_MB=64

    # Worker count limits
    local BY_RAM=$(( AVAIL_MB / WORKER_MB ))
    local BY_CPU=$(( CORES * 4 ))
    [ "$BY_RAM" -lt 1 ] && BY_RAM=1
    [ "$BY_CPU" -lt 1 ] && BY_CPU=1
    local CALC=$(( BY_RAM < BY_CPU ? BY_RAM : BY_CPU ))

    # Traffic hints (advisory — log but don't cap workers below CALC)
    local BY_TRAFFIC=0 BY_USERS=0 TRAFFIC_WARN=""
    if [ "$RPM" -gt 0 ] 2>/dev/null; then
        BY_TRAFFIC=$(( (RPM + 599) / 600 ))   # ~10 req/s per worker
        [ "$BY_TRAFFIC" -lt 1 ] && BY_TRAFFIC=1
        [ "$BY_TRAFFIC" -gt "$CALC" ] && \
            TRAFFIC_WARN="Traffic hints need ${BY_TRAFFIC} workers; RAM/CPU cap at ${CALC}"
    fi
    if [ "$USERS" -gt 0 ] 2>/dev/null; then
        BY_USERS=$(( (USERS + 24) / 25 ))     # ~25 concurrent users per worker
        [ "$BY_USERS" -lt 1 ] && BY_USERS=1
        [ "$BY_USERS" -gt "$CALC" ] && \
            TRAFFIC_WARN="User count hints need ${BY_USERS} workers; RAM/CPU cap at ${CALC}"
    fi

    # Derived FPM settings
    local START=$(( CALC / 4 )); [ "$START" -lt 2 ] && START=2
    local MIN_SP=$(( CALC / 8 )); [ "$MIN_SP" -lt 1 ] && MIN_SP=1
    local MAX_SP=$(( CALC / 2 )); [ "$MAX_SP" -lt 2 ] && MAX_SP=2

    # Nginx connections: cores * 1024, capped sensibly
    local NG_CONNS=$(( CORES * 1024 ))
    [ "$NG_CONNS" -gt 65535 ] && NG_CONNS=65535
    [ "$NG_CONNS" -lt 1024  ] && NG_CONNS=1024

    # PHP memory: 2× worker_memory_mb (heuristic: RSS vs limit differ)
    local MEM_LIMIT=$(( WORKER_MB * 2 ))
    [ "$MEM_LIMIT" -lt 64 ] && MEM_LIMIT=64

    echo "==== Auto-Tune ===="
    echo "  System:      ${CORES} cores | ${TOTAL_RAM_MB}MB RAM | ${AVAIL_MB}MB available (${RESERVE}% reserved)"
    echo "  Worker est:  ${WORKER_MB}MB/worker → by-RAM=${BY_RAM}  by-CPU=${BY_CPU}"
    [ "$BY_TRAFFIC" -gt 0 ] && echo "  Traffic hint: ${BY_TRAFFIC} workers for ${RPM} req/min"
    [ "$BY_USERS"   -gt 0 ] && echo "  Users hint:   ${BY_USERS} workers for ${USERS} concurrent users"
    [ -n "$TRAFFIC_WARN"  ] && echo "  *** WARN: ${TRAFFIC_WARN} ***"
    echo "  Calculated:  max_children=${CALC}  start=${START}  min_spare=${MIN_SP}  max_spare=${MAX_SP}"
    echo "  Calculated:  php_memory_limit=${MEM_LIMIT}M  nginx_connections=${NG_CONNS}"
    echo "  (Override any value with explicit env vars)"
    echo "==================="

    # Set only if not already defined
    : "${PHP_FPM_PM_MAX_CHILDREN:=$CALC}"
    : "${PHP_FPM_PM_START_SERVERS:=$START}"
    : "${PHP_FPM_PM_MIN_SPARE_SERVERS:=$MIN_SP}"
    : "${PHP_FPM_PM_MAX_SPARE_SERVERS:=$MAX_SP}"
    : "${PHP_MEMORY_LIMIT:=${MEM_LIMIT}M}"
    : "${NGINX_WORKER_CONNECTIONS:=$NG_CONNS}"
    : "${APACHE_MAX_REQUEST_WORKERS:=$CALC}"

    # Export so children (health-worker, telemetry) see the values
    export PHP_FPM_PM_MAX_CHILDREN PHP_FPM_PM_START_SERVERS \
           PHP_FPM_PM_MIN_SPARE_SERVERS PHP_FPM_PM_MAX_SPARE_SERVERS \
           PHP_MEMORY_LIMIT NGINX_WORKER_CONNECTIONS APACHE_MAX_REQUEST_WORKERS
}
