import type { OS, NotificationPayload } from '../../types.js';
import { notifyMacOS } from './macos.js';
import { notifyLinux } from './linux.js';
import { notifyWSL } from './wsl.js';

export function sendNotification(os: OS, payload: NotificationPayload): void {
  switch (os) {
    case 'macos': notifyMacOS(payload); break;
    case 'linux': notifyLinux(payload); break;
    case 'wsl':   notifyWSL(payload); break;
  }
}
