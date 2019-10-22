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
    postgresql-libs \
    libjpeg-turbo \
    libpng \
    icu-libs \
    freetype \
    tar \
    && chown www-data /var/www/html

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
    unzip \
    zip \
    g++ \
    autoconf \
    automake \
    libzip-dev \
    icu-dev \
    libpng-dev \
    postgresql-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/include/ \
    && docker-php-ext-install \
      intl \
      mbstring \
      pcntl \
      pgsql \
      pdo_pgsql \
      zip \
      gd \
      opcache \
      soap \
    && pecl install -o -f igbinary \
    && pecl install -o -f psr \
    && pecl install -o -f ds \
    && pecl download redis && mv redis-*.tgz /tmp && cd /tmp && tar -xvzf `ls redis-*.tgz` && cd redis-* && phpize && ./configure --enable-redis-igbinary && make -j$(nproc) && make install \
    && docker-php-ext-enable igbinary redis psr ds \
    && rm -rf /tmp/* \
    && apk del .build-deps \
    && echo -e "opcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=7963\n\
opcache.revalidate_freq=1\nopcache.fast_shutdown=1\nopcache.enable_cli=1\nopcache.enable=1\nopcache.validate_timestamps=1\n" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./php.ini /usr/local/etc/php/php.ini
COPY ./cron/root /var/spool/cron/crontabs/root
COPY /supervisor/laravel.ini /etc/supervisor.d/laravel.ini
ADD ./getcomposer.sh .

RUN mkdir /var/log/php \
    && chown www-data /var/log/php \
    && chmod 0775 /var/log/php \
    && chown www-data -R /var/www \
    && chmod 600 /var/spool/cron/crontabs/root && touch /var/log/cron.log \
    && bash ./getcomposer.sh \
    && rm getcomposer.sh \
    && mv ./composer.phar /usr/local/bin/composer \
    && php -r "copy('https://phar.phpunit.de/phpunit.phar', 'phpunit.phar');" \
    && chmod +x phpunit.phar \
    && mv phpunit.phar /usr/local/bin/phpunit

WORKDIR /var/www/html
