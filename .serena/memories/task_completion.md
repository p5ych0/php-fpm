# Done criteria

No linter/unit test suite. A Dockerfile/entrypoint change is done only after:
1. `docker build --pull` succeeds (watch PECL/imagick compile steps — unpinned, most likely to break on base bumps).
2. `php -m` shows every ext from the Dockerfile enable list, no startup warnings on stderr; compare against previous release tag's `php -m`. Also diff `phpversion()` per PECL ext vs previous release — flag any major bump.
3. Functional smoke with the FULL ini set loaded (ext interactions matter: parallel only crashes when swoole is also loaded — `php -n -d extension=parallel` hides it). Must include `new \parallel\Runtime()` + `->run()->value()`, and imagick PDF read (needs ghostscript).
4. `examples/*.php`: compare against the previous release tag, not against "all pass". Known pre-existing script failures: test_extensions (`psr` ext not installed), test_parallel (uncaught intentional exception), test_swoole (`Barrier::wait()` missing arg).
5. Laravel stack per `test-plan.md`: octane serves `/`, `/parallel-test` (parallel inside swoole worker), `/redis-ping`, `/health` (all checks ok/skipped); queue job processed; reverb handshake 101 (or 400 with placeholder creds); files in `laravel-app/storage` owned by host uid.
6. Only then push (see `mem:release`).

Why pin checks exist: `mem:tech_stack` "Pins and why".
