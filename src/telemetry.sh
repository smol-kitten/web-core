#!/bin/bash
# OpenTelemetry metrics exporter (opt-in).
# Push PHP-FPM, webserver, and system metrics to any OTLP/HTTP endpoint.
# Compatible with Grafana Cloud, Datadog, New Relic, self-hosted collectors, etc.
#
# Env vars:
#   OTEL_ENABLED=true                              - enable this exporter
#   OTEL_ENDPOINT=http://localhost:4318/v1/metrics - OTLP HTTP endpoint
#   OTEL_SERVICE_NAME=php-web                      - service.name resource attr
#   OTEL_INTERVAL=60                               - push interval (seconds)
#   OTEL_HEADERS="Authorization: Bearer tok,X-Custom: val"  - extra HTTP headers
#   OTEL_RESOURCE_ATTRS="env=prod,region=eu-west"  - extra resource attributes

[ "${OTEL_ENABLED:-false}" = "true" ] || exit 0

ENDPOINT="${OTEL_ENDPOINT:-http://localhost:4318/v1/metrics}"
SVC="${OTEL_SERVICE_NAME:-php-web}"
INTERVAL="${OTEL_INTERVAL:-60}"
INTERNAL_PORT="${WEB_PORT:-80}"
HOST="${HOSTNAME:-$(hostname 2>/dev/null || echo unknown)}"

# Build curl header args from comma-separated "Header: Value" list
_header_args() {
    [ -z "${OTEL_HEADERS:-}" ] && return
    local IFS=','
    for h in $OTEL_HEADERS; do
        printf '%s' "-H $'${h}' "
    done
}

# nanoseconds since epoch
_ts_ns() { date +%s%N 2>/dev/null || echo "0"; }

# Build a gauge metric entry
_gauge() {
    local name="$1" desc="$2" val="$3" ts="$4"
    printf '{"name":"%s","description":"%s","gauge":{"dataPoints":[{"asInt":"%s","timeUnixNano":"%s"}]}}' \
        "$name" "$desc" "$val" "$ts"
}

# Build a monotonic sum metric entry
_counter() {
    local name="$1" desc="$2" val="$3" ts="$4"
    printf '{"name":"%s","description":"%s","sum":{"dataPoints":[{"asInt":"%s","timeUnixNano":"%s"}],"isMonotonic":true,"aggregationTemporality":2}}' \
        "$name" "$desc" "$val" "$ts"
}

