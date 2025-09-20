# PHP-FPM Docker Image Modernization

## Overview
This PHP-FPM Docker image has been completely modernized to match OpenResty-style runtime configuration and includes comprehensive supervisor support for Laravel applications.

## Key Features

### 1. OpenResty-Compatible Runtime User Management
- **Environment Variables**: `PUID`, `PGID`, `USER_NAME`, `GROUP_NAME`
- **Default Values**: PUID=82, PGID=82, USER_NAME=www-data, GROUP_NAME=www-data
- **Intelligent Handling**: Automatically handles existing users/groups and UID/GID conflicts
- **Runtime Creation**: Users and groups created at container startup, not build time

### 2. Supervisor Integration for Laravel
- **Multi-Mode Operation**: Supports both `php-fpm` (default) and `supervisord` commands
- **Dynamic Worker Scaling**: Use `NUMPROCS` environment variable to control queue workers
- **Process Isolation**: Workers run as custom user, supervisor runs as root
- **Template-Based Config**: supervisor/laravel.ini.template with environment variable substitution

### 3. Dynamic Configuration System
- **Template Processing**: All configuration files use templates with envsubst
- **Runtime Flexibility**: No rebuild required for configuration changes
- **Configuration Files**:
  - `www.conf.template` → PHP-FPM pool configuration
  - `root.template` → Cron jobs
  - `laravel.ini.template` → Supervisor configuration
  - `docker-php-ext-opcache.ini.template` → OPcache settings

### 4. Environment Variable Configuration

#### Required Variables
- `PUID` - User ID (default: 82)
- `PGID` - Group ID (default: 82)
- `USER_NAME` - Username (default: www-data)
- `GROUP_NAME` - Group name (default: www-data)

#### Optional Variables
- `NUMPROCS` - Number of queue worker processes (default: 1)
- `PHP_OPCACHE_PRELOAD` - OPcache preload script path (default: empty)
- `PHP_OPCACHE_FREQ` - OPcache revalidation frequency (default: 600)

## Usage Examples

### Basic PHP-FPM Mode
```bash
docker run -d \
  -e PUID=1000 \
  -e PGID=1000 \
  -e USER_NAME=appuser \
  -e GROUP_NAME=appgroup \
  -v /path/to/laravel:/var/www/html \
  php-fpm:latest
```

### Supervisor Mode with Queue Workers
```bash
docker run -d \
  -e PUID=1000 \
  -e PGID=1000 \
  -e USER_NAME=appuser \
  -e GROUP_NAME=appgroup \
  -e NUMPROCS=3 \
  -v /path/to/laravel:/var/www/html \
  php-fpm:latest supervisord
```

### With OPcache Preloading
```bash
docker run -d \
  -e PUID=1000 \
  -e PGID=1000 \
  -e PHP_OPCACHE_PRELOAD=/var/www/html/bootstrap/cache/opcache.php \
  -e PHP_OPCACHE_FREQ=300 \
  -v /path/to/laravel:/var/www/html \
  php-fpm:latest
```

## Docker Compose Integration

The included `docker-compose.example.yml` demonstrates both modes:

1. **Single Service Mode**: PHP-FPM only
2. **Supervisor Mode**: PHP-FPM + Queue Workers + Cron (use `--profile supervisor`)

## Migration from Previous Versions

1. **User Management**: Replace any manual user creation with environment variables
2. **Configuration**: Update any hardcoded paths to use template variables
3. **Supervisor**: Use `supervisord` command instead of custom supervisor setup
4. **OPcache**: Set `PHP_OPCACHE_PRELOAD` and `PHP_OPCACHE_FREQ` as environment variables

## Architecture Benefits

- **Production Ready**: Proper process isolation and user management
- **Flexible Deployment**: Same image for development and production
- **Laravel Optimized**: Queue workers, cron scheduler, OPcache preloading
- **Security Focused**: Non-root user execution, proper file permissions
- **Resource Efficient**: Alpine-based with minimal footprint
- **Monitoring Ready**: FPM status pages, slow query logs, supervisor logs

## Technical Details

- **Base Image**: `php:7-fpm-alpine`
- **PHP Extensions**: 56+ extensions including Redis with igbinary support
- **Process Management**: FPM static/dynamic pools + supervisor for background tasks
- **Logging**: Separate logs for FPM pools, supervisor, and slow queries
- **Health Checks**: FPM status endpoints for load balancer integration