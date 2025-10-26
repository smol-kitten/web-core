# nginx-php Docker Images

## Overview
This project builds custom Docker images for Nginx + PHP 8.4 using a multi-stage build approach for optimal caching and flexibility. Images are built automatically using GitHub Actions with a base → web → variants pipeline.

## Build Pipeline
1. **prep:24.04, prep:latest** - Base Ubuntu with software-properties-common
2. **prep_web:24.04, prep_web:latest** - Adds Nginx + PHP 8.4 + common extensions
3. **nginx:*** - Final variants with optional extensions (imagick, phpdbg, sqlite, mysql, ssh2)

## Image Variants
Final images are tagged based on enabled extensions. Current matrix builds **64 variants** (2 versions × 2^5 extension combinations):

**Base versions:**
- `nginx:24.04` - Ubuntu 24.04 base (no optional extensions)
- `nginx:latest` - Ubuntu latest base (no optional extensions)

**Extension variants** (examples):
- `nginx:24.04-imagick` - With php8.4-imagick
- `nginx:24.04-phpdbg` - With php8.4-phpdbg
- `nginx:24.04-imagick-phpdbg` - With both imagick and phpdbg
- `nginx:24.04-sqlite-mysql` - With SQLite and MySQL support
- (Full matrix includes all combinations of: imagick, phpdbg, sqlite, mysql, ssh2)

## Build Arguments

### Dockerfile_prep_base
- `BASE_IMAGE` (default: `ubuntu:24.04`): Ubuntu base image version

### Dockerfile_prep_web
- `BASE_IMAGE` (default: `prep:24.04`): Base prep image to build from

### Dockerfile_specific
- `BASE_IMAGE` (default: `prep_web:24.04`): Base prep_web image to build from
- `INSTALL_IMAGICK` (default: `true`): Include php8.4-imagick
- `INSTALL_PHPDBG` (default: `true`): Include php8.4-phpdbg
- `INSTALL_SQLITE` (default: `true`): Include php8.4-sqlite3
- `INSTALL_MYSQL` (default: `true`): Include php8.4-mysql
- `INSTALL_SSH2` (default: `true`): Include php8.4-ssh2

## Example Build Commands

**Manual multi-stage build:**
```sh
# 1. Build prep base
docker build -f Dockerfile_prep_base --build-arg BASE_IMAGE=ubuntu:24.04 -t prep:24.04 .

# 2. Build prep web
docker build -f Dockerfile_prep_web --build-arg BASE_IMAGE=prep:24.04 -t prep_web:24.04 .

# 3. Build specific variant
docker build -f Dockerfile_specific \
  --build-arg BASE_IMAGE=prep_web:24.04 \
  --build-arg INSTALL_IMAGICK=true \
  --build-arg INSTALL_PHPDBG=false \
  -t nginx:24.04-imagick .
```

## Usage

Start a container:
```sh
docker run -p 8080:80 nginx:24.04
```

## Configuration
- Nginx config: `src/nginx/nginx.conf`, `src/nginx/site.conf`
- Entrypoint: `src/docker-entrypoint.sh`

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
Edit `Dockerfile_prep_web` to add common extensions for all variants, or `Dockerfile_specific` to add optional extensions.

### Adding More Variants
Adjust the build matrix in `.github/workflows/docker-build.yml` to add more extension combinations.

## Troubleshooting
- If a package is missing for a specific Ubuntu version, check the Dockerfile and adjust the package list.
- For new Ubuntu versions, ensure Ondřej's PPA supports the version.

---

For more details, see the Dockerfile and workflow YAML.
