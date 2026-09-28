# Commands

Build (always `--pull`, base tag floats):
- `docker build --pull -t p5ych0/php-cli:8.4-zts-alpine -t p5ych0/php-cli:<X.Y.Z>-zts-alpine-<YYYYMMDD> .`

Check upstream base version without pulling:
- `docker buildx imagetools inspect php:8.4-zts-alpine --format '{{json .Image}}'` -> `config.Env` PHP_VERSION
- Local: `docker image inspect php:8.4-zts-alpine --format '{{.Config.Env}}'`

Extension checks (entrypoint needs PUID/PGID/USER_NAME/GROUP_NAME — Dockerfile ENV provides defaults 82/www-data):
- `docker run --rm <img> php -m`
- `docker run --rm -v "$PWD/examples":/e <img> php /e/test_extensions.php` (also test_parallel.php, test_swoole.php)

Laravel integration stack: see `test-plan.md` / README "Laravel validation workflow". Run composer/artisan WITHOUT `--entrypoint ""` (entrypoint sets up log symlinks/perms).

Host notes: other projects' containers (strumok_*, pulse_*) run on this host from p5ych0/php-cli dated tags and hold host port 8080 — avoid host port publishing when testing, or use a separate compose project name.
