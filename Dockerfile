FROM php:7.3-fpm-alpine

ENV PHP_OPCACHE_FREQ=600

RUN apk --update add --no-cache --virtual .run-deps \
    bash \
    bash-completion \
    curl \
    diffutils \
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
    libpng \
    libzip \
    icu-libs \
    freetype \
    tar

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
    gmp-dev \
    libpng-dev \
    imagemagick-dev \
    postgresql-dev \
    oniguruma-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-gd --with-freetype-dir=/usr/include/ --with-png-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/include/ \
    && docker-php-ext-install \
      bcmath \
      intl \
      exif \
      gmp \
      mysqli \
      mbstring \
      pcntl \
      pgsql \
      pdo_pgsql \
      pdo_mysql \
      zip \
      gd \
      opcache \
      soap \
      sockets \
    && pecl install -o -f imagick \
    && pecl install -o -f igbinary \
    && pecl install -o -f psr \
    && pecl install -o -f ds \
    && pecl install -o -f raphf \
    && pecl install -o -f mongodb \
    && pecl download redis && mv redis-*.tgz /tmp && cd /tmp && tar -xvzf `ls redis-*.tgz` && cd redis-* && phpize && ./configure --enable-redis-igbinary && make -j$(nproc) && make install \
    && docker-php-ext-enable igbinary imagick mongodb raphf redis psr ds \
    && rm -rf /tmp/* \
    && apk del .build-deps \
    && echo -e "opcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=16229\n\
opcache.revalidate_freq=\${PHP_OPCACHE_FREQ}\nopcache.fast_shutdown=1\nopcache.enable_cli=1\nopcache.enable=1\nopcache.validate_timestamps=1\nopcache.enable_file_override=0\n" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# RUN wget http://browscap.org/stream?q=Full_PHP_BrowsCapINI -O /usr/local/etc/php/browscap.ini
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./php.ini /usr/local/etc/php/php.ini
COPY ./cron/root /var/spool/cron/crontabs/root
COPY /supervisor/laravel.ini /etc/supervisor.d/laravel.ini
ADD ./getcomposer.sh .

RUN mkdir /var/log/php \
    && mkdir /var/log/supervisor \
    && chown www-data:www-data /var/log/php \
    && chmod 0775 /var/log/php \
    && chown www-data:www-data -R /var/www \
    && chmod 600 /var/spool/cron/crontabs/root && touch /var/log/cron.log \
    && bash ./getcomposer.sh \
    && rm getcomposer.sh \
    && mv ./composer.phar /usr/local/bin/composer \
    && wget https://phar.phpunit.de/phpunit.phar -O phpunit.phar \
    && chmod +x phpunit.phar \
    && mv phpunit.phar /usr/local/bin/phpunit

WORKDIR /var/www/html
