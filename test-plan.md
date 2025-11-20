# Laravel 12 + Octane (Swoole) + Parallel + Reverb Container Validation Plan

## Goals

Ensure the built image supports a real Laravel 12 application using:

- Octane on Swoole (HTTP server, request handling)
- Parallel extension for concurrent CPU-bound tasks inside app code
- Reverb (WebSockets/Broadcast server) startup
- Supervisor-based management (optional future) for queue/reverb workers
- Runtime user mapping (host user 1000 or www-data 82) with correct log/file permissions

## Test Matrix

| Area | Scenario | Expected Result |
|------|----------|----------------|
| User Mapping | Container with host UID/GID | Files owned by host user; artisan commands succeed |
| Extensions | php -m & feature checks | swoole, parallel, redis, mongodb, imagick present |
| Laravel Install | create-project | Fresh Laravel skeleton created in mounted volume |
| Octane Install | `octane:install` | Swoole server scripts generated; config published |
| Reverb Install | `reverb:install` | Reverb config & assets published; start command succeeds |
| Parallel Route | Custom route /parallel-test | Returns aggregated results from parallel tasks |
| Octane Server | `octane:start` | Accepts HTTP requests on chosen port (8000) |
| Reverb Server | `reverb:start` | Process starts; port listens (default 8080/REVERB_PORT) |
| Redis Ping | `/redis-ping` route | Returns JSON `{"pong":"PONG"}` |
| Queue Dispatch | `/queue-dispatch` route & worker | Job logged in `storage/logs/laravel.log` |
| WebSocket Handshake | `curl` upgrade request | HTTP 101 with real Reverb credentials; otherwise deterministic HTTP 400 "Application does not exist" when using placeholder keys (acceptable smoke test) |
| Permissions | Write to /var/log/php & /storage/logs | Group-writable; no permission errors |
| Healthcheck | HTTP probe `curl 127.0.0.1:$PORT/health` | HTTP 200, body includes `{"ok":true,"checks":{"redis":{"status":"ok"},…}}` |

## Steps

1. Bootstrap Laravel project in `laravel-app/` directory mounted to `/var/www/html` in container. **Do not override the image entrypoint when running composer/artisan**—it prepares `/var/log/php` symlinks and runtime permissions before your command executes.
2. Install Octane & Reverb packages via composer, run respective install commands.
3. Add/verify helper routes in `routes/web.php` (parallel test + `/health` JSON endpoint with Redis/queue/storage probes and optional DB check).
4. Start Octane (Swoole) server and curl both `/` and `/parallel-test`.
5. Start Reverb server independently to confirm process spawn (smoke test).
6. Start queue worker via supervisor (or foreground) and dispatch job using `/queue-dispatch`.
7. Run Redis ping route `/redis-ping` (requires Redis container running and reachable).
8. Perform WebSocket handshake test against Reverb port (101 response expected).
9. Validate the `/health` endpoint inside the Octane container with the same curl command Compose uses and confirm each `checks.*.status` is `ok` (or `skipped` for disabled probes).
10. Inspect ownership/permissions of generated files and logs.
11. Summarize results.

## Known Pitfalls & Workarounds

- **Let the entrypoint run for every `docker run … composer|php artisan …` call.** Using `--entrypoint ""` skips the init logic that sets up `/var/log/php` and `storage/logs` symlinks, which leaves broken links on the host and causes queue/log writes to fail. Stick with `docker run --rm p5ych0/php-cli:8.4-zts …` (or the build tag you are validating) so the entrypoint finishes first.
- **Nuke and recreate `laravel-app/` before new installs.** The entrypoint lays down symlinks relative to `/var/www/html`; reusing a partially created app (especially after a failed composer run) leaves root-owned files and stale symlinks. Use `rm -rf laravel-app && mkdir -p laravel-app` prior to `composer create-project`.
- **Run composer inside the container and fix ownership once.** After create-project and package installs, run `chown -R $(id -u):$(id -g) laravel-app` so local edits/IDE tooling can modify the tree without sudo.
- **Queue/Redis dependencies must be up before hitting `/queue-dispatch`.** The route immediately attempts to push a Redis-backed job and expect a running queue worker (e.g., the `queue-worker` service). Hitting it without Redis or the worker yields a 500 and clutters logs.
- **Healthcheck database probe is optional.** Set `HEALTHCHECK_DATABASE=false` (default) whenever no DB container is available so the `/health` endpoint reports the DB check as `skipped` instead of `failed`.
- **Reverb smoke test expectations.** With placeholder `REVERB_APP_ID/KEY/SECRET`, the WebSocket probe returns `HTTP/1.1 400 Application does not exist`. Treat this as success (it proves the server is listening); only expect `101 Switching Protocols` once real credentials and channel/app IDs are configured.

