FROM php:fpm-alpine

ENV PHP_OPCACHE_PRELOAD=""
ENV PHP_OPCACHE_FREQ=600

RUN apk --update add --no-cache --virtual .run-deps \
    bash \
    bash-completion \
    curl \
    diffutils \
    git \
    grep \
    gmp \
    sed \
    openssl \
    gettext \
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
    gettext-dev \
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
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/include/ \
    && mkdir -p /usr/src/php/ext/imagick; \
    curl -fsSL https://github.com/Imagick/imagick/archive/06116aa24b76edaf6b1693198f79e6c295eda8a9.tar.gz | tar xvz -C "/usr/src/php/ext/imagick" --strip 1 \
    && docker-php-ext-install \
      bcmath \
      calendar \
      intl \
      exif \
      gmp \
      gettext \
      imagick \
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
    && pecl install -o -f igbinary \
    && pecl install -o -f psr \
    && pecl install -o -f ds \
    && pecl install -o -f raphf \
    && pecl install -o -f mongodb \
    && pecl download redis && mv redis-*.tgz /tmp && cd /tmp && tar -xvzf `ls redis-*.tgz` && cd redis-* && phpize && ./configure --enable-redis-igbinary && make -j$(nproc) && make install \
    && docker-php-ext-enable igbinary mongodb raphf redis psr ds \
    && rm -rf /tmp/* \
    && apk del .build-deps \
    && echo -e "opcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=16229\nopcache.jit_buffer_size=32M\n\
opcache.revalidate_freq=\${PHP_OPCACHE_FREQ}\nopcache.fast_shutdown=1\nopcache.enable_cli=1\nopcache.enable=1\nopcache.validate_timestamps=1\nopcache.enable_file_override=0\n\
opcache.preload=\${PHP_OPCACHE_PRELOAD}\nopcache.preload_user=www-data\n" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

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
    && php -r "copy('https://phar.phpunit.de/phpunit.phar', 'phpunit.phar');" \
    && chmod +x phpunit.phar \
    && mv phpunit.phar /usr/local/bin/phpunit

WORKDIR /var/www/html
