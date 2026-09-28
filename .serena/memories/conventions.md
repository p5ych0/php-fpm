# Conventions

- Dockerfile: builder stage installs `.build-deps` virtual pkg and `apk del`s it in the same RUN; final stage gets only runtime libs. Adding an ext => add `-dev` pkg to builder AND runtime lib to final stage, else `.so` fails to load at runtime.
- New PECL ext: append to both `pecl install` list and `docker-php-ext-enable` list.
- Entrypoint is POSIX `sh` (Alpine busybox), not bash. Every tunable is an env var with `${VAR:-default}`; document new ones in the header comment block and README.
- Entrypoint must stay idempotent across restarts (rm/recreate symlinks, sed rewrites of placeholders).
- Files created at runtime must be group-writable (umask 0002, setgid dirs) so host user + container user can share `storage/`.
- Commit messages: short imperative, optionally `area: ...` prefix (e.g. `runtime:`, `octane:`, `feat:`).
