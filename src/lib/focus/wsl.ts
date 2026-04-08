import { basename } from 'node:path';
import { commandExists, exec } from '../exec.js';
import type { App } from '../../types.js';

async function focusWithCli(cmd: string, cwd: string): Promise<boolean> {
  if (!commandExists(cmd)) return false;
  await exec(`${cmd} "${cwd}"`).catch(() => {});
  return true;
}

export async function focusWSL(app: App, cwd: string): Promise<void> {
  const project = basename(cwd);

  switch (app) {
    case 'vscode':
      await focusWithCli('code', cwd);
      break;
    case 'cursor':
      await focusWithCli('cursor', cwd);
      break;
    default:
      // Try to focus Windows Terminal or any window matching the project name
      await exec(
        `powershell.exe -NoProfile -NonInteractive -Command ` +
        `"$wshell = New-Object -ComObject wscript.shell; ` +
        `$wshell.AppActivate('Windows Terminal') -or $wshell.AppActivate('${project}')"`,
      ).catch(() => {});
      break;
  }
}
