#!/usr/bin/env bash
# claude-code-notify — Installer
#
# Detects the OS, checks dependencies, ensures hook scripts are
# executable and patches ~/.claude/settings.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
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

# ─── Ensure hook scripts are executable ─────────────────────────────

chmod +x "$HOOKS_DIR/notify.sh" "$HOOKS_DIR/focus-session.sh"

ok "Hook scripts ready at $HOOKS_DIR"

# ─── Patch settings.json ─────────────────────────────────────────────

HOOK_ENTRY="$(cat <<EOF
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "$HOOKS_DIR/notify.sh",
      "timeout": 10,
      "async": true
    }
  ]
}
EOF
)"

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

# ─── Welcome notification ────────────────────────────────────────────

info "Sending welcome notification..."

WELCOME_TITLE="Setup Complete"
WELCOME_MSG="Notifications are working! You'll be notified when Claude needs attention."

case "$OS" in
  macos)
    if command -v terminal-notifier &>/dev/null; then
      terminal-notifier \
        -title "Claude Code" \
        -subtitle "$WELCOME_TITLE" \
        -message "$WELCOME_MSG" \
        -sound default \
        -group "claude-code-welcome" \
        -ignoreDnD \
        > /dev/null 2>&1
    fi
    # Always show alert dialog (bypasses Focus/DnD)
    osascript -e "display alert \"Claude Code — $WELCOME_TITLE\" message \"$WELCOME_MSG\" giving up after 8" > /dev/null 2>&1
    ;;
  linux)
    if command -v notify-send &>/dev/null; then
      notify-send "Claude Code — $WELCOME_TITLE" "$WELCOME_MSG" \
        --app-name="Claude Code" \
        --icon=terminal 2>/dev/null
    fi
    ;;
  wsl)
    PS_TITLE="Claude Code - $WELCOME_TITLE"
    powershell.exe -NoProfile -NonInteractive -Command "
      try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime];
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime];
        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
        \$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>$PS_TITLE</text><text>$WELCOME_MSG</text></binding></visual></toast>');
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new(\$xml));
      } catch {
        Add-Type -AssemblyName System.Windows.Forms;
        \$n = New-Object System.Windows.Forms.NotifyIcon;
        \$n.Icon = [System.Drawing.SystemIcons]::Information;
        \$n.BalloonTipTitle = '$PS_TITLE';
        \$n.BalloonTipText = '$WELCOME_MSG';
        \$n.Visible = \$true;
        \$n.ShowBalloonTip(5000);
        Start-Sleep -Milliseconds 5500;
        \$n.Dispose();
      }
    " > /dev/null 2>&1
    ;;
esac

echo ""
echo "  Did you see the notification?"
echo ""

read -r -p "  [Y] Yes, it worked  [n] No, I didn't see it: " SAW_NOTIF
SAW_NOTIF="${SAW_NOTIF:-Y}"

if [[ "$SAW_NOTIF" =~ ^[Yy]$ ]]; then
  ok "You're all set!"
else
  warn "The notification may be going to the Notification Center only."

  if [ "$OS" = "macos" ]; then
    echo ""
    echo "  To fix this on macOS:"
    echo ""
    echo "    1. Open System Settings → Notifications → terminal-notifier"
    echo "    2. Set notification style to \"Alerts\" (stays on screen)"
    echo "       or \"Banners\" (auto-dismisses after a few seconds)"
    echo "    3. Make sure \"Allow Notifications\" is ON"
    echo ""

    read -r -p "  Open Notification Settings now? [Y/n] " OPEN_SETTINGS
    OPEN_SETTINGS="${OPEN_SETTINGS:-Y}"
    if [[ "$OPEN_SETTINGS" =~ ^[Yy]$ ]]; then
      open "x-apple.systempreferences:com.apple.Notifications-Settings"
      info "Settings opened — look for \"terminal-notifier\" in the list."
    fi
  elif [ "$OS" = "linux" ]; then
    echo ""
    echo "  Check that your desktop environment's notification daemon is running."
    echo "  Common daemons: dunst, mako, swaync, notify-osd."
  fi
fi

rm -f /tmp/claude-code-notify/install-test 2>/dev/null
