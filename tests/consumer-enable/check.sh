#!/bin/bash
# Checks the core image and the consumer path (webcore-enable, webcore-apt).
#
#   tests/consumer-enable/check.sh <core-image>
#
# <core-image> is a local image built from Dockerfile_nginx with every INSTALL_* argument false.
# Run from the repository root. Needs docker. Exits non-zero on the first failed check.

set -euo pipefail

CORE="${1:?usage: check.sh <core-image>}"
CONSUMER="webcore-consumer-test:$$"
EXTENSIONS="imagick redis memcached ssh2"
# The docker-container builder that setup-buildx-action selects cannot see local images.
BUILDER="${CHECK_BUILDER:-default}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok:   $*"; }
cleanup() { docker image rm -f "$CONSUMER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ---- core image -------------------------------------------------------------
mods=$(docker run --rm "$CORE" php -m 2>&1)
grep -qi 'warning' <<<"$mods" && fail "core: php -m prints a warning: $(grep -i warning <<<"$mods" | head -2)"
for e in $EXTENSIONS; do
    grep -qix "$e" <<<"$mods" && fail "core: $e is loaded, the core must load no optional extension"
done
ok "core loads none of: $EXTENSIONS"

docker run --rm "$CORE" sh -c 'command -v cron' >/dev/null 2>&1 && fail "core: cron is installed"
list=$(docker run --rm "$CORE" webcore-enable --list)
[ "$(grep -c ' off$' <<<"$list")" = "5" ] || fail "core: webcore-enable --list does not show 5 features off: $list"
ok "core: webcore-enable --list shows 5 features off"

if out=$(docker run --rm "$CORE" webcore-enable imagick nosuch 2>&1); then
    fail "core: an unknown feature did not fail"
fi
grep -q "unknown feature 'nosuch'" <<<"$out" || fail "core: unknown feature gave no clear message: $out"
ok "core: unknown feature stops with a clear message"

docker run --rm "$CORE" webcore-enable >/dev/null 2>&1 && fail "core: no argument did not fail"
ok "core: no argument stops with the usage text"

# ---- consumer image ---------------------------------------------------------
docker buildx build --builder "$BUILDER" --load \
    --build-arg "CORE_IMAGE=$CORE" -t "$CONSUMER" -f tests/consumer-enable/Dockerfile .

mods=$(docker run --rm "$CONSUMER" php -m 2>&1)
grep -qi 'warning' <<<"$mods" && fail "consumer: php -m prints a warning: $(grep -i warning <<<"$mods" | head -2)"
for e in $EXTENSIONS; do
    grep -qix "$e" <<<"$mods" || fail "consumer: $e is not loaded"
done
ok "consumer loads: $EXTENSIONS"

docker run --rm "$CONSUMER" php -r '
    $i = new Imagick(); $i->newImage(4, 4, "red"); $i->setImageFormat("png");
    if (strlen($i->getImageBlob()) < 8) { fwrite(STDERR, "imagick wrote no image\n"); exit(1); }
    new Redis(); new Memcached();
    if (!function_exists("ssh2_connect")) { fwrite(STDERR, "ssh2_connect missing\n"); exit(1); }
' || fail "consumer: an extension does not work"
ok "consumer: imagick writes a PNG; Redis, Memcached and ssh2 are usable"

docker run --rm "$CONSUMER" sh -c 'command -v cron && command -v jq' >/dev/null || fail "consumer: cron or jq is missing"
ok "consumer: cron (feature) and jq (webcore-apt) are installed"

list=$(docker run --rm "$CONSUMER" webcore-enable --list)
[ "$(grep -c ' on$' <<<"$list")" = "5" ] || fail "consumer: webcore-enable --list does not show 5 features on: $list"
[ "$(docker run --rm "$CONSUMER" sh -c 'sort -u /etc/webcore/enabled | wc -l')" = "5" ] || fail "consumer: /etc/webcore/enabled does not list 5 features"
ok "consumer: --list and /etc/webcore/enabled show 5 features on"

again=$(docker run --rm "$CONSUMER" webcore-enable imagick cron 2>&1) || fail "consumer: a second enable failed: $again"
grep -q 'nothing to do' <<<"$again" || fail "consumer: a second enable was not a no-op: $again"
ok "consumer: a second enable is a no-op"

docker run --rm "$CONSUMER" sh -c 'test -z "$(ls /var/lib/apt/lists 2>/dev/null)"' || fail "consumer: apt lists were left in the image"
ok "consumer: no apt lists left in the image"

docker run --rm "$CONSUMER" nginx -t >/dev/null 2>&1 || fail "consumer: nginx -t fails"
ok "consumer: nginx -t passes"
echo "All checks passed."
