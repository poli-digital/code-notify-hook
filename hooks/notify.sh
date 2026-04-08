#!/usr/bin/env bash
# claude-code-notify — Push Notification Hook
#
# Sends a native OS notification when Claude Code needs attention
# or finishes a task. Supports macOS, Linux and Windows (WSL).
#
# The notification click handler delegates to focus-session.sh
# which brings the exact IDE window / terminal tab to the foreground.

set -euo pipefail

# ─── Load configuration ────────────────────────────────────────────

NOTIFY_ALERT=true
NOTIFY_ALERT_TIMEOUT=8
NOTIFY_SOUND="default"
NOTIFY_DND_BYPASS=true

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude-code-notify/config"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

# ─── Parse hook input (JSON on stdin) ────────────────────────────────

INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# ─── Notification content ────────────────────────────────────────────

TITLE=""
MESSAGE=""

case "$HOOK_EVENT" in
  Notification)
    case "$NOTIFICATION_TYPE" in
      permission_prompt)
        TITLE="Approval Required"
        MESSAGE="Claude needs your permission to continue."
        ;;
      idle_prompt)
        TITLE="Waiting for Input"
        MESSAGE="Claude is waiting for your response."
        ;;
      *)
        TITLE="Attention"
        MESSAGE="Claude needs your attention."
        ;;
    esac
    ;;
  Stop)
    TITLE="Task Complete"
    MESSAGE="Claude finished processing."
    ;;
  *)
    exit 0
    ;;
esac

if [ -n "$CWD" ]; then
  MESSAGE="$MESSAGE [$(basename "$CWD")]"
fi

# ─── Detect OS ───────────────────────────────────────────────────────

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

# ─── Detect host application ─────────────────────────────────────────

detect_app() {
  # Primary: TERM_PROGRAM env var (set by most terminal emulators / IDEs)
  case "${TERM_PROGRAM:-}" in
    vscode)          echo "vscode"; return ;;
    cursor)          echo "cursor"; return ;;
    zed)             echo "zed"; return ;;
    iTerm.app)       echo "iterm"; return ;;
    Apple_Terminal)  echo "apple-terminal"; return ;;
    WarpTerminal)    echo "warp"; return ;;
    kitty)           echo "kitty"; return ;;
    alacritty)       echo "alacritty"; return ;;
    ghostty)         echo "ghostty"; return ;;
    tmux)            echo "tmux"; return ;;
    rio)             echo "rio"; return ;;
  esac

  # Fallback: walk the process tree looking for a known parent
  local _pid="${PPID:-1}"
  while [ "$_pid" -gt 1 ] 2>/dev/null; do
    local _comm
    _comm=$(ps -p "$_pid" -o comm= 2>/dev/null || true)
    case "$_comm" in
      *"Code Helper"*|*code*|*Electron*)  echo "vscode"; return ;;
      *Cursor*)                           echo "cursor"; return ;;
      *zed*|*Zed*)                        echo "zed"; return ;;
      *iTerm*)                            echo "iterm"; return ;;
      *Terminal*)                         echo "apple-terminal"; return ;;
      *Warp*|*WarpTerminal*)              echo "warp"; return ;;
      *kitty*)                            echo "kitty"; return ;;
      *ghostty*)                          echo "ghostty"; return ;;
      *alacritty*)                        echo "alacritty"; return ;;
      *rio*)                              echo "rio"; return ;;
      *gnome-terminal*|*mate-terminal*)   echo "gnome-terminal"; return ;;
      *konsole*)                          echo "konsole"; return ;;
      *xfce4-terminal*)                   echo "xfce4-terminal"; return ;;
      *tilix*)                            echo "tilix"; return ;;
    esac
    _pid=$(ps -p "$_pid" -o ppid= 2>/dev/null | tr -d ' ')
  done

  echo "unknown"
}

OS=$(detect_os)
APP=$(detect_app)

# ─── Save session context for the click handler ──────────────────────

CONTEXT_DIR="/tmp/claude-code-notify"
mkdir -p "$CONTEXT_DIR"
cat > "$CONTEXT_DIR/$SESSION_ID" <<EOF
APP=$APP
CWD=$CWD
OS=$OS
EOF

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
FOCUS_SCRIPT="$HOOKS_DIR/focus-session.sh"

# ─── Send notification (per OS) ──────────────────────────────────────

case "$OS" in

  macos)
    # terminal-notifier: adds to Notification Center + enables click-to-focus.
    # May be silenced by Focus/DnD — kept for history and when Focus is off.
    if command -v terminal-notifier &>/dev/null; then
      TN_ARGS=(
        -title "Claude Code"
        -subtitle "$TITLE"
        -message "$MESSAGE"
        -execute "'$FOCUS_SCRIPT' '$SESSION_ID'"
        -group "claude-code-${SESSION_ID:-default}"
      )
      [ -n "$NOTIFY_SOUND" ]             && TN_ARGS+=(-sound "$NOTIFY_SOUND")
      [ "$NOTIFY_DND_BYPASS" = "true" ]  && TN_ARGS+=(-ignoreDnD)

      terminal-notifier "${TN_ARGS[@]}" > /dev/null 2>&1 &
    fi

    # Focus/DnD bypass: `display alert` creates a real window (not a
    # notification), so it always appears on screen regardless of any
    # Focus mode. Auto-dismisses after NOTIFY_ALERT_TIMEOUT seconds.
    # Disable via NOTIFY_ALERT=false in the config file.
    if [ "$NOTIFY_ALERT" = "true" ]; then
      osascript -e "display alert \"Claude Code — $TITLE\" message \"$MESSAGE\" giving up after $NOTIFY_ALERT_TIMEOUT" > /dev/null 2>&1 &
    fi
    ;;

  linux)
    if command -v notify-send &>/dev/null; then
      # Check if notify-send supports --action (libnotify >= 0.7.9)
      if notify-send --help 2>&1 | grep -q -- '--action'; then
        (
          ACTION=$(notify-send "Claude Code — $TITLE" "$MESSAGE" \
            --app-name="Claude Code" \
            --icon=terminal \
            --action="focus=Open Session" 2>/dev/null || true)
          if [ "$ACTION" = "focus" ]; then
            "$FOCUS_SCRIPT" "$SESSION_ID"
          fi
        ) &
      else
        notify-send "Claude Code — $TITLE" "$MESSAGE" \
          --app-name="Claude Code" \
          --icon=terminal &
      fi
    fi
    ;;

  wsl)
    # Windows toast notification via PowerShell
    # Escape single quotes for PowerShell
    PS_TITLE="Claude Code - $TITLE"
    PS_MESSAGE="$MESSAGE"

    powershell.exe -NoProfile -NonInteractive -Command "
      try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime];
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime];
        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
        \$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>$PS_TITLE</text><text>$PS_MESSAGE</text></binding></visual></toast>');
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new(\$xml));
      } catch {
        # Fallback: balloon tip
        Add-Type -AssemblyName System.Windows.Forms;
        \$n = New-Object System.Windows.Forms.NotifyIcon;
        \$n.Icon = [System.Drawing.SystemIcons]::Information;
        \$n.BalloonTipTitle = '$PS_TITLE';
        \$n.BalloonTipText = '$PS_MESSAGE';
        \$n.Visible = \$true;
        \$n.ShowBalloonTip(5000);
        Start-Sleep -Milliseconds 5500;
        \$n.Dispose();
      }
    " > /dev/null 2>&1 &
    ;;

esac

exit 0
