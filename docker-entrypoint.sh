#!/bin/sh
set -e

# Only modify user/group in development mode
# Default APP_ENV is set to 'production' if not explicitly defined
if [ "${APP_ENV:-production}" = "development" ]; then
    # Get host user ID and group ID (default to 1000 if not set)
    USER_ID=${WWWUSER:-1000}
    GROUP_ID=${WWWGROUP:-1000}
    if [ -z "$USER_ID" ]; then
        USER_ID=1000
    fi
    if [ -z "$GROUP_ID" ]; then
        GROUP_ID=1000
    fi
    # Ensure IDs are >= 1000 to avoid conflicts with system-reserved IDs
    if [ "$USER_ID" -lt 1000 ]; then
        USER_ID=1000
    if [ "$GROUP_ID" -lt 1000 ]; then
        # Ensure group ID is >= 1000 to avoid conflicts with system groups
        GROUP_ID=1000
    fi

    # Update www-data user and group IDs
    if id "www-data" >/dev/null 2>&1; then
        # Check if www-data is running any processes
        if pgrep -u www-data >/dev/null 2>&1; then
        OLD_GID=$(getent group www-data | cut -d: -f3)
        groupmod -g $GROUP_ID www-data
        if [ "$OLD_GID" != "$GROUP_ID" ]; then
            find / -group $OLD_GID -exec chgrp -h $GROUP_ID {} \; || echo "Warning: Failed to update some file permissions for the new GID."
        fi
        else
            usermod -u $USER_ID www-data
        fi
        groupmod -g $GROUP_ID www-data
        usermod -u $USER_ID www-data
    else
        echo "User 'www-data' does not exist. Skipping usermod."
    fi
        usermod -u $USER_ID www-data
    else
        echo "User 'www-data' does not exist. Skipping usermod."
# Check if arguments are provided, otherwise print usage or set default behavior
if [ "$#" -eq 0 ]; then
    echo "No command provided. Exiting."
    exit 1
fi

exec "$@"
    groupmod -g $GROUP_ID www-data
fi

exec "$@" 