## Parallel Test Route Sample (Concept)

```php
Route::get('/parallel-test', function() {
  $tasks = [10, 20, 25];
  $runtimes = [];
  foreach ($tasks as $n) {
    $rt = new \parallel\Runtime();
    $runtimes[] = [$rt, $rt->run(function($x){
      $fib = function($n){ $a=0;$b=1; for($i=0;$i<$n;$i++){ $tmp=$a+$b; $a=$b; $b=$tmp;} return $a;};
      return ['n'=>$x,'fib'=>$fib($x)];
    }, [$n])];
  }
  $results = [];
  foreach ($runtimes as [$rt,$future]) { $results[] = $future->value(); }
  return response()->json(['parallel'=>$results,'user'=>getenv('USER_NAME')]);
});
```

## Commands Cheat Sheet

Container image reference: `php-fpm:8.4-zts-octane-test`

```bash
# 1. Create target directory
mkdir -p laravel-app

# 2. Composer create-project (host user mapping)
docker run --rm -e PUID=$(id -u) -e PGID=$(id -g) -e USER_NAME=$USER -e GROUP_NAME=$USER \
  -v "$PWD/laravel-app":/var/www/html php-fpm:8.4-zts-octane-test \
  composer create-project laravel/laravel .

# 3. Install Octane & Reverb
docker run --rm -v "$PWD/laravel-app":/var/www/html php-fpm:8.4-zts-octane-test \
  composer require laravel/octane laravel/reverb

docker run --rm -v "$PWD/laravel-app":/var/www/html php-fpm:8.4-zts-octane-test \
  php artisan octane:install --server=swoole

docker run --rm -v "$PWD/laravel-app":/var/www/html php-fpm:8.4-zts-octane-test \
  php artisan reverb:install

# 4. Add parallel route
# (Apply patch or manual edit to laravel-app/routes/web.php)

# 5. Start Octane server (foreground test)
docker run --rm -p 8000:8000 -e PUID=$(id -u) -e PGID=$(id -g) -e USER_NAME=$USER -e GROUP_NAME=$USER \
  -v "$PWD/laravel-app":/var/www/html php-fpm:8.4-zts-octane-test \
  php artisan octane:start --server=swoole --host=0.0.0.0 --port=8000 --workers=2 &

# 6. Curl test routes (after small delay)
curl -s http://localhost:8000/ | head -n 20
curl -s http://localhost:8000/parallel-test

# (Optional) Redis service start (example using official image)
docker run -d --name test-redis -p 6379:6379 redis:7-alpine

# 7. Redis ping & queue dispatch (ensure queue worker running in separate container or supervisor)
curl -s http://localhost:8000/redis-ping
curl -s http://localhost:8000/queue-dispatch

# 8. WebSocket handshake test (Reverb on 8080)
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: testkey123==" http://localhost:8080/app/CHANNEL

# 7. Healthcheck (same as compose)
docker compose exec octane \
  sh -c 'curl -fsS --max-time 5 http://127.0.0.1:${OCTANE_PORT:-8000}/health'

# Reverb server (smoke)
docker run --rm -p 8080:8080 -e REVERB_ENABLE=1 -e REVERB_PORT=8080 -v "$PWD/laravel-app":/var/www/html \
  php-fpm:8.4-zts-octane-test php artisan reverb:start --host=0.0.0.0 --port=8080 &

# Permissions audit
ls -ld laravel-app/storage/logs
ls -l laravel-app/storage/logs
```

## Acceptance Criteria

- All artisan commands succeed without permission errors.
- Octane responds to HTTP requests and parallel route returns computed JSON.
- Reverb process starts (even if no clients connected).
- Healthcheck returns exit code 0.
- No root-owned artifacts left in project (expect mapped user ownership).

## Notes

- For a full production test, queue workers and broadcasting would be validated with a running Redis or other broker; omitted here for scope.
- Reverb functionality beyond process start not asserted (websocket handshake tests can be added later).
- Parallel computations kept small to avoid excessive CPU time during the smoke test.
- Set `HEALTHCHECK_DATABASE=1` on the Octane service only when a reachable database exists; otherwise leave it unset so the DB probe remains `skipped`.