_collect_and_push() {
    local TS
    TS=$(_ts_ns)

    # --- System ---
    local MEM_TOTAL=0 MEM_AVAIL=0 MEM_USED=0
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo)
        MEM_AVAIL=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
        MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
    fi
    local LOAD1=0 LOAD5=0
    [ -f /proc/loadavg ] && {
        local _L1 _L5
        read _L1 _L5 _ < /proc/loadavg
        # Convert float to int×100 for OTLP integer gauge
        LOAD1=$(echo "$_L1" | awk '{printf "%d", $1*100}')
        LOAD5=$(echo "$_L5" | awk '{printf "%d", $1*100}')
    }

    # --- PHP-FPM ---
    local FPM_MAX=0 FPM_ACTIVE=0 FPM_IDLE=0 FPM_QUEUE=0 FPM_MAX_REACHED=0
    FPM_MAX=$(grep -m1 '^pm.max_children' /usr/local/php8.4/etc/php-fpm.d/www.conf 2>/dev/null | awk '{print $3}' || echo 0)
    FPM_ACTIVE=$(pgrep -c "php-fpm: pool" 2>/dev/null || echo 0)

    if command -v curl >/dev/null 2>&1; then
        local _FPM
        _FPM=$(curl -sf "http://127.0.0.1:${INTERNAL_PORT}/php-fpm-status?json" 2>/dev/null || true)
        if [ -n "$_FPM" ]; then
            FPM_ACTIVE=$(    echo "$_FPM" | grep -o '"active processes":[0-9]*'     | cut -d: -f2 || echo "$FPM_ACTIVE")
            FPM_IDLE=$(      echo "$_FPM" | grep -o '"idle processes":[0-9]*'        | cut -d: -f2 || echo 0)
            FPM_QUEUE=$(     echo "$_FPM" | grep -o '"listen queue":[0-9]*'          | cut -d: -f2 || echo 0)
            FPM_MAX_REACHED=$(echo "$_FPM" | grep -o '"max children reached":[0-9]*' | cut -d: -f2 || echo 0)
        fi
    fi

    # --- Web server (nginx stub_status) ---
    local WS_ACTIVE=0 WS_REQUESTS=0 WS_ACCEPTS=0 WS_HANDLED=0
    if command -v curl >/dev/null 2>&1; then
        local _NG
        _NG=$(curl -sf "http://127.0.0.1:${INTERNAL_PORT}/nginx-status" 2>/dev/null || true)
        if [ -n "$_NG" ]; then
            WS_ACTIVE=$(  echo "$_NG" | grep -i 'Active' | awk '{print $3}' || echo 0)
            WS_ACCEPTS=$( echo "$_NG" | awk 'NR==3{print $1}' || echo 0)
            WS_HANDLED=$( echo "$_NG" | awk 'NR==3{print $2}' || echo 0)
            WS_REQUESTS=$(echo "$_NG" | awk 'NR==3{print $3}' || echo 0)
        fi
    fi

    # --- Build resource attributes ---
    local RES_ATTRS
    RES_ATTRS=$(printf '[{"key":"service.name","value":{"stringValue":"%s"}},{"key":"host.name","value":{"stringValue":"%s"}}' "$SVC" "$HOST")

    # Append extra resource attributes from OTEL_RESOURCE_ATTRS="key=val,key2=val2"
    if [ -n "${OTEL_RESOURCE_ATTRS:-}" ]; then
        local IFS=','
        for ATTR in $OTEL_RESOURCE_ATTRS; do
            local K="${ATTR%%=*}" V="${ATTR#*=}"
            RES_ATTRS="${RES_ATTRS},{\"key\":\"${K}\",\"value\":{\"stringValue\":\"${V}\"}}"
        done
    fi
    RES_ATTRS="${RES_ATTRS}]"

    # --- Assemble payload ---
    local M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12
    M1=$(_gauge   "system.memory.used"           "Used system memory (kB)"                   "$MEM_USED"       "$TS")
    M2=$(_gauge   "system.memory.total"          "Total system memory (kB)"                  "$MEM_TOTAL"      "$TS")
    M3=$(_gauge   "system.cpu.load_1m_x100"      "1-minute load average ×100"                "$LOAD1"          "$TS")
    M4=$(_gauge   "system.cpu.load_5m_x100"      "5-minute load average ×100"                "$LOAD5"          "$TS")
    M5=$(_gauge   "phpfpm.active_processes"      "PHP-FPM active worker processes"            "$FPM_ACTIVE"     "$TS")
    M6=$(_gauge   "phpfpm.idle_processes"        "PHP-FPM idle worker processes"              "$FPM_IDLE"       "$TS")
    M7=$(_gauge   "phpfpm.max_children"          "PHP-FPM configured max_children"            "$FPM_MAX"        "$TS")
    M8=$(_gauge   "phpfpm.listen_queue"          "PHP-FPM requests waiting in queue"          "$FPM_QUEUE"      "$TS")
    M9=$(_counter "phpfpm.max_children_reached"  "Times PHP-FPM max_children was hit"         "$FPM_MAX_REACHED" "$TS")
    M10=$(_gauge  "webserver.active_connections" "Active web server connections"              "$WS_ACTIVE"      "$TS")
    M11=$(_counter "webserver.accepts_total"     "Total accepted connections"                 "$WS_ACCEPTS"     "$TS")
    M12=$(_counter "webserver.requests_total"    "Total requests handled"                     "$WS_REQUESTS"    "$TS")

    local PAYLOAD
    PAYLOAD=$(printf \
        '{"resourceMetrics":[{"resource":{"attributes":%s},"scopeMetrics":[{"scope":{"name":"php-container"},"metrics":[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s]}]}]}' \
        "$RES_ATTRS" "$M1" "$M2" "$M3" "$M4" "$M5" "$M6" "$M7" "$M8" "$M9" "$M10" "$M11" "$M12")

    # Build header array safely (no eval)
    local CURL_ARGS=(-sfX POST "$ENDPOINT" -H "Content-Type: application/json" -d "$PAYLOAD")
    if [ -n "${OTEL_HEADERS:-}" ]; then
        local IFS=','
        for H in $OTEL_HEADERS; do
            CURL_ARGS+=(-H "$H")
        done
    fi

    curl "${CURL_ARGS[@]}" >/dev/null 2>&1 || \
        echo "[telemetry] Failed to push metrics to ${ENDPOINT}" >&2
}

echo "[telemetry] Started — pushing to ${ENDPOINT} every ${INTERVAL}s (service: ${SVC})"

# Initial delay so PHP-FPM and web server are ready
sleep 10

while true; do
    _collect_and_push
    sleep "$INTERVAL"
done
