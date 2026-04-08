#!/usr/bin/env bash
# claude-code-notify — Installer
#
# Detects the OS, checks dependencies, copies hook scripts to
# ~/.claude/hooks/ and patches ~/.claude/settings.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# ─── Colors ───────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; }

# ─── Detect OS ────────────────────────────────────────────────────────

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

OS=$(detect_os)

echo ""
echo "  claude-code-notify installer"
echo "  ────────────────────────────"
echo ""
info "Detected OS: $OS"
echo ""

# ─── Check dependencies ──────────────────────────────────────────────

MISSING=()

# jq is required on all platforms
if ! command -v jq &>/dev/null; then
  MISSING+=("jq")
fi

case "$OS" in
  macos)
    if ! command -v terminal-notifier &>/dev/null; then
      MISSING+=("terminal-notifier")
    fi
    ;;
  linux)
    if ! command -v notify-send &>/dev/null; then
      MISSING+=("libnotify / notify-send")
    fi
    ;;
  wsl)
    if ! command -v powershell.exe &>/dev/null; then
      MISSING+=("powershell.exe (should be available by default in WSL)")
    fi
    ;;
esac

if [ ${#MISSING[@]} -gt 0 ]; then
  error "Missing dependencies:"
  for dep in "${MISSING[@]}"; do
    echo "       - $dep"
  done
  echo ""

  case "$OS" in
    macos)
      info "Install with:"
      echo "       brew install jq terminal-notifier"
      ;;
    linux)
      info "Install with (Debian/Ubuntu):"
      echo "       sudo apt install jq libnotify-bin"
      info "Or (Fedora):"
      echo "       sudo dnf install jq libnotify"
      info "Or (Arch):"
      echo "       sudo pacman -S jq libnotify"
      ;;
    wsl)
      info "Install jq with:"
      echo "       sudo apt install jq"
      ;;
  esac

  echo ""
  error "Please install the missing dependencies and run this script again."
  exit 1
fi

ok "All dependencies found."

# ─── Optional: focus tools (Linux) ───────────────────────────────────

if [ "$OS" = "linux" ]; then
  HAS_FOCUS_TOOL=false
  for tool in xdotool wmctrl swaymsg hyprctl; do
    if command -v "$tool" &>/dev/null; then
      HAS_FOCUS_TOOL=true
      break
    fi
  done

  if ! $HAS_FOCUS_TOOL; then
    warn "No window-focus tool found (xdotool, wmctrl, swaymsg, hyprctl)."
    warn "Click-to-focus will rely on IDE CLIs only (code, zed, cursor)."
    warn "For full support, install one:"
    echo "       sudo apt install xdotool    # X11"
    echo "       sudo apt install wmctrl     # X11"
    echo "       # swaymsg / hyprctl come with their compositors"
    echo ""
  fi
fi

# ─── Copy hook scripts ───────────────────────────────────────────────

info "Installing hooks to $HOOKS_DST ..."

mkdir -p "$HOOKS_DST"
cp "$HOOKS_SRC/notify.sh" "$HOOKS_DST/notify.sh"
cp "$HOOKS_SRC/focus-session.sh" "$HOOKS_DST/focus-session.sh"
chmod +x "$HOOKS_DST/notify.sh" "$HOOKS_DST/focus-session.sh"

ok "Hook scripts installed."

# ─── Patch settings.json ─────────────────────────────────────────────

HOOK_ENTRY='{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.claude/hooks/notify.sh",
      "timeout": 10,
      "async": true
    }
  ]
}'

info "Configuring Claude Code hooks in $SETTINGS ..."

mkdir -p "$(dirname "$SETTINGS")"

if [ ! -f "$SETTINGS" ]; then
  # Create settings from scratch
  jq -n --argjson hook "$HOOK_ENTRY" '{
    hooks: {
      Notification: [$hook],
      Stop: [$hook]
    }
  }' > "$SETTINGS"
  ok "Created $SETTINGS with notification hooks."
else
  # Merge into existing settings
  BACKUP="$SETTINGS.backup.$(date +%s)"
  cp "$SETTINGS" "$BACKUP"
  info "Backup saved to $BACKUP"

  UPDATED=$(jq --argjson hook "$HOOK_ENTRY" '
    .hooks //= {} |
    .hooks.Notification //= [] |
    .hooks.Stop //= [] |
    # Only add if not already present (check for notify.sh in command)
    (if (.hooks.Notification | map(select(.hooks[]?.command | tostring | test("notify\\.sh"))) | length) == 0
     then .hooks.Notification += [$hook]
     else . end) |
    (if (.hooks.Stop | map(select(.hooks[]?.command | tostring | test("notify\\.sh"))) | length) == 0
     then .hooks.Stop += [$hook]
     else . end)
  ' "$SETTINGS")

  echo "$UPDATED" > "$SETTINGS"
  ok "Updated $SETTINGS with notification hooks."
fi

# ─── Done ─────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  Installation complete!${NC}"
echo ""
echo "  Hooks installed:"
echo "    - Notification  → push notification when Claude needs input"
echo "    - Stop          → push notification when Claude finishes"
echo ""
echo "  Restart Claude Code to activate."
echo ""

# ─── Verify ──────────────────────────────────────────────────────────

info "Running quick verification..."

TEST_RESULT=$(echo '{"hook_event_name":"Stop","cwd":"/tmp/test","session_id":"install-test"}' \
  | "$HOOKS_DST/notify.sh" 2>&1 && echo "PASS" || echo "FAIL")

if echo "$TEST_RESULT" | grep -q "PASS"; then
  ok "Verification passed — notification sent!"
  rm -f /tmp/claude-code-notify/install-test
else
  warn "Verification returned unexpected output. Check the logs above."
fi
