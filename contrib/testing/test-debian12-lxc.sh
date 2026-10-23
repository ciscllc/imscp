#!/usr/bin/env bash
# Download and optionally run the i-MSCP Debian 12 / PHP 8.2 test branch.
# Intended for a disposable Debian 12 LXC container.
set -Eeuo pipefail
umask 022

REPO="ciscllc/imscp"
BRANCH="port/debian12-php82"
ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
RUN_INSTALLER=0
INSTALL_PREREQS=1
BASE_DIR="/usr/local/src"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="${BASE_DIR}/imscp-bookworm-test-${STAMP}"
LOG_DIR="/var/log/imscp-bookworm-test"
LOG_FILE="${LOG_DIR}/test-${STAMP}.log"

usage() {
    cat <<'USAGE'
Usage: sudo bash test-debian12-lxc.sh [options]

Downloads the port branch, checks the Debian/LXC environment and validates
the package catalog. The actual i-MSCP installer is NOT run unless requested.

Options:
  --run-installer     Run 'perl imscp-autoinstall -d' after checks.
                      This can install/configure services and change the OS.
  --no-install-deps   Do not install curl/ca-certificates/tar/perl/whiptail.
  --help              Show this help.

Examples:
  sudo bash test-debian12-lxc.sh
  sudo bash test-debian12-lxc.sh --run-installer
USAGE
}

while (($#)); do
    case "$1" in
        --run-installer) RUN_INSTALLER=1 ;;
        --no-install-deps) INSTALL_PREREQS=0 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run as root, e.g. sudo bash $0" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
    local rc=$?
    echo
    echo "ERROR: command failed (exit $rc, line ${BASH_LINENO[0]})."
    echo "Log: $LOG_FILE"
    exit "$rc"
}
trap on_error ERR

echo "=== i-MSCP Debian 12 / PHP 8.2 LXC test ==="
echo "Started: $(date --iso-8601=seconds)"
echo "Branch:  $BRANCH"
echo "Log:     $LOG_FILE"
echo

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: /etc/os-release is missing."
    exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
echo "OS:      ${PRETTY_NAME:-unknown}"
echo "ID:      ${ID:-unknown}"
echo "VERSION: ${VERSION_ID:-unknown}"
echo "Arch:    $(dpkg --print-architecture 2>/dev/null || uname -m)"

if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "12" ]]; then
    echo "ERROR: This script is intended specifically for Debian 12."
    exit 1
fi

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT="$(systemd-detect-virt --container 2>/dev/null || true)"
    echo "Container: ${VIRT:-not detected by systemd-detect-virt}"
    if [[ "$VIRT" != "lxc" && "$VIRT" != "lxc-libvirt" ]]; then
        echo "WARNING: LXC was not positively detected. Continuing with environment checks."
    fi
else
    echo "WARNING: systemd-detect-virt is unavailable; cannot confirm LXC."
fi

if [[ ! -d /run/systemd/system ]]; then
    echo "WARNING: systemd does not appear to be running as PID 1."
    echo "The installer/service tests are likely to fail in this container."
fi

echo
echo "=== Container readiness ==="
echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
echo "Disk:"
df -h "$BASE_DIR" 2>/dev/null || df -h /
echo "Memory:"
free -h 2>/dev/null || true
echo "Resolver:"
cat /etc/resolv.conf 2>/dev/null || true
echo
echo "NOTE: Use a disposable container with working DNS/network access,"
echo "systemd as PID 1, a unique hostname and sufficient disk/RAM."
echo "The script does not change LXC host configuration."

if [[ $INSTALL_PREREQS -eq 1 ]]; then
    echo
    echo "=== Installing download/installer prerequisites ==="
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates curl tar perl whiptail
else
    for cmd in curl tar perl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: Required command '$cmd' is missing (--no-install-deps was set)."
            exit 1
        fi
    done
fi

echo
echo "=== Downloading branch archive ==="
mkdir -p "$BASE_DIR"
mkdir "$WORK_DIR"
ARCHIVE="${WORK_DIR}/branch.tar.gz"
curl --fail --location --retry 3 --retry-delay 2 "$ARCHIVE_URL" -o "$ARCHIVE"
tar -tzf "$ARCHIVE" >/dev/null
tar -xzf "$ARCHIVE" --strip-components=1 -C "$WORK_DIR"
rm -f "$ARCHIVE"

if [[ ! -f "${WORK_DIR}/imscp-autoinstall" ]]; then
    echo "ERROR: Archive downloaded, but imscp-autoinstall was not found."
    echo "Extracted path: $WORK_DIR"
    exit 1
fi

CATALOG="${WORK_DIR}/autoinstaller/Packages/debian-bookworm.xml"
if [[ ! -f "$CATALOG" ]]; then
    echo "ERROR: Required package catalog is missing: $CATALOG"
    exit 1
fi

echo
echo "=== Static package catalog checks ==="
grep -q '<php8\.2' "$CATALOG"
grep -q '<mariadb_10\.11' "$CATALOG"
if grep -Eq 'packages\.sury\.org|<php(5\.6|7\.[0-4]|8\.0)([[:space:]>])|php8\.2-json|mariadb-server-10\.3|mariadb-client-10\.3' "$CATALOG"; then
    echo "ERROR: A known stale package/repository entry was found."
    exit 1
fi
echo "PASS: Bookworm catalog exists and contains PHP 8.2 / MariaDB 10.11 entries."
echo "PASS: No known Buster Sury, old PHP-version or MariaDB 10.3 entries detected."

echo
echo "=== Package availability spot check (APT metadata) ==="
apt-cache policy php8.2-cli php8.2-fpm php8.2-mysql mariadb-server mariadb-client apache2 postfix bind9
echo
echo "NOTE: apt-cache policy is only a spot check; it is not a full dependency simulation."

echo
echo "=== Download/extraction result ==="
echo "Source directory: $WORK_DIR"
echo "Installer:        $WORK_DIR/imscp-autoinstall"
echo "Catalog:          $CATALOG"
echo "Log:              $LOG_FILE"

if [[ $RUN_INSTALLER -eq 1 ]]; then
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "The real i-MSCP installer will now run interactively."
    echo "It may install packages, overwrite service configuration and"
    echo "change firewall, mail, DNS, web and database settings."
    echo "Continue only inside a disposable test container."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -r -p "Type RUN-I-MSCP-INSTALLER to continue: " CONFIRM
    if [[ "$CONFIRM" != "RUN-I-MSCP-INSTALLER" ]]; then
        echo "Installer not started; download and checks are complete."
        exit 0
    fi
    cd "$WORK_DIR"
    echo "Running: perl imscp-autoinstall -d"
    perl imscp-autoinstall -d
    echo
    echo "Installer process finished with exit code 0."
else
    echo
    echo "Installer has NOT been run."
    echo "To attempt installation, rerun with --run-installer."
fi

echo
echo "Finished: $(date --iso-8601=seconds)"
echo "Log saved to: $LOG_FILE"
