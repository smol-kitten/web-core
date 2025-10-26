# nginx-php Docker Images

## Overview
This project builds custom Docker images for Nginx + PHP 8.4, supporting multiple Ubuntu versions (24.04, 25.04, 25.10) and feature variants (imagic, dbg, etc). Images are built and tagged automatically using GitHub Actions.

## Image Variants
- `nginx:24.04`, `nginx:25.04`, `nginx:25.10`, `nginx:latest` (Ubuntu-based)
- `nginx:24.04-imagic`, `nginx:latest-imagic` (with php8.4-imagick)
- `nginx:24.04-dbg`, `nginx:latest-dbg` (with php8.4-phpdbg)
- `nginx:24.04-imagic-dbg`, `nginx:latest-imagic-dbg` (with both imagick and phpdbg)

## Build Arguments
- `BASE_IMAGE` (default: `ubuntu:24.04`): Ubuntu base image version.
- `INSTALL_IMAGICK` (default: `true`): Set to `false` to exclude php8.4-imagick.
- `INSTALL_PHPDBG` (default: `true`): Set to `false` to exclude php8.4-phpdbg.

## Example Build Commands

Build Ubuntu 24.04 base (no imagick or phpdbg):
```sh
docker build --build-arg BASE_IMAGE=ubuntu:24.04 --build-arg INSTALL_IMAGICK=false --build-arg INSTALL_PHPDBG=false -t nginx:24.04 .
```

Build Ubuntu 24.04 with imagick only:
```sh
docker build --build-arg BASE_IMAGE=ubuntu:24.04 --build-arg INSTALL_IMAGICK=true --build-arg INSTALL_PHPDBG=false -t nginx:24.04-imagic .
```

Build Ubuntu 24.04 with phpdbg only:
```sh
docker build --build-arg BASE_IMAGE=ubuntu:24.04 --build-arg INSTALL_IMAGICK=false --build-arg INSTALL_PHPDBG=true -t nginx:24.04-dbg .
```

Build Ubuntu 24.04 with both imagick and phpdbg:
```sh
docker build --build-arg BASE_IMAGE=ubuntu:24.04 --build-arg INSTALL_IMAGICK=true --build-arg INSTALL_PHPDBG=true -t nginx:24.04-imagic-dbg .
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
- Workflow: `.github/workflows/docker-build.yml`
- Builds all variants on push to `main`

## Extending
- Edit the Dockerfile to add more PHP extensions or Nginx modules as needed.
- Adjust the build matrix in the workflow for more variants.

## Troubleshooting
- If a package is missing for a specific Ubuntu version, check the Dockerfile and adjust the package list.
- For new Ubuntu versions, ensure Ondřej's PPA supports the version.

---

For more details, see the Dockerfile and workflow YAML.
