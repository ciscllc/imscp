# Debian 12 package and service compatibility audit

This is a source-level audit of the installer package catalog and Debian service
configuration. It is not a successful APT resolution or installation test.
Package availability can vary by architecture and repository configuration.

## Confirmed installer blocker

The Debian adapter constructs the package-catalog path as:

```
autoinstaller/Packages/<DISTRO_ID>-<DISTRO_CODENAME>.xml
```

For Debian 12 this resolves to `autoinstaller/Packages/debian-bookworm.xml`.
A Bookworm-specific catalog has now been added on this port branch. This removes
the missing-file blocker, but does not prove that every package resolves or that
the resulting service configurations work. A clean Bookworm APT/install test is
still required.

## Package catalog findings

| Area | Existing Buster catalog | Debian 12 assessment |
| --- | --- | --- |
| PHP | Lists PHP 5.6, 7.0–7.4 and 8.0; adds Sury repository for `buster` | Bookworm catalog now selects PHP 8.2 from Debian packages and does not add the Buster/Sury repository. Resolve the full package set with APT. |
| PHP extensions | Includes legacy package names such as `php8.0-json`; older branches list `mcrypt` | Build the PHP 8.2 list against Bookworm package metadata. JSON is part of the PHP 8.2 runtime packaging; mcrypt is not a standard PHP 8.2 extension package. |
| MariaDB | Pins `mariadb-server-10.3`, `mariadb-client-10.3` and `libmariadb3` | Bookworm catalog uses `mariadb-server`, `mariadb-client`, and the `mariadb_10.11` alternative, matching Debian 12's MariaDB series. Test upgrades from the older 10.3 setup. |
| Apache | Uses `apache2`, `apache2-dev`, `apache2-suexec-pristine`, `libapache2-mod-fcgid`, and `libapache2-mpm-itk` | Several core package names are present in Bookworm, but each alternative still needs dependency resolution and module/MPM tests. In particular, verify the ITK package and Apache module activation. |
| Mail | Offers Courier or Dovecot for mailbox services; uses Postfix for MTA | The package names must be resolved against Bookworm. Then validate Postfix/Dovecot or Courier integration, SASL sockets, authentication, TLS and mailbox delivery. |
| DNS | Uses `bind9` and `resolvconf` | Verify package availability, systemd unit names, resolver ownership and the generated BIND configuration on Bookworm. |
| FTP | Offers `proftpd-basic` or `vsftpd`; ProFTPD uses MySQL module package | Resolve the selected FTP stack and SQL module packages on Bookworm; test PAM/authentication and passive ports. |
| Base tools | Includes `ntp` and a range of legacy build/runtime utilities | Catalog retains `ntp`; in Bookworm this is a transitional package depending on `ntpsec`. Other utility package names and their necessity still need APT and source-reference validation. |

Spot checks against Debian's Bookworm package index confirm the PHP 8.2
runtime and APCu packages, MariaDB 10.11 server/client packages, Apache core
packages and ITK MPM, Courier IMAP, ProFTPD's MySQL module, vsftpd, the MySQL
PAM module, `resolvconf`, and the `ntp` transitional package. These checks
establish package-name availability only; they are not a full dependency
resolution of the catalog and do not validate service configuration.

References: <https://packages.debian.org/bookworm/php8.2>,
<https://packages.debian.org/bookworm/php8.2-apcu>,
<https://packages.debian.org/bookworm/mariadb-server>,
<https://packages.debian.org/bookworm/httpd/>,
<https://packages.debian.org/bookworm/libapache2-mpm-itk>,
<https://packages.debian.org/bookworm/courier-imap>,
<https://packages.debian.org/bookworm/proftpd-mod-mysql>,
<https://packages.debian.org/bookworm/vsftpd>,
<https://packages.debian.org/bookworm/libpam-mysql>,
<https://packages.debian.org/bookworm/resolvconf>, and
<https://packages.debian.org/bookworm/ntp/>.

## Configuration and service checks still required

- Check the exact systemd unit names and start/reload/restart behavior for
  Apache, Postfix, Dovecot/Courier, BIND, MariaDB, FTP, PHP-FPM and i-MSCP
  daemons.
- Validate config syntax with `apache2ctl configtest`, `postfix check`,
  `doveconf -n` (or Courier's applicable validators), `named-checkconf`,
  SQL smoke tests, and `php-fpm8.2 -t` where applicable.
- Confirm module names and enablement for Apache (event/ITK, fcgid, suexec,
  rewrite, SSL, headers, proxy/FastCGI), plus PHP-FPM socket paths and pool
  permissions.
- Verify TLS defaults, OpenSSL 3 compatibility, mail authentication sockets,
  DNSSEC configuration, resolver integration, FTP PAM/SQL auth, cron jobs,
  logrotate rules, and systemd service overrides.
- Test package resolution with a clean Debian 12 VM and the exact repository
  configuration intended for supported installations. A package's presence in
  the index alone does not prove that i-MSCP's generated configuration works.

## Current status

- [x] Identified the package-catalog path selected by the Debian adapter.
- [x] Confirmed the Bookworm catalog is missing from the branch.
- [x] Identified stale PHP/Sury and MariaDB 10.3 entries in the Buster catalog.
- [x] Add a Bookworm-specific package catalog with PHP 8.2 and MariaDB 10.11 package names.
- [ ] Validate every selected package with Bookworm APT metadata for supported architectures.
- [ ] Test service configuration and lifecycle on a clean Debian 12 VM.
