# Done criteria

No linter/unit test suite. A Dockerfile/entrypoint change is done only after:
1. `docker build --pull` succeeds (watch PECL/imagick compile steps — unpinned, most likely to break on base bumps).
2. `php -m` shows every ext from the Dockerfile enable list, no startup warnings on stderr; compare against previous release tag's `php -m`.
3. Functional smoke: `examples/test_extensions.php` (+ parallel/swoole examples); imagick PDF read works (needs ghostscript).
4. Laravel stack per `test-plan.md`: octane serves `/`, `/parallel-test`, `/redis-ping`, `/health` (all checks ok/skipped); queue worker runs under mapped user; reverb listens; files in `laravel-app/storage` owned by host uid.
5. Only then push (see `mem:release`).
