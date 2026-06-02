#!/usr/bin/env bash
#
# sync-hosts.sh — add a local .local domain for every folder in www/.
#
# For each folder inside www/ it builds "<folder><DOMAIN_SUFFIX>" and makes sure
# the system hosts file points it at 127.0.0.1. It also adds PHPMYADMIN_DOMAIN
# and MAILPIT_DOMAIN. Existing entries are left untouched (no duplicates).
#
# Works on Linux/macOS, and on Windows when run from Git Bash as Administrator.
#
# Usage:
#   ./scripts/sync-hosts.sh
#   bash scripts/sync-hosts.sh
#
set -euo pipefail

# --- Locate the project root --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WWW_DIR="$ROOT_DIR/www"

# --- Auto-elevate so the user never has to open an admin shell manually -------
OS_NAME="$(uname -s 2>/dev/null || echo unknown)"
case "$OS_NAME" in
    MINGW*|MSYS*|CYGWIN*)
        # On Windows, hand off to the self-elevating PowerShell version, which
        # triggers a UAC prompt automatically and then writes the hosts file.
        PS1_WIN="$(cygpath -w "$SCRIPT_DIR/sync-hosts.ps1" 2>/dev/null || echo "$SCRIPT_DIR/sync-hosts.ps1")"
        echo "Windows detected — launching self-elevating sync (accept the UAC prompt)..."
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN"
        exit $?
        ;;
    *)
        # On Linux/macOS, re-run with sudo if the hosts file isn't writable.
        if [ ! -w /etc/hosts ] && [ "$(id -u)" -ne 0 ]; then
            echo "Root required to write /etc/hosts — re-running with sudo..."
            exec sudo -- "$0" "$@"
        fi
        ;;
esac

# --- Load environment values (.env, falling back to .env.example) ------------
ENV_FILE="$ROOT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    ENV_FILE="$ROOT_DIR/.env.example"
fi

get_env() {
    # get_env KEY DEFAULT  -> prints value from $ENV_FILE or the default
    local key="$1" default="${2:-}"
    local val
    val="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null | tail -n1 \
        | cut -d'=' -f2- | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
    if [ -z "$val" ]; then echo "$default"; else echo "$val"; fi
}

DOMAIN_SUFFIX="$(get_env DOMAIN_SUFFIX .local)"
PHPMYADMIN_DOMAIN="$(get_env PHPMYADMIN_DOMAIN pma.local)"
MAILPIT_DOMAIN="$(get_env MAILPIT_DOMAIN mail.local)"

# --- Detect the hosts file path ----------------------------------------------
case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) HOSTS="/c/Windows/System32/drivers/etc/hosts" ;;
    *)                    HOSTS="/etc/hosts" ;;
esac

echo "Project root : $ROOT_DIR"
echo "Env file     : $ENV_FILE"
echo "Hosts file   : $HOSTS"
echo "Domain suffix: $DOMAIN_SUFFIX"
echo

# --- Collect domains ----------------------------------------------------------
declare -a DOMAINS=()

echo "Found projects in www/:"
if [ -d "$WWW_DIR" ]; then
    for dir in "$WWW_DIR"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        DOMAINS+=("${name}${DOMAIN_SUFFIX}")
        echo "  - $name => ${name}${DOMAIN_SUFFIX}"
    done
else
    echo "  (www/ not found)"
fi

# Service domains.
DOMAINS+=("$PHPMYADMIN_DOMAIN" "$MAILPIT_DOMAIN")
echo "  - phpMyAdmin => $PHPMYADMIN_DOMAIN"
echo "  - Mailpit    => $MAILPIT_DOMAIN"
echo

# --- Apply entries ------------------------------------------------------------
PERM_ERROR=0

entry_exists() {
    local domain="$1"
    # Match domain as a whole token on a non-comment line.
    grep -qiE "^[[:space:]]*[^#].*[[:space:]]${domain//./\\.}([[:space:]]|\$)" "$HOSTS" 2>/dev/null
}

add_entry() {
    local domain="$1"
    if entry_exists "$domain"; then
        echo "  exists : $domain"
        return
    fi
    if printf '127.0.0.1\t%s\n' "$domain" >> "$HOSTS" 2>/dev/null; then
        echo "  added  : $domain"
    else
        echo "  ERROR  : cannot write '$domain' — run as Administrator (Git Bash) or root/sudo"
        PERM_ERROR=1
    fi
}

# Ensure the hosts file ends with a newline, otherwise an append would be
# glued onto the last existing entry (some editors leave no trailing newline).
if [ -s "$HOSTS" ] && [ -n "$(tail -c1 "$HOSTS" 2>/dev/null)" ]; then
    printf '\n' >> "$HOSTS" 2>/dev/null || true
fi

echo "Syncing hosts entries:"
for domain in "${DOMAINS[@]}"; do
    [ -n "$domain" ] && add_entry "$domain"
done
echo

if [ "$PERM_ERROR" -ne 0 ]; then
    echo "Some entries could not be written due to permissions."
    echo "  - Windows: open Git Bash 'Run as administrator', then re-run this script."
    echo "  - Linux/macOS: run with sudo, e.g.  sudo ./scripts/sync-hosts.sh"
    exit 1
fi

echo "Hosts file is up to date."
echo "Tip: on Windows you may need 'ipconfig //flushdns' to refresh DNS."
