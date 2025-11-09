<?php
// Minimal Swoole HTTP server for testing. Binds to PORT env (default 9501)
// Responds with uid/gid and names to verify runtime user mapping.

if (!extension_loaded('swoole')) {
    fwrite(STDERR, "Swoole extension not loaded\n");
    exit(2);
}

$port = getenv('PORT') ?: '9501';
$host = getenv('HOST') ?: '0.0.0.0';

$server = new Swoole\HTTP\Server($host, (int)$port);

$server->on('request', function ($request, $response) use ($port) {
    $uid  = function_exists('posix_geteuid') ? posix_geteuid() : getmyuid();
    $gid  = function_exists('posix_getegid') ? posix_getegid() : getmygid();
    $user = function_exists('posix_getpwuid') ? (posix_getpwuid($uid)['name'] ?? '') : get_current_user();
    $grp  = function_exists('posix_getgrgid') ? (posix_getgrgid($gid)['name'] ?? '') : '';

    $payload = [
        'ok' => true,
        'port' => (int)$port,
        'uid' => $uid,
        'gid' => $gid,
        'user' => $user,
        'group' => $grp,
        'extensions' => [
            'swoole' => extension_loaded('swoole'),
            'uv' => extension_loaded('uv'),
            'parallel' => extension_loaded('parallel'),
        ],
    ];

    $response->header('Content-Type', 'application/json');
    $response->end(json_encode($payload));
});

$server->start();
