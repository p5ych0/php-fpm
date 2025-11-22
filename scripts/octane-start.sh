#!/bin/sh
set -e

ARGS="php artisan octane:start --server=swoole"
if [ -n "${OCTANE_MAX_REQUESTS:-}" ]; then
  ARGS="$ARGS --max-requests=${OCTANE_MAX_REQUESTS}"
fi
if [ "${OCTANE_WORKERS:-0}" -gt 0 ]; then
  ARGS="$ARGS --workers=${OCTANE_WORKERS}"
fi
if [ "${OCTANE_TASK_WORKERS:-0}" -gt 0 ]; then
  ARGS="$ARGS --task-workers=${OCTANE_TASK_WORKERS}"
fi
if [ "${OCTANE_WATCH:-false}" = "true" ]; then
  ARGS="$ARGS --watch"
fi

set -- $ARGS "$@"
exec "$@"
