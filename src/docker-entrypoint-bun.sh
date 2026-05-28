#!/bin/bash
set -e

TZ=${TZ:-UTC}
PORT=${PORT:-3000}
NODE_ENV=${NODE_ENV:-production}
BUN_ENTRY=${BUN_ENTRY:-server.js}

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
echo "$TZ" > /etc/timezone

if [ -f "/docker-entrypoint-custom.sh" ]; then
    echo "Executing custom entrypoint hook..."
    /bin/bash /docker-entrypoint-custom.sh
fi

echo "Bun runtime:"
echo "  Entry: $BUN_ENTRY | Port: $PORT | NODE_ENV: $NODE_ENV | TZ: $TZ"
echo "  Bun version: $(bun --version 2>/dev/null || echo unknown)"

exec bun run "$BUN_ENTRY"
