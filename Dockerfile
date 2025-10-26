ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

# Detect OS type and set package manager
ARG INSTALL_IMAGICK=true
ARG INSTALL_PHPDBG=true

# Install packages based on OS type
RUN if [ -f /etc/alpine-release ]; then \
        # Alpine Linux \
        apk update && \
        apk add --no-cache \
            nginx \
            php84 \
            php84-fpm \
            php84-opcache \
            php84-gd \
            php84-mysqli \
            php84-zlib \
            php84-curl \
            php84-mbstring \
            php84-json \
            php84-session \
            php84-xml \
            php84-intl \
            php84-pdo \
            php84-pdo_mysql \
            php84-openssl \
            $(if [ "$INSTALL_IMAGICK" = "true" ]; then echo "php84-pecl-imagick"; fi) \
            $(if [ "$INSTALL_PHPDBG" = "true" ]; then echo "php84-phpdbg"; fi) && \
        ln -sf /usr/bin/php84 /usr/bin/php; \
    else \
        # Ubuntu/Debian \
        apt-get update && \
        apt-get install -y software-properties-common && \
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -yy && \
        apt-get update && \
        apt-get install -y \
            nginx \
            php8.4 \
            php8.4-cli \
            php8.4-fpm \
            php8.4-intl \
            php8.4-mysql \
            php8.4-readline \
            php8.4-bz2 \
            php8.4-common \
            php8.4-gd \
            php8.4-mbstring \
            php8.4-opcache \
            php8.4-ssh2 \
            php8.4-cgi \
            php8.4-curl \
            php8.4-mcrypt \
            php8.4-xml \
            $(if [ "$INSTALL_IMAGICK" = "true" ]; then echo "php8.4-imagick"; fi) \
            $(if [ "$INSTALL_PHPDBG" = "true" ]; then echo "php8.4-phpdbg"; fi) && \
        apt-get upgrade -yy && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Create necessary directories
RUN mkdir -p /var/www/html /run/nginx

# Copy nginx config (with conditional paths for Alpine vs Ubuntu)
RUN if [ -f /etc/alpine-release ]; then \
        mkdir -p /etc/nginx/http.d; \
    else \
        mkdir -p /etc/nginx/sites-enabled; \
    fi

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/site.conf /tmp/site.conf

# Copy site config to appropriate location based on OS
RUN if [ -f /etc/alpine-release ]; then \
        mv /tmp/site.conf /etc/nginx/http.d/default.conf; \
    else \
        mv /tmp/site.conf /etc/nginx/sites-enabled/nginx.conf; \
    fi

# Start nginx and php-fpm
COPY src/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]