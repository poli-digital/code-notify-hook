import { commandExists, fireAndForget } from '../exec.js';
import type { NotificationPayload } from '../../types.js';

export function notifyMacOS(payload: NotificationPayload): void {
  if (commandExists('terminal-notifier')) {
    fireAndForget('terminal-notifier', [
      '-title', 'Claude Code',
      '-subtitle', payload.subtitle,
      '-message', payload.message,
      '-sound', 'default',
      '-execute', `${payload.focusBin} ${payload.sessionId}`,
      '-group', `code-notify-hook-${payload.sessionId}`,
      '-ignoreDnD',
    ]);
  } else {
    const script =
      `display notification "${payload.message}" ` +
      `with title "Claude Code" ` +
      `subtitle "${payload.subtitle}" ` +
      `sound name "default"`;
    fireAndForget('osascript', ['-e', script]);
  }
}
