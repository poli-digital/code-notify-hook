import { spawn } from 'node:child_process';
import { commandExists, execSafe } from '../exec.js';
import type { NotificationPayload } from '../../types.js';

function supportsActions(): boolean {
  const help = execSafe('notify-send --help');
  return help.includes('--action');
}

export function notifyLinux(payload: NotificationPayload): void {
  if (!commandExists('notify-send')) return;

  const title = `Claude Code — ${payload.subtitle}`;

  if (supportsActions()) {
    // notify-send --action blocks until clicked/dismissed.
    // Run in a detached child so the hook process can exit.
    const child = spawn(
      'sh',
      [
        '-c',
        `ACTION=$(notify-send "${title}" "${payload.message}" ` +
        `--app-name="Claude Code" --icon=terminal ` +
        `--action="focus=Open Session" 2>/dev/null || true); ` +
        `[ "$ACTION" = "focus" ] && "${payload.focusBin}" "${payload.sessionId}"`,
      ],
      { detached: true, stdio: 'ignore' },
    );
    child.unref();
  } else {
    spawn(
      'notify-send',
      [title, payload.message, '--app-name=Claude Code', '--icon=terminal'],
      { detached: true, stdio: 'ignore' },
    ).unref();
  }
}
