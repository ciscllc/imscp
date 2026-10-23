# Debian 12 / PHP 8.2 porting status

This document tracks the Debian 12 (Bookworm) port of the i-MSCP 1.9.00.x
branch. Debian 12 ships PHP 8.2, so this port must validate both the installer
and the web GUI against that runtime.

## Status

**Work in progress — Debian 12 is not yet declared supported.** Do not use this
branch for production installs until the checks below pass on a clean Bookworm
system and an upgrade test system.

## Confirmed blockers

- `gui/composer.json` now targets PHP `^8.2`; the obsolete `ext-apc` platform
  requirement was removed because APC is not available as a PHP 8.2 extension.
  Audit application code for legacy `apc_*` calls and verify APCu behavior.
- The manifest now requires `cweagans/composer-patches ^1.7.3` and explicitly
  allows the required Composer plugins. The lock file has not yet been
  regenerated, so it still pins version 1.6.7.
- The i-MSCP-specific installer plugin has been vendored as
  `gui/packages/composer-installers` and adapted for Composer Plugin API 2.x.
  The root manifest now resolves it through a local path repository. The
  install-path resolver was adjusted to use Composer's package argument, but
  this fork still needs Composer installation and package-path behavior tests.
- The direct Escaper requirement has been migrated from the abandoned
  `zendframework/zend-escaper` to `laminas/laminas-escaper ^2.11`. Laminas
  Escaper 2.11 introduced PHP 8.2 support; current 2.x releases require PHP
  8.2+. The existing lock file still contains Zend Escaper 2.6.1, so Composer
  must regenerate it before installs are consistent. Search/audit application
  and plugin code for any direct `Zend\\Escaper` references before declaring
  the migration complete. Zend Framework 1.12.20 and its local patches remain
  a separate PHP 8.2 runtime risk.
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
- [x] Updated Composer manifest for PHP 8.2 and Composer-patches 1.7.3.
- [x] Added a local Composer 2 / PHP 8.2-compatible i-MSCP installer package.
- [x] Added CI JSON parsing checks for the root manifest, lock file, and local plugin manifest.
- [x] Removed an unnecessary reliance on the installer constructor's package copy when resolving install paths.
- [x] Replaced the direct Zend Escaper requirement with Laminas Escaper.
- [ ] Regenerated `gui/composer.lock` with Composer; the current lock still
  contains Zend Escaper 2.6.1 and is not yet consistent with the manifest.
- [ ] Composer dependency migration completed.
- [ ] PHP 8.2 static/runtime audit completed.
- [ ] Debian 12 installer and service integration tested.
- [ ] Fresh-install and upgrade tests passed.
