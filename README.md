# php-fpm

![DockerHub](https://img.shields.io/docker/automated/p5ych0/php-fpm.svg) Dockerfile for [PHP-FPM](https://hub.docker.com/r/p5ych0/php-fpm) to use with Laravel

Contains the following extensions:

* bcmath
* calendar
* ctype
* curl
* date
* dom
* ds
* exif
* fileinfo
* filter
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
* openssl
* pcntl
* pcre
* PDO
* pdo_mysql
* pdo_pgsql
* pgsql
* Phar
* posix
* psr
* raphf
* redis
* Reflection
* session
* SimpleXML
* soap
* sockets
* SPL
* standard
* swoole
* tokenizer
* uv
* parallel
* xml
* xmlreader
* xmlwriter
* zip
* zlib
* Zend OPcache + optional preload set with env var _PHP_OPCACHE_PRELOAD=path/to/preload.php_

## Runtime user/group mapping

To avoid permission issues between your host and the container, you can map the container user to your host user via environment variables. Fallback aliases are also supported to ease migration:

Primary vars (with defaults):

* PUID (fallback CUID): numeric user id (default 82)
* PGID (fallback CGID): numeric group id (default 82)
* USER_NAME (fallback CUSER): username (default www-data)
* GROUP_NAME (fallback CGROUP): group name (default www-data)
* NUMPROCS: supervisor worker count (default 1)
* PHP_OPCACHE_PRELOAD: path to preload script (optional)
* PHP_OPCACHE_FREQ: opcache.revalidate_freq (default 600)

Example with Docker Compose (see `docker-compose.example.yml`):

```yaml
services:
  php:
    build: .
    environment:
      # Primary names
      PUID: ${UID:-1000}
      PGID: ${GID:-1000}
      USER_NAME: ${USER:-ck}
      GROUP_NAME: ${GROUP:-ck}
      # Or use legacy/fallback names (CUID/CGID/CUSER/CGROUP) interchangeably
      NUMPROCS: 4
      PHP_OPCACHE_PRELOAD: /var/www/html/preload.php
      PHP_OPCACHE_FREQ: 300
    volumes:
      - ./:/var/www/html
    command: ["php", "-v"]
```

The container will create or reuse the specified user/group at runtime and drop privileges for the provided command. This works for both CLI and Supervisor modes. Supervisor config is dynamically updated to reflect `USER_NAME` and `NUMPROCS` on startup.

### OPcache preload via environment

If `PHP_OPCACHE_PRELOAD` is set, an ini fragment is generated: `zz-opcache-env.ini` enabling preload and assigning `opcache.preload_user` to the runtime user. Adjust `PHP_OPCACHE_FREQ` to control `opcache.revalidate_freq`.
