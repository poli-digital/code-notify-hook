import { exec as cpExec, execSync, spawn } from 'node:child_process';

export function exec(command: string): Promise<string> {
  return new Promise((resolve, reject) => {
    cpExec(command, { timeout: 10_000 }, (error, stdout) => {
      if (error) reject(error);
      else resolve(stdout.trim());
    });
  });
}

export function execSafe(command: string): string {
  try {
    return execSync(command, { timeout: 5_000, stdio: 'pipe' }).toString().trim();
  } catch {
    return '';
  }
}

export function commandExists(cmd: string): boolean {
  try {
    execSync(`command -v ${cmd}`, { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

export function fireAndForget(command: string, args: string[]): void {
  const child = spawn(command, args, {
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
}
