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
    freetype-dev libjpeg-turbo-dev libxml2-dev libuv-dev librdkafka-dev \
    libwebp-dev libavif-dev

# Build and install PHP extensions
# Pin: parallel >=1.2.14 segfaults with swoole loaded (swoole RINIT derefs a null
# thread buffer in parallel threads; <=1.2.13 recovered via its SIGSEGV handler,
# only while parallel loads before swoole). https://github.com/swoole/swoole-src/issues/6262
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/include/ \
    && docker-php-ext-install \
    bcmath calendar intl exif gmp gettext \
    mbstring pcntl pgsql pdo_pgsql pdo_mysql zip \
    gd opcache soap sockets \
    && pecl install -o -f imagick igbinary ds raphf mongodb swoole uv parallel-1.2.13 rdkafka \
    && cd /tmp \
    && pecl download redis \
    && tar xzf redis-*.tgz \
    && cd redis-* \
    && phpize \
    && ./configure --enable-redis-igbinary \
    && make -j$(nproc) \
    && make install \
    && docker-php-ext-enable imagick igbinary mongodb raphf redis ds swoole uv parallel rdkafka \
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
ENV NODE_PATH=/usr/local/lib/node_modules:/usr/local/lib/node_modules/chokidar-cli/node_modules

# Install runtime dependencies
# Image formats: Alpine's ImageMagick is built with heic/jxl/rsvg, but ships those coders as
# imagemagick-* subpackages that imagick loads at runtime (no recompile). libheif decodes HEIC
# (libde265) and AVIF (dav1d); libheif-aom adds AVIF encoding. No libheif-x265: HEIC is read-only.
# ffmpeg/ffprobe: video uploads (probe, thumbnails, transcode)
RUN apk --update add --no-cache \
    bash bash-completion curl diffutils git grep gmp sed openssl \
    gettext ghostscript imagemagick mc wget net-tools procps sudo supervisor \
    postgresql-libs libjpeg-turbo libpng libzip icu-libs freetype tar libuv \
    shadow su-exec nodejs npm librdkafka libwebp libavif \
    imagemagick-heic imagemagick-jxl imagemagick-svg libheif-aom ffmpeg \
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
COPY scripts/octane-start.sh /usr/local/bin/octane-start.sh

# Setup directories and base permissions (ownership applied at runtime)
RUN mkdir -p /var/log/php \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/www/html \
    && chmod 0775 /var/log/php \
    && chmod 600 /var/spool/cron/crontabs/root \
    && touch /var/log/cron.log \
    && chmod +x /usr/local/bin/octane-start.sh

# Add script to handle user creation
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php", "-a"]
