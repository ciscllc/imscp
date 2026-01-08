#!/usr/bin/env sh
# Installer helper: copy canonical php.ini to per-version PHP paths
# Usage: install-php-ini.sh [--source PATH] [--versions "7.4,8.2,8.3"] [--target-prefix /etc/php] [--set KEY=VALUE] [--dry-run]

set -eu

SRC="configs/debian/php-common/php.ini"
VERSIONS=""
TARGET_PREFIX="/etc/php"
DRY_RUN=0

REPLACEMENTS=""

usage() {
    cat <<EOF
Usage: $0 [--source PATH] [--versions "7.4,8.2"] [--target-prefix /etc/php] [--set KEY=VALUE] [--dry-run]

Copies the canonical php.ini to common target locations for each PHP version.
If --set KEY=VALUE is provided it will replace placeholders {KEY} in the php.ini.
Default source: configs/debian/php-common/php.ini
Default target prefix: /etc/php
EOF
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            SRC="$2"; shift 2;;
        --versions)
            VERSIONS="$2"; shift 2;;
        --target-prefix)
            TARGET_PREFIX="$2"; shift 2;;
        --set)
            REPLACEMENTS="$REPLACEMENTS $2"; shift 2;;
        --dry-run)
            DRY_RUN=1; shift 1;;
        --help|-h)
            usage;;
        *)
            echo "Unknown arg: $1"; usage;;
    esac
done

if [ -z "$VERSIONS" ]; then
    echo "No versions provided. Use --versions '7.4,8.2' or set PHP_SUPPORTED_VERSIONS in imscp.conf and pass here." >&2
    exit 1
fi

if [ ! -f "$SRC" ]; then
    echo "Source file not found: $SRC" >&2
    exit 1
fi

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t install-php-ini)
trap 'rm -rf "$TMPDIR"' EXIT

for ver in $(echo "$VERSIONS" | tr ',' ' '); do
    for sub in fpm apache2 cli; do
        destdir="$TARGET_PREFIX/$ver/$sub"
        destfile="$destdir/php.ini"

        echo "Preparing $destfile"

        if [ "$DRY_RUN" -ne 1 ]; then
            mkdir -p "$destdir"
        fi

        # Copy and optionally replace tokens
        if [ -n "$REPLACEMENTS" ]; then
            cp "$SRC" "$TMPDIR/php.ini"
            for kv in $REPLACEMENTS; do
                key=$(echo "$kv" | awk -F= '{print $1}')
                val=$(echo "$kv" | awk -F= '{print $2}')
                # Escape forward slashes for sed
                esc=$(printf '%s' "$val" | sed 's/[&/\\]/\\&/g')
                sed -i "s/{${key}}/${esc}/g" "$TMPDIR/php.ini"
            done
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "DRY RUN: would install $TMPDIR/php.ini -> $destfile"
            else
                install -m 0644 -o root -g root "$TMPDIR/php.ini" "$destfile"
            fi
        else
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "DRY RUN: would install $SRC -> $destfile"
            else
                install -m 0644 -o root -g root "$SRC" "$destfile"
            fi
        fi
    done
done

echo "Done."
