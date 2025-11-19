#!/bin/sh
# Simple healthcheck: ensure critical extensions are loaded and log dir writable.
set -e
php -r 'if(!extension_loaded("swoole")) exit(10); if(!extension_loaded("parallel")) exit(11); if(!extension_loaded("redis")) exit(12); if(!extension_loaded("mongodb")) exit(13); if(!is_writable("/var/log/php")) exit(14); file_put_contents("/var/log/php/.healthcheck","ok");'
exit 0
