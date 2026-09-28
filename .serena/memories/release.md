# Publishing to Docker Hub

- Docker Hub user: `p5ych0`. v8.4 images go to `p5ych0/php-cli` (NOT `p5ych0/php-fpm`, which holds legacy `v7.4-fpm`, `v7.3-fpm`, etc. tagged by branch name).
- Tag scheme per release, both pointing at same digest:
  - floating: `8.5-zts-alpine` / `8.4-zts-alpine` (downstream projects build FROM these)
  - immutable: `<full php version>-zts-alpine-<YYYYMMDD>` e.g. `8.5.11-zts-alpine-20260928`
- Older scheme (`8.4-zts`, `8.4-zts-<date>`) is superseded; don't reuse.
- Pushing the floating tag changes what every downstream build pulls — confirm with user before pushing.
- Push only after checks in `mem:task_completion` pass.
