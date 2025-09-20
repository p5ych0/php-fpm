# Modern PHP-FPM Docker Image

This is a modernized PHP-FPM Docker image that supports running with host user UID/GID instead of the hardcoded www-data user.

## Key Features

- **Dynamic User Support**: Run with any UID/GID using build arguments
- **Modern Docker Practices**: Multi-stage builds, BuildKit cache mounts, heredoc syntax
- **Same Extensions**: All original PHP extensions preserved
- **Laravel Optimized**: Includes Composer, PHPUnit, and Laravel-specific configurations

## Build Arguments

- `USER_ID`: UID for the container user (default: 1000)
- `GROUP_ID`: GID for the container user (default: 1000)
- `USERNAME`: Username for the container user (default: appuser)

## Usage Examples

### Build with Host UID/GID

```bash
# Build with your current user UID/GID
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  --build-arg USERNAME=$(whoami) \
  -t my-php-fpm .
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  php-fpm:
    build:
      context: .
      args:
        USER_ID: ${UID:-1000}
        GROUP_ID: ${GID:-1000}
        USERNAME: ${USER:-appuser}
    volumes:
      - ./app:/var/www/html
    ports:
      - "9000:9000"
      - "9099:9099"
    environment:
      - ENV_NUMPROCS=4
```

```

Then run with:

```bash

### Environment Variables

Set these when running the container:

- `ENV_NUMPROCS`: Number of queue worker processes (default: 1)
- `PHP_OPCACHE_PRELOAD`: Path to OPcache preload script
- `PHP_OPCACHE_FREQ`: OPcache revalidation frequency (default: 600)

## File Structure Changes

The modernized version uses template files that are processed at runtime:

- `www.conf.template` → `www.conf` (with dynamic user substitution)
- `cron/root.template` → `cron/root` (with dynamic user substitution)
- `supervisor/laravel.ini.template` → `supervisor/laravel.ini` (with dynamic user substitution)

## Migration from Old Version

If you're migrating from the old hardcoded www-data version:

1. Backup your current configuration
2. Build the new image with your desired UID/GID
3. Update any volume mounts to use the new user permissions
4. Test that file permissions work correctly

## Backward Compatibility

To maintain compatibility with existing setups that expect www-data (UID 82):

```bash
```bash
docker build \
  --build-arg USER_ID=82 \
  --build-arg GROUP_ID=82 \
  --build-arg USERNAME=www-data \
  -t my-php-fpm .
```