import { readFileSync } from 'node:fs';
import { platform } from 'node:os';
import type { OS } from '../types.js';

export function detectOS(): OS {
  const p = platform();

  if (p === 'darwin') return 'macos';

  if (p === 'linux') {
    try {
      const version = readFileSync('/proc/version', 'utf-8');
      if (/microsoft/i.test(version)) return 'wsl';
    } catch {
      // /proc/version not readable — assume native Linux
    }
    return 'linux';
  }

  return 'unknown';
}
