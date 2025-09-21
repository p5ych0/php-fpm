# syntax=docker/dockerfile:1
FROM php:7-fpm-alpine AS base

# Environment variables for OpenResty compatibility
ENV PHP_OPCACHE_PRELOAD=""
ENV PHP_OPCACHE_FREQ=600
ENV PUID=82
ENV PGID=82
ENV USER_NAME=www-data
ENV GROUP_NAME=www-data

# Install runtime dependencies
RUN --mount=type=cache,target=/var/cache/apk \
    apk --update add --no-cache \
        bash \
        bash-completion \
        curl \
        diffutils \
        git \
        grep \
        gmp \
        sed \
        openssl \
        imagemagick \
        mc \
        wget \
        net-tools \
        procps \
        sudo \
        supervisor \
        postgresql-libs \
        libjpeg-turbo \
        libgomp \
        libpng \
        libzip \
        icu-libs \
        freetype \
        tar \
        shadow \
        su-exec \
        gettext

# Build stage for extensions
FROM base AS builder

# Install build dependencies
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        cmake \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        gnupg \
        libxslt-dev \
        gd-dev \
        geoip-dev \
        perl-dev \
        unzip \
        zip \
        g++ \
        autoconf \
        automake \
        libzip-dev \
        icu-dev \
        gmp-dev \
        libpng-dev \
        imagemagick-dev \
        postgresql-dev \
        oniguruma-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libxml2-dev

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/include/ && \
    docker-php-ext-install -j$(nproc) \
        bcmath \
        intl \
        exif \
        gmp \
        mbstring \
        pcntl \
        pgsql \
        pdo_pgsql \
        pdo_mysql \
        zip \
        gd \
        opcache \
        soap \
        sockets

# Install PECL extensions (MongoDB version compatible with PHP 7.4)
RUN pecl install -o -f imagick igbinary psr ds raphf mongodb-1.17.2

# Custom Redis installation with igbinary support
RUN --mount=type=cache,target=/tmp/redis-build \
    pecl download redis && \
    tar -xf redis-*.tgz -C /tmp/redis-build --strip-components=1 && \
    cd /tmp/redis-build && \
    phpize && \
    ./configure --enable-redis-igbinary && \
    make -j$(nproc) && \
    make install

# Enable all extensions
RUN docker-php-ext-enable igbinary imagick mongodb raphf redis psr ds

# Final stage
FROM base AS final

# Copy built extensions from builder stage
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Configure OPcache with dynamic environment variable support
RUN { \
        echo 'opcache.memory_consumption=192'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=16229'; \
        echo 'opcache.revalidate_freq=${PHP_OPCACHE_FREQ}'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.enable_file_override=0'; \
        echo 'opcache.preload=${PHP_OPCACHE_PRELOAD}'; \
        echo 'opcache.preload_user=${USER_NAME}'; \
    } > /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini.template

# Copy configuration files
COPY ./www.conf.template /usr/local/etc/php-fpm.d/www.conf.template
COPY ./php.ini /usr/local/etc/php/php.ini
COPY ./cron/root.template /var/spool/cron/crontabs/root.template
COPY ./supervisor/laravel.ini.template /etc/supervisor.d/laravel.ini.template

# Install Composer with integrity verification
COPY ./getcomposer.sh /tmp/getcomposer.sh
RUN --mount=type=cache,target=/tmp/composer-cache \
    cd /tmp && \
    bash ./getcomposer.sh && \
    mv ./composer.phar /usr/local/bin/composer && \
    rm ./getcomposer.sh

# Install PHPUnit compatible with PHP 7.4
RUN --mount=type=cache,target=/tmp/phpunit-cache \
    wget https://phar.phpunit.de/phpunit-9.phar -O /tmp/phpunit.phar && \
    chmod +x /tmp/phpunit.phar && \
    mv /tmp/phpunit.phar /usr/local/bin/phpunit

# Create necessary directories and set permissions
RUN mkdir -p /var/log/php /var/log/supervisor /var/www/html /tmp/templates && \
    chmod 0775 /var/log/php /var/log/supervisor

# Create entrypoint script
COPY --chmod=755 <<'EOF' /usr/local/bin/docker-entrypoint.sh
#!/bin/bash
set -e

# Set default values if not provided (OpenResty compatibility)
USER_ID=${PUID:-82}
GROUP_ID=${PGID:-82}
USER_NAME=${USER_NAME:-www-data}
GROUP_NAME=${GROUP_NAME:-www-data}
NUMPROCS=${NUMPROCS:-4}
PHP_OPCACHE_PRELOAD=${PHP_OPCACHE_PRELOAD:-}
PHP_OPCACHE_FREQ=${PHP_OPCACHE_FREQ:-600}

# Export environment variables for supervisor
export USER_ID GROUP_ID USER_NAME GROUP_NAME NUMPROCS PHP_OPCACHE_PRELOAD PHP_OPCACHE_FREQ

# Create group if it doesn't exist
if ! getent group "${GROUP_NAME}" >/dev/null 2>&1; then
    if ! getent group "${GROUP_ID}" >/dev/null 2>&1; then
        addgroup -g "${GROUP_ID}" "${GROUP_NAME}"
    else
        # Group ID exists but with different name, use existing group
        EXISTING_GROUP=$(getent group "${GROUP_ID}" | cut -d: -f1)
        GROUP_NAME="${EXISTING_GROUP}"
    fi
fi

# Create user if it doesn't exist
if ! getent passwd "${USER_NAME}" >/dev/null 2>&1; then
    if ! getent passwd "${USER_ID}" >/dev/null 2>&1; then
        adduser -D -u "${USER_ID}" -G "${GROUP_NAME}" -s /bin/bash "${USER_NAME}"
    else
        # User ID exists but with different name, use existing user
        EXISTING_USER=$(getent passwd "${USER_ID}" | cut -d: -f1)
        USER_NAME="${EXISTING_USER}"
    fi
fi

# Process configuration templates
envsubst '${USER_NAME} ${GROUP_NAME} ${USER_ID} ${GROUP_ID}' < /usr/local/etc/php-fpm.d/www.conf.template > /usr/local/etc/php-fpm.d/www.conf
envsubst '${USER_NAME}' < /var/spool/cron/crontabs/root.template > /var/spool/cron/crontabs/root
envsubst '${USER_NAME}' < /etc/supervisor.d/laravel.ini.template > /etc/supervisor.d/laravel.ini
envsubst '${PHP_OPCACHE_PRELOAD} ${PHP_OPCACHE_FREQ} ${USER_NAME}' < /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini.template > /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Set proper permissions for cron
chmod 600 /var/spool/cron/crontabs/root
chown root:root /var/spool/cron/crontabs/root

# Create log file for cron
touch /var/log/cron.log

# Ensure proper ownership of critical directories
chown -R "${USER_ID}:${GROUP_ID}" /var/www /var/log/php
# Supervisor logs need to be accessible by root (supervisord) but readable by user
chown -R root:root /var/log/supervisor
chmod 755 /var/log/supervisor

# Set working directory
cd /var/www/html

# Execute the main command
if [ "$1" = "supervisord" ]; then
    # Run supervisor with the processed configuration (use -n for nodaemon)
    exec /usr/bin/supervisord -n -c /etc/supervisor.d/laravel.ini
else
    # Default: run php-fpm (manages its own user switching)
    exec "$@"
fi
EOF

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
