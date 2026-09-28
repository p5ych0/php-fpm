# Tech stack (v8.4-zts-alpine)

- Base: official `php:8.4-zts-alpine` (ZTS required by `parallel`). Tag floats: patch version AND default Alpine release change (e.g. 8.4.20/Alpine 3.23 -> 8.4.26/Alpine 3.24). Check both when rebuilding.
- Core exts via `docker-php-ext-install`: bcmath calendar intl exif gmp gettext mbstring pcntl pgsql pdo_pgsql pdo_mysql zip gd(freetype+jpeg) opcache soap sockets.
- PECL: igbinary ds raphf mongodb swoole uv rdkafka unpinned (latest at build time); `parallel` PINNED — see below.
- ds is 2.x (Seq/Map/Set/Heap/Pair + Key interface; Vector/Deque/Stack/Queue/PriorityQueue/Hashable removed). Downstream apps don't use Ds directly; symfony/uid auto-switches to `Ds\Key`. Changelog: https://github.com/php-ds/ext-ds/blob/master/CHANGELOG.md
- redis: built manually from `pecl download` with `--enable-redis-igbinary` (not `pecl install`).
- imagick: from PECL (3.8.1+; the GitHub `develop` branch is stale since 2025-03 and does not compile on PHP 8.5).
- `php.ini` sets `opcache.enable_cli=1`: Octane/Horizon/scheduler are CLI SAPI; without it OPcache and PHP_OPCACHE_PRELOAD are silently inactive in workers (was the case until 2026-09-28).
- Runtime-only apk deps in final stage: ghostscript (imagick PDF read), imagemagick, librdkafka, libuv, icu-libs, postgresql-libs, nodejs/npm (+ global chokidar-cli for `octane --watch`), supervisor, su-exec, shadow.
- ICU data is English-only (Alpine `icu-data-en`): non-en locales in intl silently fall back to en. Pre-existing, not a regression.
- Tooling baked in: composer (latest installer), phpunit.phar (latest).
- Target app stack: Laravel 12 + Octane (Swoole) + Reverb + Redis queues.
- amd64 only builds so far.

## Pins and why (do not unpin without re-testing)
- `parallel-1.2.13`: swoole's RINIT (`zm_activate_swoole` -> `swoole_set_task_tmpdir` -> `sw_tg_buffer()`) derefs a NULL thread-local buffer in any thread swoole didn't create, i.e. every `parallel\Runtime` thread. Upstream: https://github.com/swoole/swoole-src/issues/6262
  - parallel <=1.2.13 had a catch-all SIGSEGV handler that `zend_bailout()`ed past it; parallel >=1.2.14 (krakjoe/parallel#378) narrowed it, so `new Runtime()` kills the process.
  - The 1.2.13 recovery works ONLY if parallel loads before swoole. Holds today because `docker-php-ext-parallel.ini` sorts before `docker-php-ext-swoole.ini` in conf.d. Don't rename/reorder those ini files.
  - Side effect even when "working": RINIT of exts loaded after swoole (uv, zip, opcache) is skipped in parallel threads.
  - Unpin parallel once swoole ships a fix for #6262.
