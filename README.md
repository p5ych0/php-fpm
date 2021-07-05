# php-fpm

![DockerHub](https://img.shields.io/docker/automated/p5ych0/php-fpm.svg) Dockerfile for [PHP-FPM](https://hub.docker.com/r/p5ych0/php-fpm) to use with Laravel

Contains the following extensions:

* bcmath
* calendar
* Core
* ctype
* curl
* date
* dom
* ds
* exif
* fileinfo
* filter
* ftp
* gd
* gettext
* gmp
* hash
* iconv
* igbinary
* imagick
* intl
* json
* libxml
* mbstring
* mongodb
* mysqlnd
* openssl
* pcntl
* pcre
* PDO
* pdo_mysql
* pdo_pgsql
* pdo_sqlite
* pgsql
* Phar
* posix
* psr
* raphf
* readline
* redis
* Reflection
* session
* SimpleXML
* soap
* sockets
* sodium
* SPL
* sqlite3
* standard
* swoole
* tokenizer
* xml
* xmlreader
* xmlwriter
* zip
* zlib
* Zend OPcache + optional preload set with env var _PHP_OPCACHE_PRELOAD=path/to/preload.php_

you may want to change the entrypoint to run supervisord
