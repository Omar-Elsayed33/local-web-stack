#!/usr/bin/env bash
#
# restart.sh — sync hosts, restart the stack, and print the local URLs.
#
# Usage:
#   ./scripts/restart.sh
#   bash scripts/restart.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WWW_DIR="$ROOT_DIR/www"

# 1) Make sure every project + service has a hosts entry.
bash "$SCRIPT_DIR/sync-hosts.sh" || true
echo

# 2) Restart the Docker services (no rebuild — file changes are already live
#    via the ./www volume mount; only config benefits from a restart).
echo "Restarting Docker Compose services..."
( cd "$ROOT_DIR" && docker compose restart )
echo

# --- Load env values to print the right domains ------------------------------
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$ROOT_DIR/.env.example"

get_env() {
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

echo "Your local URLs:"
echo
echo "  Projects:"
if [ -d "$WWW_DIR" ]; then
    for dir in "$WWW_DIR"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        echo "    http://${name}${DOMAIN_SUFFIX}"
    done
fi
echo
echo "  phpMyAdmin : http://${PHPMYADMIN_DOMAIN}"
echo "  Mailpit    : http://${MAILPIT_DOMAIN}"
echo
echo "Done."
