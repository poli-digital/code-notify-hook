#!/usr/bin/env bash
# claude-code-notify — Uninstaller
#
# Removes hook scripts and cleans up settings.json.

set -euo pipefail

HOOKS_DST="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }

echo ""
echo "  claude-code-notify uninstaller"
echo "  ──────────────────────────────"
echo ""

# Remove hook scripts
if [ -f "$HOOKS_DST/notify.sh" ]; then
  rm "$HOOKS_DST/notify.sh"
  ok "Removed $HOOKS_DST/notify.sh"
fi

if [ -f "$HOOKS_DST/focus-session.sh" ]; then
  rm "$HOOKS_DST/focus-session.sh"
  ok "Removed $HOOKS_DST/focus-session.sh"
fi

# Clean up settings.json
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  BACKUP="$SETTINGS.backup.$(date +%s)"
  cp "$SETTINGS" "$BACKUP"
  info "Backup saved to $BACKUP"

  UPDATED=$(jq '
    if .hooks then
      .hooks.Notification //= [] |
      .hooks.Stop //= [] |
      .hooks.Notification = [.hooks.Notification[] | select(.hooks[]?.command | tostring | test("notify\\.sh") | not)] |
      .hooks.Stop = [.hooks.Stop[] | select(.hooks[]?.command | tostring | test("notify\\.sh") | not)] |
      # Remove empty arrays
      (if (.hooks.Notification | length) == 0 then del(.hooks.Notification) else . end) |
      (if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end) |
      (if (.hooks | length) == 0 then del(.hooks) else . end)
    else . end
  ' "$SETTINGS")

  echo "$UPDATED" > "$SETTINGS"
  ok "Cleaned hooks from $SETTINGS"
fi

# Clean up temp files
rm -rf /tmp/claude-code-notify 2>/dev/null || true
ok "Cleaned temporary files."

echo ""
echo -e "${GREEN}  Uninstall complete.${NC}"
echo ""
