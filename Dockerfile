ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

# Detect OS type and set package manager
ARG INSTALL_IMAGICK=true
ARG INSTALL_PHPDBG=true

# Install packages
RUN apt-get update && \
        apt-get install -y software-properties-common && \
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -yy

RUN apt-get upgrade -yy        

RUN apt-get update && \
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
            php8.4-xml

RUN apt-get clean && rm -rf /var/lib/apt/lists/*; 




# Separately install optional packages to have better cache utilization
RUN if [ "$INSTALL_IMAGICK" = "true" ]; then \
        apt-get update && \
        apt-get install -y php8.4-imagick && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi
    
RUN if [ "$INSTALL_PHPDBG" = "true" ]; then \
        apt-get update && \
        apt-get install -y php8.4-phpdbg && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Create necessary directories
RUN mkdir -p /var/www/html /run/nginx

# Copy nginx config (with conditional paths for Alpine vs Ubuntu)
RUN mkdir -p /etc/nginx/sites-enabled; 
COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/site.conf /etc/nginx/sites-enabled/nginx.conf

# Start nginx and php-fpm
COPY src/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]