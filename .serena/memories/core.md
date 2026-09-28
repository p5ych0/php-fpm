# php-fpm repo — core

Docker image build repo for PHP runtimes used as base images by other (Laravel) projects. No app code of its own.

## Branch model
- One long-lived branch per image variant: `v8.4-zts-alpine` (active), `v7.4-fpm`, `v7.3-fpm`, `v5.6-fpm`, `v8.0-cli`, `browscap`, `cli`.
- `master` is stale (2021); do NOT branch from or PR into it for variant work. Commit on the variant branch.
- Repo/dir name says "fpm", but the v8.4 branch image is CLI + ZTS (no php-fpm binary, no FPM pool). `www.conf`, `getcomposer.sh` are legacy leftovers not used by the Dockerfile.

## Source map (v8.4-zts-alpine)
- `Dockerfile` — 2 stages, both `FROM php:8.4-zts-alpine` (floating tag; minor + Alpine versions move under you). Builder compiles exts; final stage copies `/usr/local/lib/php/extensions/` + `conf.d/` only, so runtime libs must be added separately to final-stage `apk add`.
- `docker-entrypoint.sh` — runtime uid/gid mapping (PUID/PGID/USER_NAME/GROUP_NAME required), log symlinks into `storage/logs`, supervisor/cron user rewrite, OPcache + browscap ini generation, then `su-exec` to mapped user (except `sh|bash|supervisord`).
- `supervisor/*.ini`, `cron/root` — queue workers + scheduler; placeholders rewritten by entrypoint.
- `scripts/octane-start.sh` — builds `octane:start --server=swoole` args from OCTANE_* env.
- `examples/*.php` — standalone extension smoke tests runnable in the image.
- `docker-compose*.yml`, `test-plan.md` — Laravel 12 Octane/Reverb/queue validation stack against local `laravel-app/` (gitignored).

## Further memories
- Extension set, base image, version pins and their build quirks: `mem:tech_stack`
- Build/test/run commands: `mem:suggested_commands`
- Publishing images to Docker Hub (repo names, tag scheme): `mem:release`
- Dockerfile/entrypoint editing conventions: `mem:conventions`
- Verification required before calling a change done: `mem:task_completion`
