# nginx PHP Docker Images

[![Build Docker Images](https://github.com/smol-kitten/web-core/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/smol-kitten/web-core/actions/workflows/build.yml)
[![PHP Version](https://img.shields.io/badge/PHP-8.4.x-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ubuntu 25.04](https://img.shields.io/badge/Ubuntu-25.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/github/license/smol-kitten/web-core)](LICENSE)
[![GitHub Container Registry](https://img.shields.io/badge/ghcr.io-packages-blue?logo=docker)](https://github.com/smol-kitten?tab=packages&repo_name=web-core)

Production-ready Docker images for **nginx + PHP 8.4** compiled from source — no third-party PPAs, fully configurable via environment variables, automatic security updates, built-in health monitoring, HEALTHCHECK on every image, and optional OpenTelemetry metrics.

## Overview

PHP 8.4.x is compiled from source to support Ubuntu 24.04, 25.04, and 25.10 without depending on sury.org or other PPAs. A two-stage build pipeline separates the heavy compile step (builder) from the lean runtime image. The PHP version is auto-resolved from php.net on every build so you always get the latest 8.4.x patch.

Three image types are available: `nginx` (PHP + nginx), `static` (nginx-only SPA server), and `bun` (Bun.js edge runtime).

## Key Features

- **PHP 8.4.x from source** — latest patch auto-resolved, no PPAs
- **Two-stage build** — heavy builder image separate from lean runtime
- **Ubuntu 24.04, 25.04 & 25.10** — dynamic package detection handles t64 transition
- **QUICK_SET presets** — one env var tunes the stack for API / SHOP / STATIC / CMS / AUTO workloads
- **AUTO resource calculator** — derives optimal FPM workers and memory limits from actual CPU/RAM
- **Security hardening** — rate limiting, HSTS, CSP, security headers, PHP function blocking, all opt-in
- **Built-in HEALTHCHECK** — all images have Docker HEALTHCHECK configured out of the box
- **Daily health worker** — background daemon logs memory, load, disk, FPM, and OPcache health
- **OpenTelemetry metrics** — opt-in push to any OTLP/HTTP endpoint (Grafana, Datadog, New Relic, self-hosted)
- **Tiered build schedule** — monthly base mirror → weekly PHP compile → daily OS security patches
- **Trivy scanning** — container vulnerability scan runs after every build
- **Dependabot** — GitHub Actions dependencies auto-updated weekly

## Build Schedule

Builds use a three-tier cache hierarchy that minimises Docker Hub pulls and build time:

```
Docker Hub ──[monthly]──▶ ubuntu-base (GHCR mirror)
                               │
                            [weekly]──▶ prep_base  (PHP compiled from source)
                               │
                            [daily]──▶  nginx / static / bun  (apt security patches)
```

- **Monthly** (`monthly-base.yml`): mirrors `ubuntu:24.04`, `25.04`, `25.10` to `ghcr.io/smol-kitten/ubuntu-base`. This is the only point that touches Docker Hub.
- **Weekly** (`build.yml`, Sunday 04:00 UTC): compiles PHP from source using the ubuntu-base mirror; builds all runtime variants.
- **Daily** (`security-update.yml`, 02:00 UTC): rebuilds runtime images from the GHCR ubuntu-base to apply OS-level apt patches within 24 hours, without re-compiling PHP.

## Build Pipeline

### Stage 1 — prep_base (builder)

Compiles PHP 8.4.x from source with all configure flags, installs PEAR/PECL, and compiles all optional extensions (imagick, redis, memcached, ssh2). One builder per Ubuntu version.

```
prep_base:24.04   prep_base:25.04   prep_base:25.10
```

### Stage 2 — runtime variants

Copies only the required binaries and libraries from the builder. Extension `.so` files for disabled extensions are removed to keep the image lean. All 96 nginx combinations (3 Ubuntu versions × 2⁵ optional extensions) are built in parallel.

```
nginx:24.04                  nginx:25.04
nginx:24.04-redis            nginx:25.04-redis
nginx:24.04-imagick          nginx:25.04-imagick
nginx:24.04-redis-imagick    nginx:25.04-redis-imagick
... (all combinations for 24.04, 25.04, 25.10)
```

## Image Tags

### nginx + PHP

| Tag | Ubuntu |
|-----|--------|
| `nginx:24.04` | 24.04 LTS |
| `nginx:25.04` | 25.04 |
| `nginx:25.10` | 25.10 (experimental) |

Tags are suffixed with any combination of `-imagick`, `-redis`, `-memcached`, `-ssh2`, `-cron`. For example: `nginx:24.04-redis-imagick`.

### Static / SPA

| Tag | Ubuntu |
|-----|--------|
| `static:24.04` | 24.04 LTS |
| `static:25.04` | 25.04 |
| `static:25.10` | 25.10 (experimental) |

### Bun Edge Runtime

| Tag |
|-----|
| `bun:latest` |

## Built-in PHP Extensions

| Category | Extensions |
|----------|-----------|
| Core | cli, fpm, cgi, opcache |
| Database | mysqli, mysqlnd, pdo_mysql, pdo_sqlite, sqlite3 |
| Encoding | mbstring, iconv, intl |
| Compression | bz2, zip, zlib |
| Crypto | openssl, sodium, argon2 (password) |
| Web | curl, gd, xml, json |
| Other | readline, calendar, ctype, exif, fileinfo, ftp, gettext, posix, shmop, sockets, sysvmsg, sysvsem, sysvshm, tokenizer |

## Optional Extension Variants (PECL)

| Suffix | Extension | Use Case |
|--------|-----------|----------|
| `-imagick` | imagick | Image processing |
| `-redis` | redis | Redis client |
| `-memcached` | memcached | Memcached client |
| `-ssh2` | ssh2 | SSH protocol |
| `-cron` | cron daemon | Scheduled tasks |

Any combination is supported: `nginx:24.04-redis-memcached-imagick-cron`

## Build Arguments

### Dockerfile_prep_base

| Argument | Default | Description |
|----------|---------|-------------|
| `BASE_IMAGE` | `ghcr.io/smol-kitten/ubuntu-base:24.04` | Ubuntu base image (from GHCR mirror) |
| `PHP_VERSION` | `8.4.6` | PHP version to compile (overridden by CI auto-resolve) |

### Dockerfile_nginx

| Argument | Default | Description |
|----------|---------|-------------|
| `BUILDER_IMAGE` | `ghcr.io/smol-kitten/prep_base:24.04` | Builder image with compiled PHP |
| `UBUNTU_IMAGE` | `ghcr.io/smol-kitten/ubuntu-base:24.04` | Ubuntu base image from GHCR mirror |
| `INSTALL_IMAGICK` | `true` | Include imagick |
| `INSTALL_REDIS` | `false` | Include Redis |
| `INSTALL_MEMCACHED` | `false` | Include Memcached |
| `INSTALL_SSH2` | `false` | Include SSH2 |
| `INSTALL_CRON` | `false` | Include cron daemon |

### Dockerfile_static / Dockerfile_bun

| Argument | Default | Description |
|----------|---------|-------------|
| `UBUNTU_IMAGE` | `ghcr.io/smol-kitten/ubuntu-base:24.04` | Ubuntu base image from GHCR mirror |

## Example Build Commands

```sh
# Stage 1: build the builder (PHP from source)
docker build -f Dockerfile_prep_base \
  --build-arg BASE_IMAGE=ubuntu:24.04 \
  --build-arg PHP_VERSION=8.4.6 \
  -t prep_base:24.04 .

# Stage 2: build nginx runtime with Redis and imagick
docker build -f Dockerfile_nginx \
  --build-arg BUILDER_IMAGE=prep_base:24.04 \
  --build-arg UBUNTU_IMAGE=ubuntu:24.04 \
  --build-arg INSTALL_IMAGICK=true \
  --build-arg INSTALL_REDIS=true \
  -t nginx:24.04-redis-imagick .

# Build static/SPA image
docker build -f Dockerfile_static \
  --build-arg UBUNTU_IMAGE=ubuntu:24.04 \
  -t static:24.04 .

# Build Bun runtime image
docker build -f Dockerfile_bun \
  --build-arg UBUNTU_IMAGE=ubuntu:24.04 \
  -t bun:latest .
```

> **Local builds**: use `ubuntu:24.04` directly as `UBUNTU_IMAGE` / `BASE_IMAGE` when building locally. The GHCR mirror is only needed in CI to avoid Docker Hub rate limits.

## Usage

```sh
# Basic nginx container
docker run -p 8080:80 ghcr.io/smol-kitten/nginx:24.04

# API workload preset
docker run -p 8080:80 -e QUICK_SET=API ghcr.io/smol-kitten/nginx:24.04

# Auto-tune from hardware
docker run -p 8080:80 -e QUICK_SET=AUTO ghcr.io/smol-kitten/nginx:24.04

# Fully hardened production example
docker run -p 8080:80 \
  -e QUICK_SET=SHOP \
  -e FORCE_HTTPS=true \
  -e PHP_DISABLE_DANGEROUS_FUNCTIONS=true \
  -e OTEL_ENABLED=true \
  -e OTEL_ENDPOINT=https://otlp.example.com/v1/metrics \
  ghcr.io/smol-kitten/nginx:24.04

# Static / SPA site
docker run -p 8080:80 -v ./dist:/var/www/html:ro ghcr.io/smol-kitten/static:24.04

# Bun edge runtime
docker run -p 3000:3000 -v ./app:/app ghcr.io/smol-kitten/bun:latest
```

## Security

### Built-in protections

- **HEALTHCHECK** — all images have a Docker `HEALTHCHECK` configured; orchestrators (Docker Compose, Kubernetes, ECS) can detect and restart unhealthy containers automatically.
- **Security headers** — enabled by default: `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`.
- **PHP hardening** — `PHP_EXPOSE=Off` hides the PHP version from response headers. Set `PHP_DISABLE_DANGEROUS_FUNCTIONS=true` to block `exec`, `shell_exec`, `system`, `proc_open`, `popen`, `passthru`, `show_source`, `phpinfo`.
- **Session security** — `SESSION_COOKIE_HTTPONLY=On` by default; enable `SESSION_COOKIE_SECURE=On` when running behind HTTPS.
- **Trivy scanning** — automated daily vulnerability scans (CRITICAL/HIGH severity, unfixed CVEs ignored).

### Production recommendations

```yaml
# docker-compose.yml — hardened production example
services:
  web:
    image: ghcr.io/smol-kitten/nginx:24.04-imagick@sha256:<digest>
    read_only: true
    tmpfs:
      - /var/run
      - /tmp
      - /run/nginx
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
    environment:
      FORCE_HTTPS: "true"          # Set Strict-Transport-Security (deploy behind TLS terminator)
      PHP_DISABLE_DANGEROUS_FUNCTIONS: "true"
      SESSION_COOKIE_SECURE: "On"
      SECURITY_HEADERS: "true"
```

Key recommendations:

- **Run behind a TLS terminator** (nginx, Traefik, Caddy) and set `FORCE_HTTPS=true` for HSTS.
- **Pin image to digest** in production (`image: ...:24.04@sha256:...`) to prevent unexpected updates.
- **Drop capabilities** with `cap_drop: [ALL]` and add back only `NET_BIND_SERVICE` if binding to port 80.
- **Read-only filesystem** with `read_only: true`; mount tmpfs for `/var/run`, `/tmp`, and `/run/nginx` (log dirs still need write access — mount a volume for `/var/log` if needed).
- **no-new-privileges** with `security_opt: [no-new-privileges:true]` prevents privilege escalation.

## Environment Variables

All variables have sensible defaults and can be combined freely. QUICK_SET presets fill in unset variables — explicit env vars always win.

### QUICK_SET Presets

| Preset | Description |
|--------|-------------|
| `AUTO` | Calculates optimal settings from CPU, RAM, and optional traffic hints |
| `API` | High concurrency, short timeouts, rate limiting enabled |
| `SHOP` | Moderate concurrency, secure cookies, medium uploads |
| `STATIC` | Very high connections, minimal PHP, small uploads |
| `CMS` | Large uploads, longer timeouts, moderate FPM |
| `default` | Balanced general-purpose (when QUICK_SET is not set) |

```sh
docker run -e QUICK_SET=API ghcr.io/smol-kitten/nginx:24.04
```

### AUTO Resource Calculator

When `QUICK_SET=AUTO`, the entrypoint reads CPU core count and available RAM to derive optimal settings. Pass traffic hints to get an advisory warning if the hardware may not be sufficient.

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKER_MEMORY_MB` | `32` | Expected RSS per FPM worker (MB) |
| `RESERVE_RAM_PERCENT` | `30` | RAM to reserve for OS/non-PHP use |
| `EXPECTED_REQUESTS_PER_MIN` | `0` | Advisory: requests per minute |
| `EXPECTED_CONCURRENT_USERS` | `0` | Advisory: concurrent users |

The calculator outputs a report to the container log at startup, e.g.:

```
==== Auto-Tune ====
  System:      4 cores | 8192MB RAM | 5734MB available (30% reserved)
  Worker est:  32MB/worker → by-RAM=179  by-CPU=16
  Calculated:  max_children=16  start=4  min_spare=2  max_spare=8
  Calculated:  php_memory_limit=64M  nginx_connections=4096
  (Override any value with explicit env vars)
===================
```

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Container timezone |
| `WEB_PORT` | `80` | Internal listen port |
| `EXPOSE_SERVER_SOFTWARE` | `on` | Show server version in response headers (`on`/`off`) |

### PHP Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | Memory limit per request |
| `PHP_MAX_EXECUTION_TIME` | `60` | Max script execution time (s) |
| `PHP_UPLOAD_MAX_FILESIZE` | `20M` | Max upload file size |
| `PHP_POST_MAX_SIZE` | `20M` | Max POST body size |
| `PHP_MAX_INPUT_VARS` | `1000` | Max input variables |
| `PHP_DISPLAY_ERRORS` | `Off` | Display errors in browser output |
| `PHP_LOG_ERRORS` | `On` | Log errors to file |
| `ALLOW_URL_FOPEN` | `On` | Allow remote URL fopen |
| `DISABLE_FUNCTIONS` | `""` | Comma-separated list of disabled PHP functions |
| `SESSION_COOKIE_SECURE` | `Off` | Require HTTPS for session cookies |
| `SESSION_COOKIE_HTTPONLY` | `On` | Block JS access to session cookies |

### OPcache Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_OPCACHE_ENABLE` | `1` | Enable OPcache |
| `PHP_OPCACHE_MEMORY` | `128` | OPcache memory (MB) |
| `PHP_OPCACHE_MAX_FILES` | `10000` | Max cached files |

### PHP-FPM Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_FPM_PM` | `dynamic` | Process manager (`dynamic`, `static`, `ondemand`) |
| `PHP_FPM_PM_MAX_CHILDREN` | `20` | Max worker processes |
| `PHP_FPM_PM_START_SERVERS` | `5` | Workers at startup |
| `PHP_FPM_PM_MIN_SPARE_SERVERS` | `5` | Min idle workers |
| `PHP_FPM_PM_MAX_SPARE_SERVERS` | `10` | Max idle workers |

### Security Hardening

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_EXPOSE` | `Off` | Hide PHP version from `X-Powered-By` header |
| `PHP_DISABLE_DANGEROUS_FUNCTIONS` | `false` | Block `exec`, `shell_exec`, `system`, `proc_open`, etc. |
| `SECURITY_HEADERS` | `true` | Inject `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` |
| `FORCE_HTTPS` | `false` | Add `Strict-Transport-Security` header (use behind TLS terminator) |
| `CSP_HEADER` | `""` | Set `Content-Security-Policy` header (empty = disabled) |
| `RATE_LIMIT` | `false` | Enable nginx rate limiting on PHP requests |
| `RATE_LIMIT_RPS` | `10` | Allowed requests per second per IP |
| `RATE_LIMIT_BURST` | `20` | Burst allowance before rate limiting kicks in |

### Nginx-Specific Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_WORKER_CONNECTIONS` | `1024` | Max connections per worker |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | Keep-alive timeout (s) |
| `NGINX_CLIENT_MAX_BODY_SIZE` | (upload size) | Max request body size |

### Health Worker

A background daemon starts automatically (60 s after container start) and runs every `HEALTH_WORKER_INTERVAL` seconds. It logs recommendations to stdout where they appear in `docker logs`.

Checks performed:
- Memory pressure (warn >75%, critical >90%)
- Load average relative to core count
- Disk usage at `/var/www/html`
- PHP-FPM process count vs `max_children`
- PHP-FPM status page: listen queue, max_children_reached events
- PHP error log error count
- OPcache hit rate

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_WORKER` | `true` | Enable the health worker daemon |
| `HEALTH_WORKER_INTERVAL` | `86400` | Check interval in seconds (default: daily) |

Sample output:
```
======== [health-worker] 2026-05-26 12:00:00 UTC ========
  Memory:      45% used  (3686400 / 8192000 kB)
  Load avg:    0.8 (4 cores)
  Disk (/var/www/html): 22% used
  PHP-FPM:     6 processes (max_children=20)
  OPcache hit rate: 94%
  ---
  All checks passed. Container is healthy.
==================================================
```

### OpenTelemetry Metrics (opt-in)

Push system and PHP-FPM metrics to any OTLP/HTTP endpoint. Compatible with Grafana Cloud, Datadog, New Relic, self-hosted OpenTelemetry Collectors, and more.

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_ENABLED` | `false` | Enable the telemetry exporter |
| `OTEL_ENDPOINT` | `http://localhost:4318/v1/metrics` | OTLP/HTTP endpoint URL |
| `OTEL_SERVICE_NAME` | `php-web` | `service.name` resource attribute |
| `OTEL_INTERVAL` | `60` | Push interval in seconds |
| `OTEL_HEADERS` | `""` | Extra HTTP headers as `"Header: Value,Header2: Value2"` |
| `OTEL_RESOURCE_ATTRS` | `""` | Extra resource attributes as `"key=val,key2=val2"` |

**Metrics exported:**

| Metric | Type | Description |
|--------|------|-------------|
| `system.memory.used` | gauge | Used system memory (kB) |
| `system.memory.total` | gauge | Total system memory (kB) |
| `system.cpu.load_1m_x100` | gauge | 1-minute load average ×100 |
| `system.cpu.load_5m_x100` | gauge | 5-minute load average ×100 |
| `phpfpm.active_processes` | gauge | Active FPM workers |
| `phpfpm.idle_processes` | gauge | Idle FPM workers |
| `phpfpm.max_children` | gauge | Configured `max_children` |
| `phpfpm.listen_queue` | gauge | Requests queued waiting for a worker |
| `phpfpm.max_children_reached` | counter | Times `max_children` limit was hit |
| `webserver.active_connections` | gauge | Active nginx connections |
| `webserver.accepts_total` | counter | Total accepted connections |
| `webserver.requests_total` | counter | Total requests handled |

**Grafana Cloud example:**
```sh
docker run -p 8080:80 \
  -e OTEL_ENABLED=true \
  -e OTEL_ENDPOINT=https://otlp-gateway-prod-us-east-0.grafana.net/otlp/v1/metrics \
  -e OTEL_HEADERS="Authorization: Basic <base64-token>" \
  -e OTEL_SERVICE_NAME=my-app \
  -e OTEL_RESOURCE_ATTRS="env=prod,region=us-east-1" \
  ghcr.io/smol-kitten/nginx:24.04
```

## QUICK_SET Preset Reference

### API
High concurrency, short timeouts, rate limiting on by default.
```
PHP_MEMORY_LIMIT=256M         PHP_MAX_EXECUTION_TIME=30
PHP_UPLOAD_MAX_FILESIZE=10M   PHP_POST_MAX_SIZE=10M
NGINX_WORKER_CONNECTIONS=2048 PHP_FPM_PM_MAX_CHILDREN=50
EXPOSE_SERVER_SOFTWARE=off    RATE_LIMIT=true
```

### SHOP
Secure cookies, moderate concurrency, medium uploads.
```
PHP_MEMORY_LIMIT=512M         PHP_MAX_EXECUTION_TIME=60
PHP_UPLOAD_MAX_FILESIZE=20M   PHP_POST_MAX_SIZE=20M
NGINX_WORKER_CONNECTIONS=1024 PHP_FPM_PM_MAX_CHILDREN=30
EXPOSE_SERVER_SOFTWARE=off    SESSION_COOKIE_SECURE=On
```

### STATIC
Maximum connections, minimal PHP, small uploads.
```
PHP_MEMORY_LIMIT=128M         PHP_MAX_EXECUTION_TIME=15
PHP_UPLOAD_MAX_FILESIZE=2M    PHP_POST_MAX_SIZE=2M
NGINX_WORKER_CONNECTIONS=4096 PHP_FPM_PM_MAX_CHILDREN=10
EXPOSE_SERVER_SOFTWARE=off
```

### CMS
Large uploads, longer timeouts, balanced FPM.
```
PHP_MEMORY_LIMIT=384M         PHP_MAX_EXECUTION_TIME=90
PHP_UPLOAD_MAX_FILESIZE=64M   PHP_POST_MAX_SIZE=64M
NGINX_WORKER_CONNECTIONS=1024 PHP_FPM_PM_MAX_CHILDREN=25
EXPOSE_SERVER_SOFTWARE=off
```

## Docker Compose Example

```yaml
services:
  web:
    image: ghcr.io/smol-kitten/nginx:24.04-redis
    environment:
      QUICK_SET: AUTO
      WORKER_MEMORY_MB: 48
      RESERVE_RAM_PERCENT: 25
      TZ: Europe/Berlin
      SECURITY_HEADERS: "true"
      FORCE_HTTPS: "true"
      OTEL_ENABLED: "true"
      OTEL_ENDPOINT: http://otel-collector:4318/v1/metrics
      OTEL_SERVICE_NAME: my-app
    ports:
      - "80:80"
    volumes:
      - ./app:/var/www/html
```

## Customizing the Image

### Using as a Base Image

```dockerfile
FROM ghcr.io/smol-kitten/nginx:24.04-imagick

COPY ./app /var/www/html

# Optional: override nginx site config
COPY ./my-site.conf /etc/nginx/sites-enabled/nginx.conf

# Optional: run custom init before services start
COPY ./init.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh
```

### Custom Entrypoint Hook

The nginx image executes `/docker-entrypoint-custom.sh` (if it exists) after env var configuration but before PHP-FPM and the web server start. Use it to install packages, write config files, or set up anything your application needs.

```bash
#!/bin/bash
# /docker-entrypoint-custom.sh

# Install extra packages
apt-get update && apt-get install -y --no-install-recommends vim

# Extra PHP INI settings
echo "zend_extension=xdebug.so" > /usr/local/php8.4/etc/conf.d/20-xdebug.ini

# Ensure writable dirs
mkdir -p /var/www/html/cache
chown www-data:www-data /var/www/html/cache
```

### Cron Jobs

Images built with `-cron` include the cron daemon, started automatically after the web server.

```dockerfile
FROM ghcr.io/smol-kitten/nginx:24.04-cron

COPY ./app /var/www/html

# Add a crontab entry
RUN echo "*/5 * * * * www-data /usr/local/bin/php /var/www/html/cron.php >> /var/log/cron.log 2>&1" \
    >> /etc/crontab
```

Or mount a crontab file:
```sh
docker run -v ./my-crontab:/etc/cron.d/app:ro ghcr.io/smol-kitten/nginx:24.04-cron
```

## Internal Monitoring Endpoints

These endpoints are accessible only from loopback (`127.0.0.1`) inside the container.

| Endpoint | Description |
|----------|-------------|
| `/nginx-status` | nginx `stub_status` |
| `/php-fpm-status` | PHP-FPM status page (JSON: `?json`) |

## Key File Locations

| Path | Description |
|------|-------------|
| `/var/www/html/` | Web root |
| `/usr/local/bin/php` | PHP binary (symlink) |
| `/usr/local/php8.4/etc/php.ini` | PHP configuration |
| `/usr/local/php8.4/etc/php-fpm.conf` | PHP-FPM main config |
| `/usr/local/php8.4/etc/php-fpm.d/www.conf` | PHP-FPM pool config |
| `/usr/local/php8.4/etc/conf.d/` | PHP extension INI files |
| `/var/run/php/php8.4-fpm.sock` | PHP-FPM Unix socket |
| `/etc/nginx/nginx.conf` | Main nginx config |
| `/etc/nginx/sites-enabled/nginx.conf` | nginx site config |
| `/docker-entrypoint-custom.sh` | Custom init hook (optional) |

## GitHub Actions Workflows

### `monthly-base.yml` — Ubuntu Base Mirror

Triggers: 1st of each month 03:00 UTC, manual dispatch.

Mirrors `ubuntu:24.04`, `25.04`, `25.10` from Docker Hub to `ghcr.io/smol-kitten/ubuntu-base`. This is the only workflow that ever contacts Docker Hub — all other builds use the GHCR mirror.

### `build.yml` — Full Build Pipeline

Triggers: push to `main`, weekly Sunday 04:00 UTC, manual dispatch.

1. **resolve-php-version** — fetches latest PHP 8.4.x from php.net API (override via `php_version_override` input)
2. **build-builder** — builds `prep_base` images (3 Ubuntu versions, `max-parallel: 3`)
3. **build-nginx** — builds all 96 nginx runtime variants (`max-parallel: 20`)
4. **build-static** — builds static/SPA images (3 Ubuntu versions)
5. **build-bun** — builds the Bun edge runtime image
6. **scan-images** — runs Trivy vulnerability scan on sample images
7. **cleanup-untagged** — removes untagged/SHA-only images from the registry

### `security-update.yml` — Daily OS Patch

Triggers: daily 02:00 UTC, manual dispatch.

Rebuilds runtime images using the ubuntu-base GHCR mirror so OS-level security patches are applied within 24 hours without recompiling PHP. Runs Trivy scan after.

### `pr-test.yml` — Pull Request CI

Triggers: pull requests to `main`, manual dispatch.

Jobs:
- **lint** — Dockerfile linting with hadolint on all 4 Dockerfiles (uses `.hadolint.yaml`)
- **check-prep-base** — probes registry to see if a builder image exists
- **test-build-nginx** — test-builds the nginx image (skipped if builder not available)
- **smoke-test** — starts a container, verifies HTTP 200 from nginx

### Dependabot

`.github/dependabot.yml` auto-updates GitHub Actions versions weekly (Mondays).

## Source Files

| File | Description |
|------|-------------|
| `Dockerfile_prep_base` | Builds PHP from source; output is the builder image |
| `Dockerfile_nginx` | Assembles nginx runtime image from builder |
| `Dockerfile_static` | Lightweight nginx image for SPA/static sites (no PHP) |
| `Dockerfile_bun` | Bun.js edge runtime image |
| `src/entrypoint-common.sh` | Shared functions sourced by entrypoints |
| `src/docker-entrypoint-nginx.sh` | nginx entrypoint |
| `src/docker-entrypoint-static.sh` | Static server entrypoint |
| `src/docker-entrypoint-bun.sh` | Bun entrypoint |
| `src/auto-tune.sh` | AUTO resource calculator |
| `src/health-worker.sh` | Background health monitoring daemon |
| `src/telemetry.sh` | OpenTelemetry metrics exporter |
| `src/nginx/nginx.conf` | nginx main config template |
| `src/nginx/site.conf` | nginx site config template (PHP) |
| `src/nginx/nginx-static.conf` | nginx main config for static images |
| `src/nginx/site-static.conf` | nginx site config for static images |
| `.hadolint.yaml` | Dockerfile linting config |
| `.github/dependabot.yml` | Dependabot auto-update config |

## Troubleshooting

**PHP compilation fails** — check that all build dependencies are installed in `Dockerfile_prep_base`.

**libzip package not found** — the build auto-detects `libzip4` (24.04) or `libzip5` (25.04/25.10) using `apt-cache search`.

**t64 package errors on 25.10** — dynamic package detection handles `libxml2-16`, `libcurl4t64`, `libssl3t64`, etc.

**test-build jobs skipped on PR** — normal behaviour when `prep_base` has not yet been built for the branch. The `check-prep-base` job gates them; a successful merge to main will build the builder and enable them.

**PHP-FPM workers maxing out** — set `QUICK_SET=AUTO` or increase `PHP_FPM_PM_MAX_CHILDREN`. The health worker will warn you when the pool is at capacity.

**OPcache hit rate below 80%** — increase `PHP_OPCACHE_MAX_FILES` (current value shown in the health worker log).

**OpenTelemetry push failures** — check `OTEL_ENDPOINT` reachability and `OTEL_HEADERS` auth. Failed pushes are logged to stderr but do not affect container operation.
