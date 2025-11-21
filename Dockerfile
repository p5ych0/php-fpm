# Build stage
FROM php:8.4-zts-alpine AS builder

ENV PHP_OPCACHE_PRELOAD=""
ENV PHP_OPCACHE_FREQ=600

# First extract PHP source and ensure it's available
RUN apk add --no-cache --virtual .build-deps \
    gcc libc-dev make cmake openssl-dev pcre-dev zlib-dev \
    linux-headers gnupg libxslt-dev gd-dev geoip-dev gettext-dev \
    perl-dev unzip zip g++ autoconf automake libzip-dev icu-dev \
    gmp-dev libpng-dev imagemagick-dev postgresql-dev oniguruma-dev \
    freetype-dev libjpeg-turbo-dev libxml2-dev libuv-dev

# Build and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/include/ \
    && mkdir -p /usr/src/php/ext/imagick \
    && curl -fsSL https://github.com/Imagick/imagick/archive/develop.tar.gz | tar xvz -C "/usr/src/php/ext/imagick" --strip 1 \
    && cd /usr/src/php/ext/imagick \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && docker-php-ext-install \
        bcmath calendar intl exif gmp gettext \
        mbstring pcntl pgsql pdo_pgsql pdo_mysql zip \
        gd opcache soap sockets \
    && pecl install -o -f igbinary ds raphf mongodb swoole uv parallel \
    && cd /tmp \
    && pecl download redis \
    && tar xzf redis-*.tgz \
    && cd redis-* \
    && phpize \
    && ./configure --enable-redis-igbinary \
    && make -j$(nproc) \
    && make install \
    && docker-php-ext-enable imagick igbinary mongodb raphf redis ds swoole uv parallel \
    && rm -rf /tmp/* /var/cache/apk/* \
    && apk del .build-deps

# Get Composer and PHPUnit
ADD https://getcomposer.org/installer /tmp/composer-setup.php
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm /tmp/composer-setup.php

ADD https://phar.phpunit.de/phpunit.phar /usr/local/bin/phpunit
RUN chmod +x /usr/local/bin/phpunit

# Final stage
FROM php:8.4-zts-alpine

ENV PHP_OPCACHE_PRELOAD=""
ENV PHP_OPCACHE_FREQ=600
ENV PUID=82
ENV PGID=82
ENV USER_NAME=www-data
ENV GROUP_NAME=www-data

# Install runtime dependencies
RUN apk --update add --no-cache \
    bash bash-completion curl diffutils git grep gmp sed openssl \
    gettext imagemagick mc wget net-tools procps sudo supervisor \
    postgresql-libs libjpeg-turbo libpng libzip icu-libs freetype tar libuv \
    shadow su-exec nodejs npm \
    && npm install -g chokidar-cli \
    && npm cache clean --force \
    && rm -rf /var/cache/apk/*

# Copy built extensions and binaries from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer
COPY --from=builder /usr/local/bin/phpunit /usr/local/bin/phpunit

# Copy application configs
COPY php.ini /usr/local/etc/php/php.ini
COPY supervisor/laravel.ini /etc/supervisor.d/laravel.ini
COPY supervisor/queue-worker.ini /etc/supervisor.d/queue-worker.ini
COPY cron/root /var/spool/cron/crontabs/root

# Setup directories and base permissions (ownership applied at runtime)
RUN mkdir -p /var/log/php \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/www/html \
    && chmod 0775 /var/log/php \
    && chmod 600 /var/spool/cron/crontabs/root \
    && touch /var/log/cron.log

# Add script to handle user creation
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php", "-a"]
