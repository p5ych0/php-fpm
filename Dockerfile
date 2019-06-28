FROM php:fpm

RUN apt-get update
RUN apt-get install -y \
      wget \
      mc \
      net-tools \
      iputils-ping \
      procps \
      unzip \
      supervisor

RUN apt-get install -y \
      libzip-dev \
      libicu-dev \
      libpng-dev \
      libpq-dev \
      libfreetype6-dev \
      libjpeg62-turbo-dev

RUN rm -r /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/

RUN docker-php-ext-install \
      intl \
      mbstring \
      pcntl \
      pdo_pgsql \
      pgsql \
      zip \
      gd

RUN docker-php-ext-install opcache

RUN pecl install -o -f igbinary
RUN pecl install -o -f psr
RUN pecl install -o -f ds
RUN pecl download redis && mv redis-*.tgz /tmp && cd /tmp && tar -xvzf `ls redis-*.tgz` && cd redis-* && phpize && ./configure --enable-redis-igbinary && make -j$(nproc) && make install
RUN docker-php-ext-enable igbinary redis psr ds
RUN rm -rf /tmp/*

RUN echo "opcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=7963\n\
opcache.revalidate_freq=1\nopcache.fast_shutdown=1\nopcache.enable_cli=1\nopcache.enable=1\nopcache.validate_timestamps=1\n" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www/html

RUN mkdir /var/log/php
RUN chown 33:33 /var/log/php
RUN chmod 0775 /var/log/php

# Install composer
ADD ./getcomposer.sh .
RUN bash ./getcomposer.sh
RUN rm getcomposer.sh
RUN mv ./composer.phar /usr/local/bin/composer
RUN php -r "copy('https://phar.phpunit.de/phpunit.phar', 'phpunit.phar');"
RUN chmod +x phpunit.phar
RUN mv phpunit.phar /usr/local/bin/phpunit
