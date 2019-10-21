FROM php:fpm-alpine

RUN apk update

RUN apk add --no-cache --virtual .run-deps \
    bash \
    curl \
    diffutils \
    grep \
    sed \
    openssl \
    mc \
    wget \
    net-tools \
    procps \
    sudo \
    supervisor \
    && addgroup -S nginx \
    && adduser -D -S -h /var/www/html -s /sbin/nologin -G nginx nginx \
    && chown nginx /var/www/html

RUN apk add --no-cache --virtual .build-deps \
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
    tar \
    unzip \
    zip \
    g++ \
    autoconf \
    automake \
    libzip-dev \
    icu-dev \
    libpng \
    libpng-dev \
    freetype \
    postgresql-dev \
    freetype-dev \
    libjpeg-turbo \
    libjpeg-turbo-dev \
    libxml2-dev

RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/

RUN docker-php-ext-install \
      intl \
      mbstring \
      pcntl \
      pdo_pgsql \
      pgsql \
      zip \
      gd

RUN docker-php-ext-install opcache
RUN docker-php-ext-install soap

RUN pecl install -o -f igbinary
RUN pecl install -o -f psr
RUN pecl install -o -f ds
RUN pecl download redis && mv redis-*.tgz /tmp && cd /tmp && tar -xvzf `ls redis-*.tgz` && cd redis-* && phpize && ./configure --enable-redis-igbinary && make -j$(nproc) && make install
RUN docker-php-ext-enable igbinary redis psr ds
RUN rm -rf /tmp/*

RUN apk del .build-deps

RUN echo -e "opcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=7963\n\
opcache.revalidate_freq=1\nopcache.fast_shutdown=1\nopcache.enable_cli=1\nopcache.enable=1\nopcache.validate_timestamps=1\n" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www/html

RUN mkdir /var/log/php
RUN chown nginx /var/log/php
RUN chmod 0775 /var/log/php
RUN chown nginx /var/www

#crontab
COPY ./cron/root /var/spool/cron/crontabs/root
RUN chmod 600 /var/spool/cron/crontabs/root
RUN touch /var/log/cron.log
COPY /supervisor /etc/supervisor/conf.d/

# Install composer
ADD ./getcomposer.sh .
RUN bash ./getcomposer.sh
RUN cat /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
RUN rm getcomposer.sh
RUN mv ./composer.phar /usr/local/bin/composer
RUN php -r "copy('https://phar.phpunit.de/phpunit.phar', 'phpunit.phar');"
RUN chmod +x phpunit.phar
RUN mv phpunit.phar /usr/local/bin/phpunit
