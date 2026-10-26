# PHP security deployment notes

Reviewed on 26 October 2026.

## Current protection

- PHP 8.3.36 fixes CVE-2026-109618 and CVE-2026-109619. Keep the existing build-time runtime check.
- CVE-2026-115560 has no released upstream fix listed in PHP's 23 October advisory. Keep `session.upload_progress.enabled = 0` in server-level PHP configuration until the upstream fix is released and deployed. Do not remove it just because PHP is 8.3.36.
- PHP describes a narrow trigger: configuration selects `php_binary` or `php_serialize`, application code switches to `php` with `ini_set()` before `session_start()`, and session upload progress is enabled.
- FrankenPHP 1.13.3 includes the fixes released in 1.13.2 for GHSA-ccgp-ch9h-533f, GHSA-4gfw-9v29-gp9h, GHSA-fq24-r53r-xcx3 and GHSA-6q3j-62j9-f9hh. Some require worker mode, application-specific calls, or embedded applications. Pinning the server version avoids relying on a PHP-only tag to select a fixed FrankenPHP release.
- Disabling PHP's session upload tracking does not disable file uploads. Test any plugin that uses session-based upload progress.

The live WordPress installation, plugins and themes are mounted from `APP_DIR_PATH` and are not contained in this repository. Their versions and runtime session changes were not audited. The running container version is also not available from repository configuration alone.

## Deploy and verify

Use the actual production environment file if its name differs:

```sh
docker compose --env-file .env.prod -f compose.prod.yml build --pull --no-cache php
# Continue only after a successful build.
docker compose --env-file .env.prod -f compose.prod.yml up -d --no-deps --force-recreate php
docker compose --env-file .env.prod -f compose.prod.yml exec -T php frankenphp version
docker compose --env-file .env.prod -f compose.prod.yml exec -T php frankenphp php-cli -r 'echo "PHP ", PHP_VERSION, PHP_EOL; var_export(ini_get("session.upload_progress.enabled")); echo PHP_EOL;'
```

Expect FrankenPHP 1.13.3, PHP 8.3.36, and upload progress disabled (normally `'0'`). Recreating the container restarts all PHP threads and loads the new INI. Merging alone does not update production.

Confirm the PHP version in WordPress Site Health and smoke-test page rendering, login, and uploads through the web server. If checking effective INI over HTTP, use a temporary access-restricted diagnostic and remove it afterwards; do not expose phpinfo publicly.

## Upstream references

- https://www.php.net/archive/2026.php#2026-10-23-1
- https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- https://github.com/php/frankenphp/releases/tag/v1.13.2
- https://github.com/php/frankenphp/releases/tag/v1.13.3
- https://github.com/php/frankenphp/security/advisories

Check the next stable PHP bugfix release against the full CVE-2026-115560 advisory before removing the mitigation.
