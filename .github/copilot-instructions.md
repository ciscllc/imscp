Short, actionable instructions to help AI code agents be productive in this repo.

- Repository overview:
  - i-MSCP is a mixed-language control panel: Perl (engine/autoinstaller), PHP (GUI), C (daemon), and shell/Makefiles.
  - Major components:
    - `engine/` — Perl runtime, common libs, services, and installers. Key files: `engine/imscp_common_code.pl`, `engine/install.xml`, `engine/setup/*`.
    - `autoinstaller/` — Perl autoinstaller code and adapters (`autoinstaller/Functions.pm`, `autoinstaller/Adapter/`).
    - `gui/` — PHP web UI and vendor libraries (Zend, phpseclib). Key files: `gui/library/`, `gui/public/index.php`.
    - `daemon/` — small C-based server communicating with Perl backend (`daemon/imscp_daemon.c`, `daemon/Makefile`).
    - `configs/` and `docs/` — distribution-specific config templates and installation instructions.

- Big-picture architecture & data flows:
  - The C `imscp_daemon` listens on a TCP socket and forks workers that call into a backend script (`backendscriptpath`) to handle protocol commands.
  - The Perl `engine/` contains the runtime and management scripts used by the GUI and background services; it loads `imscp.conf` for runtime config.
  - The `autoinstaller` builds a distribution tree and installs files into locations defined by `engine/install.xml` and `configs/*` templates.
  - The PHP `gui/` layer uses `gui/library/iMSCP/*` libraries to talk to the engine (usually via the database and filesystem), and relies on `imscp.conf` values.

- Developer workflows (how to build, run, debug):
  - Building the C daemon: run `make` in `daemon/` (uses `daemon/Makefile` to produce `imscp_daemon`).
  - Running the autoinstaller (local testing): run `perl imscp-autoinstall` from repo root. This script calls `autoinstaller::Functions::build()` then `install()` when appropriate.
  - Packaging/build steps: `engine/install.xml` controls which engine files are copied during build (`INST_PREF`/`SYSTEM_ENGINE_ROOT`). Follow `autoinstaller/` logic for build/install flow.
  - GUI testing: place `gui/` output under `ROOT_DIR` (see `imscp-autoinstall` `build` notes). Many web pages are plain PHP; use a local LAMP stack and the `imscp.conf` sample in `configs/`.

- Project-specific conventions and patterns:
  - Mixed runtimes share a central `imscp.conf` file (lookups happen in `engine/imscp_common_code.pl` and `autoinstaller/Functions.pm`). Changes to config keys must be compatible across Perl and PHP layers.
  - Perl modules use `iMSCP::` namespaces and rely on `iMSCP::EventManager` events for extension points (see `autoinstaller/Functions.pm` event triggers like `beforeBuild`, `afterInstall`).
  - Installer adapters for distributions live under `autoinstaller/Adapter/` (e.g., `DebianAdapter.pm`). Adapter methods like `preBuild`, `postBuild`, and `installPreRequiredPackages` are called by the autoinstaller.
  - Minimal use of external CPAN/PHP vendor libs — many vendored dependencies live in `gui/library/vendor/` or `engine/PerlVendor`.

- Integration points & external dependencies:
  - System services: Apache/nginx, MySQL/MariaDB, Postfix, Dovecot, Bind, ProFTPD — the installer config determines which to enable (`configs/*/*`).
  - Database: MySQL via DBI/DBD::mysql in Perl and `gui/library/iMSCP/Database.php` in PHP. `engine/imscp_common_code.pl` initializes DB vars from `imscp-db-keys`.
  - The daemon speaks a simple protocol over TCP; the backend script path is passed via `-b` to the daemon and is required.

- Useful code pointers & examples (quote lines where helpful):
  - Installer entry: `imscp-autoinstall` — builds then installs; key flow: `autoinstaller/Functions.pm -> build() -> install()`.
  - Config loader: `autoinstaller/Functions.pm::loadConfig()` reads templates in `configs/<distro>/imscp.conf` and merges with existing `/etc/imscp/imscp.conf`.
  - Daemon entry: `daemon/imscp_daemon.c` — fork-per-connection model; it expects a backend script path (`-b`) and uses `takeConnection(connfd)` to handle requests.
  - PHP library entry: `gui/library/iMSCP/Database.php` and `gui/library/imscp-lib.php` — useful when adding UI features that interact with the DB.

- Editing guidance for AI agents:
  - When changing config keys, update all loaders: `engine/imscp_common_code.pl`, `autoinstaller/Functions.pm`, and any `gui/library/*` usage.
  - Preserve event triggers; prefer adding listeners under `contrib/Listeners/` or `engine/PerlLib` rather than modifying core event calls.
  - For cross-language changes (PHP ↔ Perl ↔ daemon), add tests or manual run steps (start `imscp_daemon`, run Perl scripts, load PHP pages) — don't assume runtime wiring.

- Quick checklist for common tasks:
  - Add a new engine Perl module: put under `engine/PerlLib` or `autoinstaller/Adapter` and register any events with `iMSCP::EventManager`.
  - Add a GUI page: update `gui/public/` and use `gui/library/imscp-lib.php` patterns for session/auth and `iMSCP/Database.php` for DB access.
  - Change installation layout: update `engine/install.xml` and the autoinstaller adapter methods in `autoinstaller/Adapter/*`.

- Where to look first when debugging:
  - Logs: paths built from `imscp.conf` (`LOG_DIR`, `ROOT_DIR`); `newDebug()` calls in Perl write to `imscp-autoinstall.log` and `imscp-build.log`.
  - Daemon: run `daemon/imscp_daemon -b path/to/backend_script -p /tmp/imscp.pid` and watch syslog or daemon stdout.

If any section is unclear or you'd like me to add short runnable examples (daemon run, local PHP setup, or a sample adapter), tell me which and I'll iterate.
