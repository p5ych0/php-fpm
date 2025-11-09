#!/bin/sh
set -e
# Simple mock of artisan queue:work to validate supervisor running workers as mapped user.
echo "[artisan-mock] uid=$(id -u) user=$(id -un) gid=$(id -g) group=$(id -gn)"
sleep 2
echo "[artisan-mock] done"