# Tech stack (v8.4-zts-alpine)

- Base: official `php:8.4-zts-alpine` (ZTS required by `parallel`). Tag floats: patch version AND default Alpine release change (e.g. 8.4.20/Alpine 3.23 -> 8.4.26/Alpine 3.24). Check both when rebuilding.
- Core exts via `docker-php-ext-install`: bcmath calendar intl exif gmp gettext mbstring pcntl pgsql pdo_pgsql pdo_mysql zip gd(freetype+jpeg) opcache soap sockets.
- PECL: igbinary ds raphf mongodb swoole uv parallel rdkafka (unpinned -> latest at build time).
- redis: built manually from `pecl download` with `--enable-redis-igbinary` (not `pecl install`).
- imagick: built from GitHub `develop` tarball (unpinned; reports `@PACKAGE_VERSION@` as its version — expected, not a failure).
- Runtime-only apk deps in final stage: ghostscript (imagick PDF read), imagemagick, librdkafka, libuv, icu-libs, postgresql-libs, nodejs/npm (+ global chokidar-cli for `octane --watch`), supervisor, su-exec, shadow.
- Tooling baked in: composer (latest installer), phpunit.phar (latest).
- Target app stack: Laravel 12 + Octane (Swoole) + Reverb + Redis queues.
- amd64 only builds so far.
