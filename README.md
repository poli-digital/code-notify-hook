# claude-code-notify

Native push notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Get notified when Claude needs your approval or finishes a task — click the notification to jump straight to the right window.

## Why

Claude Code often runs long tasks in the background. You switch to a browser, another terminal, or a different project — and miss when Claude needs a permission approval or finishes working. This tool sends **native OS notifications** and, when clicked, **focuses the exact IDE window or terminal tab** where the session is running.

## Features

- **Native notifications** on macOS, Linux and Windows (WSL)
- **Click-to-focus** opens the exact IDE window / terminal tab for the session
- **Auto-detects your IDE** — VS Code, Cursor, Zed, iTerm2, Warp, Kitty, Ghostty, and more
- **Multi-project aware** — identifies the correct window even with multiple projects open
- **Zero config** — install and forget; works with Claude Code's [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks)

## Platform Support

| Feature | macOS | Linux | WSL |
|---------|-------|-------|-----|
| Notifications | terminal-notifier | notify-send (libnotify) | PowerShell toast |
| Sound | Yes | Depends on DE | Yes |
| Click-to-focus | Full | Full (X11 + Wayland) | IDE CLI only |

## Supported IDEs & Terminals

Click-to-focus finds the right window by project directory, not just the app.

| Application | macOS | Linux | WSL | Detection method |
|-------------|:-----:|:-----:|:---:|------------------|
| VS Code | Yes | Yes | Yes | `TERM_PROGRAM` + `code $CWD` |
| Cursor | Yes | Yes | Yes | `TERM_PROGRAM` + `cursor $CWD` |
| Zed | Yes | Yes | — | `TERM_PROGRAM` + `zed $CWD` |
| iTerm2 | Yes | — | — | AppleScript (finds tab by title) |
| Terminal.app | Yes | — | — | AppleScript (finds tab by title) |
| Warp | Yes | Yes | — | `TERM_PROGRAM` + CLI |
| Kitty | Yes | Yes | — | `kitty @ focus-window --match cwd:` |
| Ghostty | Yes | Yes | — | `open -a` / window title match |
| Alacritty | Yes | Yes | — | `open -a` / window title match |
| Rio | Yes | Yes | — | `open -a` / window title match |
| GNOME Terminal | — | Yes | — | `xdotool` / `wmctrl` |
| Konsole | — | Yes | — | `xdotool` / `wmctrl` |
| Windows Terminal | — | — | Partial | `AppActivate` via PowerShell |
| **Unknown app** | Fallback* | Fallback* | — | Searches all windows by project name |

\* Fallback scans all visible windows for one whose title contains the project directory name.

## Quick Start

### Prerequisites

| OS | Required | Optional (click-to-focus) |
|----|----------|--------------------------|
| **macOS** | `jq`, `terminal-notifier` | — (built-in AppleScript) |
| **Linux** | `jq`, `notify-send` | `xdotool` or `wmctrl` (X11) |
| **WSL** | `jq` | — (`powershell.exe` is built-in) |

### Install

```bash
git clone https://github.com/gabrielhenrique/claude-code-notify.git
cd claude-code-notify
bash install.sh
```

The installer will:
1. Check that all dependencies are present
2. Copy hook scripts to `~/.claude/hooks/`
3. Add hook entries to `~/.claude/settings.json` (creates a backup first)
4. Create a config file at `~/.config/claude-code-notify/config`
5. Run a quick verification

### Install dependencies (if needed)

**macOS:**
```bash
brew install jq terminal-notifier
```

**Linux (Debian / Ubuntu):**
```bash
sudo apt install jq libnotify-bin xdotool  # xdotool is optional
```

**Linux (Fedora):**
```bash
sudo dnf install jq libnotify xdotool
```

**Linux (Arch):**
```bash
sudo pacman -S jq libnotify xdotool
```

**WSL:**
```bash
sudo apt install jq
# powershell.exe is available by default in WSL
```

### Uninstall

```bash
cd claude-code-notify
bash uninstall.sh
```

## How It Works

This tool uses Claude Code's [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell commands that run automatically in response to lifecycle events.

Two hooks are registered:

| Hook Event | When it fires |
|------------|---------------|
| `Notification` | Claude needs user input (permission prompt, idle prompt) |
| `Stop` | Claude finishes processing a response |

### Flow

```
Claude Code emits event
  │
  ▼
notify.sh (hook script)
  ├── Parses the event JSON from stdin
  ├── Detects the OS (macOS / Linux / WSL)
  ├── Detects the host app via TERM_PROGRAM env var
  │   (fallback: walks the process tree)
  ├── Saves session context to /tmp/claude-code-notify/{session_id}
  └── Sends a native notification
        │
        ▼ (user clicks)
      focus-session.sh
        ├── Reads session context (app + directory + OS)
        └── Focuses the correct window:
              ├── IDEs: CLI command (code/zed/cursor $CWD)
              ├── macOS terminals: AppleScript window search
              ├── Linux: xdotool/wmctrl/swaymsg/hyprctl
              └── Fallback: searches all windows by project name
```

