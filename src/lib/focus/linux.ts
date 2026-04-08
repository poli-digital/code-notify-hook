import { basename } from 'node:path';
import { commandExists, exec } from '../exec.js';
import type { App } from '../../types.js';

async function focusWithCli(cmd: string, cwd: string): Promise<boolean> {
  if (!commandExists(cmd)) return false;
  await exec(`${cmd} "${cwd}"`).catch(() => {});
  return true;
}

async function focusByWindowTitle(project: string): Promise<boolean> {
  // X11: xdotool
  if (commandExists('xdotool')) {
    try {
      const wid = (await exec(`xdotool search --name "${project}" | head -1`)).trim();
      if (wid) {
        await exec(`xdotool windowactivate ${wid}`);
        return true;
      }
    } catch { /* continue to next tool */ }
  }

  // X11: wmctrl
  if (commandExists('wmctrl')) {
    try {
      await exec(`wmctrl -a "${project}"`);
      return true;
    } catch { /* continue */ }
  }

  // Wayland: Sway
  if (commandExists('swaymsg')) {
    try {
      await exec(`swaymsg '[title=${project}]' focus`);
      return true;
    } catch { /* continue */ }
  }

  // Wayland: Hyprland
  if (commandExists('hyprctl')) {
    try {
      await exec(`hyprctl dispatch focuswindow "title:${project}"`);
      return true;
    } catch { /* continue */ }
  }

  return false;
}

export async function focusLinux(app: App, cwd: string): Promise<void> {
  const project = basename(cwd);

  switch (app) {
    case 'vscode':
      if (!(await focusWithCli('code', cwd))) await focusByWindowTitle(project);
      break;
    case 'cursor':
      if (!(await focusWithCli('cursor', cwd))) await focusByWindowTitle(project);
      break;
    case 'zed':
      if (!(await focusWithCli('zed', cwd))) await focusByWindowTitle(project);
      break;
    case 'kitty':
      if (commandExists('kitty')) {
        try {
          await exec(`kitty @ focus-window --match "cwd:${cwd}"`);
        } catch {
          await focusByWindowTitle(project);
        }
      } else {
        await focusByWindowTitle(project);
      }
      break;
    default:
      await focusByWindowTitle(project);
      break;
  }
}
