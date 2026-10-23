# Debian 12 / PHP 8.2 porting status

This document tracks the Debian 12 (Bookworm) port of the i-MSCP 1.9.00.x
branch. Debian 12 ships PHP 8.2, so this port must validate both the installer
and the web GUI against that runtime.

## Status

**Work in progress — Debian 12 is not yet declared supported.** Do not use this
branch for production installs until the checks below pass on a clean Bookworm
system and an upgrade test system.

## Confirmed blockers

- `gui/composer.json` restricts PHP to `>=7.3 <7.4`.
- The Composer requirements include `ext-apc`; APC is not a viable PHP 8.2
  extension requirement. Audit the code to determine whether APCu alone is
  sufficient before removing this requirement.
- The lock file pins `cweagans/composer-patches 1.6.7`, which predates Composer
  2 support, and `imscp/composer-installers 1.0.0`, which requires Composer
  Plugin API 1.x and PHP 7.1. The installer plugin is i-MSCP-specific, so it
  must be migrated or patched rather than blindly replaced.
- The frontend uses Zend Framework 1.12.20 and existing local patches. PHP 8.2
  runtime compatibility and patch application have not yet been verified.
- The documented Debian support list ends at Debian 10 (Buster).

## Porting sequence

1. Make the Composer dependency graph installable with PHP 8.2 and Composer 2;
   regenerate and commit `gui/composer.lock` from Composer rather than editing
   the lock metadata by hand.
2. Audit PHP source and patched vendor code for removed functions, incompatible
   signatures, dynamic-property deprecations, and PHP 8 type errors.
3. Audit Debian adapter package names, service names, configuration paths, and
   mail/DNS/web/database integration against Bookworm.
4. Run Composer install with scripts and patches enabled; lint all PHP files.
5. Test a fresh install and an upgrade from the previous supported release on
   disposable Debian 12 VMs. Verify web login, domain/vhost provisioning, DNS,
   mail, FTP, database, cron/daemon, backups, and updates.
6. Only after those checks pass, add Debian 12 to the supported-version list.

## Validation log

- [x] Created isolated branch `port/debian12-php82` from `1.9.00.x`.
- [x] Reviewed Composer manifest/lock and Debian installation documentation.
- [ ] Composer dependency migration completed.
- [ ] PHP 8.2 static/runtime audit completed.
- [ ] Debian 12 installer and service integration tested.
- [ ] Fresh-install and upgrade tests passed.
