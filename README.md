# nginx & Apache PHP Docker Images

[![Build Docker Images](https://github.com/smol-kitten/web-core/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/smol-kitten/web-core/actions/workflows/docker-build.yml)
[![PHP Version](https://img.shields.io/badge/PHP-8.4.1-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ubuntu 25.04](https://img.shields.io/badge/Ubuntu-25.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/github/license/smol-kitten/web-core)](LICENSE)
[![GitHub Container Registry](https://img.shields.io/badge/ghcr.io-packages-blue?logo=docker)](https://github.com/smol-kitten?tab=packages&repo_name=web-core)

## Overview
This project builds custom Docker images for Nginx/Apache + PHP 8.4.1 using a multi-stage build approach for optimal caching and flexibility. **PHP 8.4.1 is compiled from source** to support Ubuntu 24.04, 25.04, and 25.10 without dependency on third-party PPAs. Images are built automatically using GitHub Actions with a base → web → variants pipeline.

Both nginx and apache images include comprehensive runtime configuration via environment variables, including **QUICK_SET presets** for common workload types (API, SHOP, STATIC, CMS).

## Key Features
- **PHP 8.4.1 built from source** - No dependency on sury.org or other PPAs
- **Ubuntu 24.04, 25.04 & 25.10 support** - Dynamic package detection handles t64 transition in 25.10
- **Built-in extensions** - MySQL (mysqli, pdo_mysql), SQLite (pdo_sqlite, sqlite3), and core extensions
- **Optional extensions via PECL** - Redis, Memcached, SSH2, Imagick compiled on-demand
- **Multi-stage builds** - Optimized layer caching and minimal final image size

## Build Pipeline
1. **prep_base:24.04, prep_base:25.04, prep_base:25.10** - Ubuntu base with PHP 8.4.1 compiled from source
   - PHP configure flags: GD, Intl, MySQL, SQLite, FPM, Sodium, Argon2, and more
   - PECL/PEAR 1.10.16 installed for extension management
2. **prep_nginx:*, prep_apache2:*** - Adds web server + PHP runtime libraries (dynamic package detection for t64 in 25.10)
3. **prep_*_imagick:*** - Pre-compiles imagick extension (10+ min build)
4. **nginx:*, apache:*** - Final variants with optional extensions (redis, memcached, ssh2, imagick)

## Image Variants
Final images are tagged based on enabled extensions.

**Base versions:**
- `nginx:24.04` - Ubuntu 24.04 with PHP 8.4.1 (no optional extensions)
- `nginx:25.04` - Ubuntu 25.04 with PHP 8.4.1 (no optional extensions)
- `nginx:25.10` - Ubuntu 25.10 with PHP 8.4.1 (no optional extensions)
- `apache2:24.04` - Ubuntu 24.04 with PHP 8.4.1 (no optional extensions)
- `apache2:25.04` - Ubuntu 25.04 with PHP 8.4.1 (no optional extensions)
- `apache2:25.10` - Ubuntu 25.10 with PHP 8.4.1 (no optional extensions)

**Built-in PHP Extensions:**
- Core: CLI, FPM, CGI, opcache
- Database: mysqli, mysqlnd, pdo_mysql, pdo_sqlite, sqlite3
- Encoding: mbstring, iconv, intl
- Compression: bz2, zip, zlib
- Crypto: openssl, sodium, password (argon2)
- Web: curl, gd, xml, json
- Other: readline, calendar, ctype, exif, fileinfo, ftp, gettext, posix, shmop, sockets, sysvmsg, sysvsem, sysvshm, tokenizer

**Optional Extension Variants** (installed via PECL or apt):
- `nginx:24.04-imagick` - With imagick for image processing
- `nginx:24.04-redis` - With Redis client
- `nginx:24.04-memcached` - With Memcached client
- `nginx:24.04-ssh2` - With SSH2 protocol support
- `nginx:24.04-cron` - With cron daemon for scheduled tasks
- (Any combination of: imagick, redis, memcached, ssh2, cron)

## Build Arguments

### Dockerfile_prep_base
- `BASE_IMAGE` (default: `ubuntu:24.04`): Ubuntu base image version

### Dockerfile_prep_nginx
- `BASE_IMAGE` (default: `prep_base:24.04`): Base prep image to build from

### Dockerfile_prep_apache2
- `BASE_IMAGE` (default: `prep_base:24.04`): Base prep image to build from

### Dockerfile_specific
- `BASE_IMAGE` (default: `prep_nginx_imagick:24.04` or `prep_apache2_imagick:24.04`): Base prep image to build from
- `INSTALL_IMAGICK` (default: `true`): Include imagick extension (pre-compiled in prep_*_imagick images)
- `INSTALL_REDIS` (default: `true`): Include Redis extension via PECL
- `INSTALL_MEMCACHED` (default: `true`): Include Memcached extension via PECL
- `INSTALL_SSH2` (default: `true`): Include SSH2 extension via PECL
- `INSTALL_CRON` (default: `false`): Include cron daemon for scheduled tasks

## Example Build Commands

**Manual multi-stage build:**
```sh
# 1. Build prep base (PHP 8.4.1 from source - takes ~3 minutes)
docker build -f Dockerfile_prep_base --build-arg BASE_IMAGE=ubuntu:24.04 -t prep_base:24.04 .

# 2. Build prep nginx
docker build -f Dockerfile_prep_nginx --build-arg BASE_IMAGE=prep_base:24.04 -t prep_nginx:24.04 .

# 2b. Build prep apache2
docker build -f Dockerfile_prep_apache2 --build-arg BASE_IMAGE=prep_base:24.04 -t prep_apache2:24.04 .

# 3. Build prep nginx with imagick (optional, takes ~10 minutes)
docker build -f Dockerfile_prep_nginx_imagick --build-arg BASE_IMAGE=prep_nginx:24.04 -t prep_nginx_imagick:24.04 .

# 4. Build specific variant (nginx)
docker build -f Dockerfile_specific \
  --build-arg BASE_IMAGE=prep_nginx_imagick:24.04 \
  --build-arg INSTALL_IMAGICK=true \
  --build-arg INSTALL_REDIS=true \
  --build-arg INSTALL_MEMCACHED=true \
  --build-arg INSTALL_SSH2=true \
  --build-arg INSTALL_CRON=true \
  -t nginx:24.04-full .
```

**Using Docker Compose for testing:**
```sh
# Test Ubuntu 24.04 builds
.\build-test.ps1 -Version 24.04

# Test Ubuntu 25.04 builds
.\build-test.ps1 -Version 25.04

# Test both versions
.\build-test.ps1 -Version all
```

## Usage

Start a container (examples):
```sh
# Run nginx-based image and expose to host port 8080
docker run -p 8080:80 nginx:24.04

# Run apache-based image and expose to host port 8081
docker run -p 8081:80 apache:24.04

# Run with QUICK_SET preset for API workload
docker run -p 8080:80 -e QUICK_SET=API nginx:24.04

# Run with custom environment variables
docker run -p 8080:80 \
  -e TZ=America/New_York \
  -e PHP_MEMORY_LIMIT=512M \
  -e EXPOSE_SERVER_SOFTWARE=off \
  nginx:24.04
```

## Environment Variables

Both nginx and apache images support comprehensive runtime configuration via environment variables. All variables have sensible defaults and can be overridden individually or by using **QUICK_SET** presets.

### QUICK_SET Presets

Set `QUICK_SET` to one of these presets to apply optimized configurations for common workload types:

| Preset | Description | Use Case |
|--------|-------------|----------|
| `API` | High concurrency, small uploads, tight execution limits | REST/GraphQL APIs, microservices |
| `SHOP` | Moderate concurrency, session handling, medium uploads | E-commerce, shopping carts |
| `STATIC` | Very high concurrency, minimal PHP usage | Static sites with minimal dynamic content |
| `CMS` | Balanced config, large uploads, caching-friendly | WordPress, Drupal, content management |
| `default` | Balanced general-purpose (used when QUICK_SET not set) | General web applications |

**Example:**
```sh
docker run -p 8080:80 -e QUICK_SET=SHOP nginx:24.04
```

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone (e.g., `America/New_York`, `Europe/London`) |
| `WEB_PORT` | `80` | Internal web server port |
| `EXPOSE_SERVER_SOFTWARE` | `on` | Show server version in headers (`on`/`off`) |

### PHP Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | PHP memory limit per request |
| `PHP_MAX_EXECUTION_TIME` | `60` | Maximum script execution time (seconds) |
| `PHP_UPLOAD_MAX_FILESIZE` | `20M` | Maximum upload file size |
| `PHP_POST_MAX_SIZE` | `20M` | Maximum POST body size |
| `PHP_MAX_INPUT_VARS` | `1000` | Maximum input variables |
| `PHP_DISPLAY_ERRORS` | `Off` | Display errors to output (`On`/`Off`) |
| `PHP_LOG_ERRORS` | `On` | Log errors to file (`On`/`Off`) |

### Privacy & Security

| Variable | Default | Description |
|----------|---------|-------------|
| `DISABLE_FUNCTIONS` | `""` | Comma-separated list of functions to disable (e.g., `exec,shell_exec,system`) |
| `ALLOW_URL_FOPEN` | `On` | Allow opening remote URLs via fopen (`On`/`Off`) |
| `SESSION_COOKIE_SECURE` | `Off` | Require HTTPS for session cookies (`On`/`Off`) |
| `SESSION_COOKIE_HTTPONLY` | `On` | Prevent JavaScript access to session cookies (`On`/`Off`) |

### Performance (OPcache)

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_OPCACHE_ENABLE` | `1` | Enable OPcache (`1`/`0`) |
| `PHP_OPCACHE_MEMORY` | `128` | OPcache memory consumption (MB) |
| `PHP_OPCACHE_MAX_FILES` | `10000` | Maximum number of cached files |

### PHP-FPM Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_FPM_PM` | `dynamic` | Process manager type (`dynamic`, `static`, `ondemand`) |
| `PHP_FPM_PM_MAX_CHILDREN` | `20` | Maximum child processes |
| `PHP_FPM_PM_START_SERVERS` | `5` | Number of processes to start (dynamic mode) |
| `PHP_FPM_PM_MIN_SPARE_SERVERS` | `5` | Minimum idle processes (dynamic mode) |
| `PHP_FPM_PM_MAX_SPARE_SERVERS` | `10` | Maximum idle processes (dynamic mode) |

### Nginx-Specific Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_WORKER_CONNECTIONS` | `1024` | Maximum connections per worker |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | Keep-alive timeout (seconds) |
| `NGINX_CLIENT_MAX_BODY_SIZE` | Same as upload | Maximum request body size |

### Apache-Specific Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `APACHE_MAX_REQUEST_WORKERS` | `150` | Maximum concurrent connections (MPM event) |
| `APACHE_KEEPALIVE` | `On` | Enable HTTP keep-alive (`On`/`Off`) |
| `APACHE_KEEPALIVE_TIMEOUT` | `5` | Keep-alive timeout (seconds) |
| `APACHE_MAX_KEEPALIVE_REQUESTS` | `100` | Max requests per keep-alive connection |

### QUICK_SET Preset Values

Here's what each preset configures:

#### API
```
PHP_MEMORY_LIMIT=256M
PHP_MAX_EXECUTION_TIME=30
PHP_UPLOAD_MAX_FILESIZE=10M
NGINX_WORKER_CONNECTIONS=2048 (or APACHE_MAX_REQUEST_WORKERS=150)
PHP_FPM_PM_MAX_CHILDREN=50
EXPOSE_SERVER_SOFTWARE=off
```

#### SHOP
```
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=60
PHP_UPLOAD_MAX_FILESIZE=20M
NGINX_WORKER_CONNECTIONS=1024 (or APACHE_MAX_REQUEST_WORKERS=100)
PHP_FPM_PM_MAX_CHILDREN=30
EXPOSE_SERVER_SOFTWARE=off
```

#### STATIC
```
PHP_MEMORY_LIMIT=128M
PHP_MAX_EXECUTION_TIME=15
PHP_UPLOAD_MAX_FILESIZE=2M
NGINX_WORKER_CONNECTIONS=4096 (or APACHE_MAX_REQUEST_WORKERS=200)
PHP_FPM_PM_MAX_CHILDREN=10
EXPOSE_SERVER_SOFTWARE=off
```

#### CMS
```
PHP_MEMORY_LIMIT=384M
PHP_MAX_EXECUTION_TIME=90
PHP_UPLOAD_MAX_FILESIZE=64M
NGINX_WORKER_CONNECTIONS=1024 (or APACHE_MAX_REQUEST_WORKERS=100)
PHP_FPM_PM_MAX_CHILDREN=25
EXPOSE_SERVER_SOFTWARE=off
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  web:
    image: nginx:24.04
    environment:
      QUICK_SET: CMS
      TZ: Europe/Paris
      PHP_MEMORY_LIMIT: 512M
      EXPOSE_SERVER_SOFTWARE: off
      SESSION_COOKIE_SECURE: On
      DISABLE_FUNCTIONS: "exec,shell_exec,system"
    ports:
      - "8080:80"
```

### Advanced: Security Hardening

For production environments, consider:
```sh
docker run -p 8080:80 \
  -e QUICK_SET=API \
  -e EXPOSE_SERVER_SOFTWARE=off \
  -e PHP_DISPLAY_ERRORS=Off \
  -e SESSION_COOKIE_SECURE=On \
  -e SESSION_COOKIE_HTTPONLY=On \
  -e DISABLE_FUNCTIONS="exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec" \
  -e ALLOW_URL_FOPEN=Off \
  nginx:24.04
```

## Configuration
- Nginx config: `src/nginx/nginx.conf`, `src/nginx/site.conf`
- Apache config: `src/apache/000-default.conf`
- Entrypoints: `src/docker-entrypoint-nginx.sh`, `src/docker-entrypoint-apache.sh`

## GitHub Actions

**Workflow:** `.github/workflows/docker-build.yml`

**Build stages:**
1. `build-prep-base` - Builds base Ubuntu images
2. `build-prep-web` - Builds web server + PHP images
3. `build-variants` - Builds all extension permutations
4. `cleanup-untagged` - Removes untagged images from registry

**Triggers:**
- Push to `main` branch
- Pull requests to `main`
- Weekly schedule (Sundays at 02:00 UTC)

**Registry:** Images are pushed to GitHub Container Registry (ghcr.io)

**Cleanup:** Untagged images (SHA-only) are automatically removed after builds complete to save storage space.

## Customizing for Your Application

### Using as a Base Image

To use these images as a base for your own application:

```dockerfile
FROM ghcr.io/smol-kitten/nginx:24.04-imagick

# Copy your application files
COPY ./your-app /var/www/html

# Optional: Replace nginx site configuration
COPY ./your-nginx-site.conf /etc/nginx/sites-enabled/nginx.conf

# Optional: Replace main nginx config
COPY ./your-nginx.conf /etc/nginx/nginx.conf

# Optional: Add custom initialization without replacing the entire entrypoint
# This script will be executed before services start
COPY ./your-custom-init.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh

# Optional: Replace entrypoint script entirely
COPY ./your-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
```

### Custom Entrypoint Hook

Both nginx and apache images support a **custom entrypoint hook** that executes before services start. This allows you to add custom initialization logic (install additional packages, configure services, etc.) without replacing the entire entrypoint script.

**To use the hook:**
1. Create a bash script with your custom initialization code
2. Copy it to `/docker-entrypoint-custom.sh` in your Dockerfile
3. Make it executable

**Example custom hook script:**
```bash
#!/bin/bash
# /docker-entrypoint-custom.sh

echo "🔧 Running custom initialization..."

# Install additional packages
apt-get update && apt-get install -y vim curl

# Configure additional PHP settings
echo "zend_extension=xdebug.so" > /usr/local/php8.4/etc/conf.d/20-xdebug.ini

# Create additional directories
mkdir -p /var/www/html/cache
chown www-data:www-data /var/www/html/cache

echo "✅ Custom initialization complete"
```

**Using in Dockerfile:**
```dockerfile
FROM ghcr.io/smol-kitten/nginx:24.04

COPY ./my-app /var/www/html
COPY ./custom-init.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh
```

The custom hook runs **after** environment variable configuration but **before** PHP-FPM and web server startup, giving you full control over the initialization process.

### Using Cron for Scheduled Tasks

Images with the `-cron` suffix include the cron daemon, which is automatically started after the web server. To add scheduled tasks:

**Option 1: Add crontab via Dockerfile**
```dockerfile
FROM ghcr.io/smol-kitten/nginx:24.04-cron

COPY ./app /var/www/html

# Add crontab entries
RUN echo "*/5 * * * * www-data /usr/local/bin/php /var/www/html/cron.php >> /var/log/cron.log 2>&1" >> /etc/crontab
RUN echo "0 2 * * * www-data /usr/local/bin/php /var/www/html/cleanup.php" >> /etc/crontab
```

**Option 2: Add crontab via custom entrypoint hook**
```bash
#!/bin/bash
# /docker-entrypoint-custom.sh

echo "🕒 Setting up cron jobs..."

# Add cron job for www-data user
echo "*/15 * * * * /usr/local/bin/php /var/www/html/tasks/scheduled.php >> /var/log/cron.log 2>&1" | crontab -u www-data -

# Or add to system crontab
cat >> /etc/crontab << 'EOF'
# Run maintenance every hour
0 * * * * www-data /usr/local/bin/php /var/www/html/maintenance.php
# Database backup daily at 3 AM
0 3 * * * root /usr/local/bin/php /var/www/html/backup.php
EOF

echo "✅ Cron jobs configured"
```

**Option 3: Volume mount a crontab file**
```sh
docker run -p 8080:80 \
  -v ./my-crontab:/etc/cron.d/app-cron:ro \
  ghcr.io/smol-kitten/nginx:24.04-cron
```

**Cron log monitoring:**
Cron output is typically logged to syslog. To view logs:
```sh
# Inside the container
docker exec <container-id> tail -f /var/log/syslog

# Or redirect cron job output to a specific file
# */5 * * * * www-data /usr/local/bin/php /var/www/html/job.php >> /var/log/cron.log 2>&1
```

**Best practices:**
- Use absolute paths in cron jobs (`/usr/local/bin/php` instead of `php`)
- Specify the user for each cron job (typically `www-data` for PHP scripts)
- Redirect output to log files for debugging
- Use `/etc/cron.d/` for application-specific crontabs
- Ensure cron jobs have proper permissions and environment variables

### Key Files to Customize

**Application files:**
- `/var/www/html/` - Your PHP application files go here

**Nginx configuration:**
- `/etc/nginx/nginx.conf` - Main nginx configuration (see `src/nginx/nginx.conf`)
- `/etc/nginx/sites-enabled/nginx.conf` - Site-specific config (see `src/nginx/site.conf`)

**Startup:**
- `/docker-entrypoint.sh` - Container startup script (see `src/docker-entrypoint.sh`)

### Example: Adding a New Site

```sh
# Copy your site files
COPY ./mysite /var/www/html/mysite

# Add nginx site config
COPY ./mysite.conf /etc/nginx/sites-enabled/mysite.conf
```

## Extending

### Adding More PHP Extensions
Edit `Dockerfile_prep_nginx` or `Dockerfile_prep_apache2` to add common extensions for all variants, or `Dockerfile_specific` to add optional extensions.

### Adding More Variants
Adjust the build matrix in `.github/workflows/docker-build.yml` to add more extension combinations.

## Troubleshooting

### Build Issues
- **PHP compilation fails**: Ensure all build dependencies are installed (see Dockerfile_prep_base)
- **libzip package not found**: The build auto-detects libzip4 (24.04) or libzip5 (25.04/25.10)
- **t64 package errors (25.10)**: Dynamic detection handles libxml2-16, libcurl4t64, libssl3t64, etc.
- **PECL extension fails**: Check that PECL is accessible at `/usr/local/bin/pecl`
- **Extension loading errors**: Verify runtime libraries are installed (e.g., libssh2-1, libmemcached11, libgd3, libicu)

### Testing
Use the included test framework:
```powershell
# Build and test all Ubuntu 24.04 images
.\build-test.ps1 -Version 24.04

# Skip build and just test running containers
.\build-test.ps1 -Version 24.04 -SkipBuild

# Show full build output
.\build-test.ps1 -Version 24.04 -ShowBuildOutput
```

Test containers expose:
- Ubuntu 24.04 Nginx: http://localhost:8084
- Ubuntu 24.04 Apache: http://localhost:8085
- Ubuntu 25.04 Nginx: http://localhost:8086
- Ubuntu 25.04 Apache: http://localhost:8087
- Ubuntu 25.10 Nginx: http://localhost:8088
- Ubuntu 25.10 Apache: http://localhost:8089

### PHP Configuration
PHP 8.4.1 is installed to `/usr/local/php8.4/` with:
- Binary: `/usr/local/bin/php` (symlink)
- Config: `/usr/local/php8.4/etc/php.ini`
- FPM Config: `/usr/local/php8.4/etc/php-fpm.conf`
- Extensions: `/usr/local/php8.4/etc/conf.d/`
- Socket: `/var/run/php/php8.4-fpm.sock`

---

For more details, see the Dockerfile and workflow YAML.
