#!/usr/bin/env bash
# claude-code-notify — Focus Session Handler
#
# Called when the user clicks a notification. Reads session context
# (app type + working directory + OS) and focuses the exact IDE
# window or terminal tab where the Claude Code session is running.

set -euo pipefail

SESSION_ID="${1:-}"
CONTEXT_FILE="/tmp/claude-code-notify/$SESSION_ID"

if [ -z "$SESSION_ID" ] || [ ! -f "$CONTEXT_FILE" ]; then
  exit 0
fi

# shellcheck source=/dev/null
source "$CONTEXT_FILE"

APP="${APP:-unknown}"
CWD="${CWD:-$HOME}"
OS="${OS:-unknown}"

PROJECT=$(basename "$CWD")

# ─── Helpers ──────────────────────────────────────────────────────────

# Try to focus using an IDE CLI command (works on all platforms).
# Usage: focus_with_cli <command> <directory>
focus_with_cli() {
  local cmd="$1" dir="$2"
  if command -v "$cmd" &>/dev/null; then
    "$cmd" "$dir" &>/dev/null &
    return 0
  fi
  return 1
}

# ─── macOS Focus ──────────────────────────────────────────────────────

focus_macos_iterm() {
  osascript <<EOF
tell application "iTerm"
  activate
  set found to false
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if name of s contains "$PROJECT" then
          select t
          set found to true
          exit repeat
        end if
      end repeat
      if found then exit repeat
    end repeat
    if found then
      set index of w to 1
      exit repeat
    end if
  end repeat
end tell
EOF
}

focus_macos_apple_terminal() {
  osascript <<EOF
tell application "Terminal"
  activate
  set found to false
  repeat with w in windows
    repeat with t in tabs of w
      try
        if custom title of t contains "$PROJECT" or processes of t contains "claude" then
          set selected tab of w to t
          set index of w to 1
          set found to true
          exit repeat
        end if
      end try
    end repeat
    if found then exit repeat
  end repeat
end tell
EOF
}

focus_macos() {
  case "$APP" in
    vscode)         focus_with_cli code "$CWD" || open -a "Visual Studio Code" "$CWD" ;;
    cursor)         focus_with_cli cursor "$CWD" || open -a "Cursor" "$CWD" ;;
    zed)            focus_with_cli zed "$CWD" || open -a "Zed" "$CWD" ;;
    iterm)          focus_macos_iterm ;;
    apple-terminal) focus_macos_apple_terminal ;;
    warp)           focus_with_cli warp "$CWD" || open -a "Warp" ;;
    kitty)
      if command -v kitty &>/dev/null; then
        kitty @ focus-window --match "cwd:$CWD" 2>/dev/null || open -a "kitty"
      else
        open -a "kitty"
      fi
      ;;
    ghostty)        open -a "Ghostty" ;;
    alacritty)      open -a "Alacritty" ;;
    rio)            open -a "Rio" ;;
    *)              focus_macos_fallback ;;
  esac
}

focus_macos_fallback() {
  osascript <<EOF
tell application "System Events"
  set allProcs to every application process whose visible is true
  repeat with proc in allProcs
    try
      repeat with w in windows of proc
        if name of w contains "$PROJECT" then
          set frontmost of proc to true
          perform action "AXRaise" of w
          return
        end if
      end repeat
    end try
  end repeat
end tell
EOF
}

# ─── Linux Focus ──────────────────────────────────────────────────────

focus_linux_by_window_title() {
  # X11: xdotool
  if command -v xdotool &>/dev/null; then
    local wid
    wid=$(xdotool search --name "$PROJECT" 2>/dev/null | head -1 || true)
    if [ -n "$wid" ]; then
      xdotool windowactivate "$wid" 2>/dev/null
      return 0
    fi
  fi

  # X11: wmctrl
  if command -v wmctrl &>/dev/null; then
    wmctrl -a "$PROJECT" 2>/dev/null && return 0
  fi

  # Wayland/Sway
  if command -v swaymsg &>/dev/null; then
    swaymsg "[title=$PROJECT]" focus 2>/dev/null && return 0
  fi

  # Wayland/Hyprland
  if command -v hyprctl &>/dev/null; then
    hyprctl dispatch focuswindow "title:$PROJECT" 2>/dev/null && return 0
  fi

  return 1
}

focus_linux() {
  case "$APP" in
    vscode)          focus_with_cli code "$CWD" || focus_linux_by_window_title ;;
    cursor)          focus_with_cli cursor "$CWD" || focus_linux_by_window_title ;;
    zed)             focus_with_cli zed "$CWD" || focus_linux_by_window_title ;;
    kitty)
      if command -v kitty &>/dev/null; then
        kitty @ focus-window --match "cwd:$CWD" 2>/dev/null || focus_linux_by_window_title
      else
        focus_linux_by_window_title
      fi
      ;;
    *)               focus_linux_by_window_title || true ;;
  esac
}

# ─── WSL Focus ────────────────────────────────────────────────────────

focus_wsl() {
  case "$APP" in
    vscode) focus_with_cli code "$CWD" || true ;;
    cursor) focus_with_cli cursor "$CWD" || true ;;
    *)
      # Try to focus Windows Terminal
      powershell.exe -NoProfile -NonInteractive -Command "
        \$wshell = New-Object -ComObject wscript.shell;
        \$wshell.AppActivate('Windows Terminal') -or \$wshell.AppActivate('$PROJECT')
      " 2>/dev/null || true
      ;;
  esac
}

# ─── Dispatch ─────────────────────────────────────────────────────────

case "$OS" in
  macos) focus_macos ;;
  linux) focus_linux ;;
  wsl)   focus_wsl ;;
  *)
    # Best effort: try IDE CLI
    case "$APP" in
      vscode) focus_with_cli code "$CWD" ;;
      cursor) focus_with_cli cursor "$CWD" ;;
      zed)    focus_with_cli zed "$CWD" ;;
      *)      exit 0 ;;
    esac
    ;;
esac
