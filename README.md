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
* raphf
* rdkafka
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

## HTTP healthcheck

The example Laravel app ships with a `/health` route that exercises key dependencies and reports structured results:

* `redis`: Confirms the configured Redis connection responds to `PING`.
* `queue`: Reuses the Redis queue connection (if the default driver is `redis`). Other drivers are reported as `skipped`.
* `storage_logs`: Verifies `storage/logs` exists and is writable by the runtime user.
* `database`: Optional check (disabled by default). Set `HEALTHCHECK_DATABASE=1` in the Octane container to enable a simple `SELECT 1` probe against the configured default connection. When disabled, the response marks it as `skipped` so health does not fail in environments without a database.

The overall HTTP status is `200` when all non-skipped checks pass; otherwise it returns `503` with the failing details. All Compose files use a `CMD-SHELL` probe that runs:

```sh
curl -fsS --max-time 5 http://127.0.0.1:${OCTANE_PORT:-8000}/health
```

Feel free to extend the JSON payload with domain-specific checks (cache stores, downstream APIs, etc.)—the `curl` command only cares that the endpoint responds successfully.

## Laravel validation workflow (Octane + Parallel + Reverb)

The `docker-compose.yml` in this repo spins up Redis, Octane, a queue worker, and Reverb against a mounted `./laravel-app` directory. The quickest way to rebuild and validate the stack is:

```bash
rm -rf laravel-app && mkdir -p laravel-app

# Always let the image entrypoint run – do NOT pass --entrypoint ""
docker run --rm -e PUID=$(id -u) -e PGID=$(id -g) -e USER_NAME=$USER -e GROUP_NAME=$USER \
  -v "$PWD/laravel-app":/var/www/html p5ych0/php-cli:8.4-zts \
  composer create-project laravel/laravel .

# Install Octane/Reverb and publish assets (entrypoint still enabled)
docker run --rm -v "$PWD/laravel-app":/var/www/html p5ych0/php-cli:8.4-zts \
  composer require laravel/octane laravel/reverb

docker run --rm -v "$PWD/laravel-app":/var/www/html p5ych0/php-cli:8.4-zts \
  php artisan octane:install --server=swoole

# Configure env (see docker/octane.env) and bring the stack up
docker compose up -d --build

# After installs, fix ownership so the host user can edit freely
chown -R $(id -u):$(id -g) laravel-app
```

Once the containers are healthy, hit the helper routes exposed by the example app:

```bash
curl -s http://127.0.0.1:8000/parallel-test
curl -s http://127.0.0.1:8000/redis-ping
curl -s http://127.0.0.1:8000/queue-dispatch
curl -s http://127.0.0.1:8000/health

# WebSocket smoke test (expect HTTP 400 with placeholder credentials)
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: testkey123==" \
  http://127.0.0.1:8080/app/test
```

### Pitfalls we keep running into

* **Never bypass the entrypoint.** It prepares `/var/log/php` and `storage/logs` symlinks. Running composer/artisan with `--entrypoint ""` leaves host-side symlinks pointing into the container image and Octane cannot write logs.
* **Start from a clean `laravel-app/`.** Remove the directory before each rebuild so entrypoint-generated symlinks and failed installs do not linger.
* **Queue + Redis must be running before hitting `/queue-dispatch`.** The route immediately pushes a job and expects the `queue-worker` service to pick it up.
* **Reverb handshake returns HTTP 400 when `REVERB_APP_ID/KEY/SECRET` are placeholders.** Treat the deterministic `Application does not exist` message as success; you’ll see `101 Switching Protocols` only with real credentials.
* **Disable the DB probe when no database is present.** Leave `HEALTHCHECK_DATABASE=false` (Octane container env) so `/health` marks the DB check as `skipped` instead of failing the entire probe.
* **Composer stays inside the container.** This guarantees the bundled PHP extensions (Swoole, parallel, Redis) are available and prevents host PHP version drift.

### Optional Browscap (user agent capability database)

Browscap can be enabled dynamically without baking it into the image. Set `BROWSCAP_ENABLE=1` to trigger download at container start; the entrypoint manages caching and refresh based on `BROWSCAP_TTL` (default 604800 seconds).

Environment variables:

* `BROWSCAP_ENABLE` (0/1, default 0) – turn on browscap management.
* `BROWSCAP_VARIANT` (full|standard|lite, default standard) – selects upstream stream.
* `BROWSCAP_SOURCE_URL` (optional) – override auto-generated URL.
* `BROWSCAP_PATH` (default /usr/local/etc/php/browscap/browscap.ini) – target file.
* `BROWSCAP_TTL` (default 604800) – max age before refresh.
* `BROWSCAP_FORCE_REFRESH` (0/1) – ignore TTL and re-download.

When enabled, an ini fragment `zz-browscap-env.ini` is written with `browscap=/path/to/file`. Use `get_browser()` in PHP (ensure `browscap` directive is set). Example test script:

```php
<?php
var_dump(get_browser(null, true));
```

Minimal docker run example to enable browscap:

```bash
docker run --rm -e BROWSCAP_ENABLE=1 -v "$PWD":/var/www/html php-fpm:8.4-zts-alpine php -r 'echo json_encode(get_browser(null, true), JSON_PRETTY_PRINT), "\n";'
```
