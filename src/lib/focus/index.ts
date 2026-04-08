import type { App, OS } from '../../types.js';
import { focusMacOS } from './macos.js';
import { focusLinux } from './linux.js';
import { focusWSL } from './wsl.js';

export async function focusWindow(os: OS, app: App, cwd: string): Promise<void> {
  switch (os) {
    case 'macos': await focusMacOS(app, cwd); break;
    case 'linux': await focusLinux(app, cwd); break;
    case 'wsl':   await focusWSL(app, cwd); break;
  }
}