### App Detection

The primary detection method is the `TERM_PROGRAM` environment variable, which is set by most terminal emulators and IDE integrated terminals:

| App | `TERM_PROGRAM` value |
|-----|----------------------|
| VS Code | `vscode` |
| Cursor | `cursor` |
| Zed | `zed` |
| iTerm2 | `iTerm.app` |
| Terminal.app | `Apple_Terminal` |
| Warp | `WarpTerminal` |
| Kitty | `kitty` |
| Ghostty | `ghostty` |
| Alacritty | `alacritty` |
| Rio | `rio` |

If `TERM_PROGRAM` is not set, the script walks up the process tree (`$PPID` → parent → grandparent → ...) checking each process name against known applications.

## Configuration

### Config file

The installer creates a config file at `~/.config/claude-code-notify/config` (respects `$XDG_CONFIG_HOME`). Edit it to customise notification behaviour — no need to touch the hook scripts.

All options with their defaults:

```bash
# Show a macOS alert dialog that bypasses Focus / Do Not Disturb.
# Set to false to rely solely on Notification Center.
# (macOS only)
NOTIFY_ALERT=true

# Seconds the alert stays on screen before auto-dismissing.
# (macOS only, requires NOTIFY_ALERT=true)
NOTIFY_ALERT_TIMEOUT=8

# Sound to play with the notification.
# macOS: "default", "Basso", "Blow", "Bottle", "Frog", "Funk",
#        "Glass", "Hero", "Morse", "Ping", "Pop", "Purr",
#        "Sosumi", "Submarine", "Tink"
# Set to "" to disable sound.
NOTIFY_SOUND="default"

# Bypass Focus / Do Not Disturb via terminal-notifier's -ignoreDnD.
# (macOS only)
NOTIFY_DND_BYPASS=true
```

Options are commented out by default — uncomment and change only what you need.

> **Tip:** the config file is a plain shell script sourced at runtime, so changes take effect on the next notification with no restart required.

### settings.json

The installer adds this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/notify.sh",
            "timeout": 10,
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/notify.sh",
            "timeout": 10,
            "async": true
          }
        ]
      }
    ]
  }
}
```

### Disable specific events

To only get notified when Claude needs input (not on every stop), remove the `Stop` entry from `hooks` in your settings.

## Troubleshooting

### Notifications don't appear

**macOS:**
- Check that `terminal-notifier` is installed: `which terminal-notifier`
- Check System Settings > Notifications > terminal-notifier is allowed
- Verify Do Not Disturb is off (the `NOTIFY_DND_BYPASS` and `NOTIFY_ALERT` options bypass Focus modes, but some configurations may still block — see [Config file](#config-file))

**Linux:**
- Check that `notify-send` is installed: `which notify-send`
- Some notification daemons (dunst, mako) need configuration for app icons
- Test manually: `notify-send "Test" "Hello"`

**WSL:**
- Check that `powershell.exe` is accessible: `which powershell.exe`
- Windows notifications must be enabled in Settings > System > Notifications

### Click-to-focus doesn't work

**All platforms:**
- Ensure the IDE CLI is in your PATH (`code --version`, `zed --version`, `cursor --version`)
- For VS Code, run "Shell Command: Install 'code' command in PATH" from the command palette

**Linux:**
- Install `xdotool` (X11) or use Sway/Hyprland which have built-in window focus commands
- On Wayland (non-Sway/Hyprland), click-to-focus may not work for terminal apps — IDE CLIs still work

**WSL:**
- Click-to-focus is limited to IDE CLIs. Windows Terminal focus uses `AppActivate` which matches by window title.

### Wrong window gets focused

- The script matches by project directory name (`basename $CWD`). If two projects have the same directory name, the first match wins.
- For IDEs, the CLI (`code $CWD`) uses the full path so this is precise. The issue only affects terminal-based fallback matching.

### Hook doesn't fire

- Verify hooks are configured: run `/hooks` inside Claude Code to list active hooks
- Check that `~/.claude/settings.json` is valid JSON: `jq . ~/.claude/settings.json`
- Restart Claude Code after changing settings

## Contributing

Contributions are welcome! Some areas that could use help:

- [ ] Custom notification icon
- [ ] Better WSL click-to-focus (BurntToast module integration)
- [ ] Wayland compositor support beyond Sway and Hyprland
- [ ] Configurable notification filtering (e.g., only notify after N seconds of idle)
- [ ] Integration tests

## License

[MIT](LICENSE)
