# nginx & Apache PHP Docker Images

## Overview
This project builds custom Docker images for Nginx/Apache + PHP 8.4 using a multi-stage build approach for optimal caching and flexibility. Images are built automatically using GitHub Actions with a base → web → variants pipeline.

Both nginx and apache images include comprehensive runtime configuration via environment variables, including **QUICK_SET presets** for common workload types (API, SHOP, STATIC, CMS).

## Build Pipeline
1. **prep_base:24.04, prep_base:latest** - Base Ubuntu with software-properties-common
2. **prep_nginx:24.04, prep_nginx:latest** - Adds Nginx + PHP 8.4-FPM + common extensions
3. **prep_apache2:24.04, prep_apache2:latest** - Adds Apache2 + PHP 8.4-FPM + common extensions
4. **nginx:*, apache:*** - Final variants with optional extensions (imagick, phpdbg, sqlite, mysql, ssh2)

## Image Variants
Final images are tagged based on enabled extensions. Current matrix builds **128 variants** (2 servers × 2 versions × 2^5 extension combinations):

**Base versions:**
- `nginx:24.04` - Ubuntu 24.04 base (no optional extensions)
- `nginx:latest` - Ubuntu latest base (no optional extensions)
- `apache2:24.04` - Ubuntu 24.04 base (no optional extensions)
- `apache2:latest` - Ubuntu latest base (no optional extensions)

**Extension variants** (examples):
- `nginx:24.04-imagick` - With php8.4-imagick
- `nginx:24.04-imagick-mysql` - With imagick and MySQL support
- `apache2:24.04-sqlite-mysql` - With SQLite and MySQL support
- (Full matrix includes all combinations of: imagick, sqlite, mysql, ssh2)

**Note:** php8.4-phpdbg is currently disabled as it's not yet available in Ondřej's PPA for PHP 8.4. It will be re-enabled once the package becomes available.

## Build Arguments

### Dockerfile_prep_base
- `BASE_IMAGE` (default: `ubuntu:24.04`): Ubuntu base image version

### Dockerfile_prep_nginx
- `BASE_IMAGE` (default: `prep_base:24.04`): Base prep image to build from

### Dockerfile_prep_apache2
- `BASE_IMAGE` (default: `prep_base:24.04`): Base prep image to build from

### Dockerfile_specific
- `BASE_IMAGE` (default: `prep_nginx:24.04` or `prep_apache2:24.04`): Base prep image to build from
- `INSTALL_IMAGICK` (default: `true`): Include php8.4-imagick
- `INSTALL_SQLITE` (default: `true`): Include php8.4-sqlite3
- `INSTALL_MYSQL` (default: `true`): Include php8.4-mysql
- `INSTALL_SSH2` (default: `true`): Include php8.4-ssh2

## Example Build Commands

**Manual multi-stage build:**
```sh
# 1. Build prep base
docker build -f Dockerfile_prep_base --build-arg BASE_IMAGE=ubuntu:24.04 -t prep_base:24.04 .

# 2. Build prep nginx
docker build -f Dockerfile_prep_nginx --build-arg BASE_IMAGE=prep_base:24.04 -t prep_nginx:24.04 .

# 2b. Build prep apache2
docker build -f Dockerfile_prep_apache2 --build-arg BASE_IMAGE=prep_base:24.04 -t prep_apache2:24.04 .

# 3. Build specific variant (nginx)
docker build -f Dockerfile_specific \
  --build-arg BASE_IMAGE=prep_nginx:24.04 \
  --build-arg INSTALL_IMAGICK=true \
  --build-arg INSTALL_PHPDBG=false \
  -t nginx:24.04-imagick .
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

# Optional: Replace entrypoint script
COPY ./your-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
```

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
- If a package is missing for a specific Ubuntu version, check the Dockerfile and adjust the package list.
- For new Ubuntu versions, ensure Ondřej's PPA supports the version.

---

For more details, see the Dockerfile and workflow YAML.
