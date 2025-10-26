ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

# Delete default nginx index page
#RUN rm /usr/share/nginx/html/index.html

# Install PHP 8.4

##install required packages
RUN apt update
RUN apt install software-properties-common -yy
RUN LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -yy


#RUN apt-get install -y lsb-release ca-certificates apt-transport-https curl
#RUN curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
#RUN dpkg -i /tmp/debsuryorg-archive-keyring.deb
#RUN sh -c 'echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

RUN apt update


# Install PHP 8.4 and required extensions
ARG INSTALL_IMAGICK=true
ARG INSTALL_PHPDBG=true
RUN apt install php8.4 php8.4-cli php8.4-fpm php8.4-intl php8.4-mysql php8.4-readline php8.4-bz2 php8.4-common php8.4-gd php8.4-mbstring php8.4-opcache php8.4-ssh2 php8.4-cgi php8.4-curl php8.4-mcrypt php8.4-xml \
	$(if [ "$INSTALL_IMAGICK" = "true" ]; then echo "php8.4-imagick"; fi) \
	$(if [ "$INSTALL_PHPDBG" = "true" ]; then echo "php8.4-phpdbg"; fi) \
	-yy

RUN apt upgrade -yy

# Enable and start PHP-FPM
RUN systemctl enable php8.4-fpm

# Install Nginx
RUN apt install nginx -yy

#copy nginx config
COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/site.conf /etc/nginx/sites-enabled/nginx.conf

#Copy Panel structure form panel subdir into /var/www/
#COPY src/html/ /var/www/html/
RUN mkdir -p /var/www/html

# Start nginx and php-fpm
COPY src/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]