#!/bin/sh
set -e

# Only modify user/group in development mode
if [ "${APP_ENV:-production}" = "development" ]; then
    # Get host user ID and group ID (default to 1000 if not set)
    USER_ID=${WWWUSER:-1000}
    GROUP_ID=${WWWGROUP:-1000}

    # Ensure IDs are >= 1000
    if [ "$USER_ID" -lt 1000 ]; then
        USER_ID=1000
    fi
    if [ "$GROUP_ID" -lt 1000 ]; then
        GROUP_ID=1000
    fi

    # Update www-data user and group IDs
    usermod -u $USER_ID www-data
    groupmod -g $GROUP_ID www-data
fi

exec "$@" 