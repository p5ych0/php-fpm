# PHP-FPM Docker Image - AI Assistant Instructions

## Project Overview
This repository builds a production-ready PHP-FPM Docker image specifically optimized for **Laravel applications**. The image includes extensive PHP extensions, process management, and monitoring capabilities across multiple PHP versions via feature branches.

## Architecture & Branch Strategy
- **Branch-based versioning**: Each PHP version has its own branch (v7.4-fpm, v8.0-cli, v8.4-zts-alpine, etc.)
- **Current branch**: `v7.4-fpm` (PHP 7.4 with FPM)
- **Base image**: `php:7-fpm-alpine` for minimal footprint
- **Multi-pool configuration**: Two FPM pools (main www on port 9000, backoffice on port 9099)

## Key Components

### Docker Build Process (`Dockerfile`)
- **Two-stage dependency management**: Build deps are installed and removed to minimize image size
- **Custom extension compilation**: Redis extension compiled with igbinary support (`--enable-redis-igbinary`)
- **Laravel-specific tools**: Composer and PHPUnit pre-installed in `/usr/local/bin/`
- **Security-focused**: Uses `www-data` user, proper file permissions

### FPM Configuration (`www.conf`)
**Critical settings pattern**:
- `pm = static` with `pm.max_children = 32` for main pool
- `pm = dynamic` for backoffice pool (9099) with different memory limits
- `clear_env = no` (Laravel needs environment variables)
- Request limits: `pm.max_requests = 200` prevents memory leaks
- Monitoring: Slow log enabled (`request_slowlog_timeout = 10s`)

### Process Management (`supervisor/laravel.ini`)
**Laravel-specific supervisord config**:
- Queue workers: `artisan queue:work --timeout=60 --tries=5`
- Dynamic worker count via `ENV_NUMPROCS` environment variable
- Cron daemon for scheduled tasks

### Cron Jobs (`cron/root`)
**Laravel scheduler pattern**:
```bash
* * * * * sudo -u www-data /usr/local/bin/php /var/www/html/artisan schedule:run
30 */2 * * * sudo -u www-data /usr/local/bin/php /var/www/html/artisan queue:restart
```

## Extension Management
**Comprehensive Laravel stack**:
- **Database**: PDO MySQL, PostgreSQL, MongoDB
- **Caching**: Redis (with igbinary), OPcache (with preload support)
- **Image processing**: GD, Imagick
- **Data structures**: DS extension for advanced data types
- **HTTP**: PSR-7 compliant with PSR extension

## Environment Variables
- `PHP_OPCACHE_PRELOAD=""` - Path to preload script (Laravel optimization)
- `PHP_OPCACHE_FREQ=600` - Revalidation frequency
- `NUMPROCS` - Number of queue worker processes

## Development Patterns

### When modifying configurations:
1. **FPM pools**: Always test both www (9000) and backoffice (9099) pools
2. **Memory limits**: Different per pool (64M vs 128M) - respect Laravel's needs
3. **Process management**: Static for main, dynamic for backoffice (different load patterns)

### When adding extensions:
1. Add build dependencies to `.build-deps` section
2. Use `docker-php-ext-install` for core extensions
3. Use `pecl install` for PECL extensions
4. Enable with `docker-php-ext-enable`
5. Clean up build deps to maintain image size

### Branch workflow:
- Each PHP version maintains separate branches
- Test changes against Laravel applications requiring specific PHP versions
- Consider backward compatibility when modifying core configurations

## Monitoring & Debugging
- **FPM status**: Available via status path configuration
- **Slow query log**: `/var/log/php/slow.www.log` and `/var/log/php/slow.back.log`
- **Error logs**: Separate logs per pool for easier debugging
- **Supervisor logs**: Queue worker output in `/var/log/supervisor/supervisor.log`

## Security Considerations
- All processes run as `www-data` user
- File permissions strictly controlled (0775 for logs, 0600 for cron)
- Environment variables properly isolated per pool
- Extensions compiled with security flags where applicable