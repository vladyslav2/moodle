FROM php:7-fpm-alpine
RUN apk update && apk --no-cache add \
        nginx \
        supervisor \
        curl

# gd requirements
RUN apk --no-cache add libzip-dev freetype-dev libjpeg-turbo-dev libpng-dev zlib-dev
RUN docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/

RUN docker-php-ext-install -j$(nproc) gd

# soap deps
RUN apk --no-cache add libxml2-dev
RUN docker-php-ext-install -j$(nproc) soap

RUN docker-php-ext-install -j$(nproc) zip

# simplexml already is in php image
# RUN docker-php-ext-install -j$(nproc) simplexml \
# Installing shared extensions:     /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
# cp: can't stat 'modules/*': No such file or directory
# make: *** [Makefile:87: install-modules] Error 1
# RUN docker-php-ext-install -j$(nproc) spl

# icu-dev deps
RUN apk --no-cache add icu-dev
RUN docker-php-ext-install -j$(nproc) intl

COPY --chown=nobody . /var/www/html/

# Install packages and remove default server definition
RUN rm /etc/nginx/conf.d/default.conf

# Configure nginx
COPY etc/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY etc/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY etc/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY etc/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup document root
RUN mkdir -p /var/www/html
RUN ls /var/www/html/

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
