import { mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import type { SessionContext } from '../types.js';

const CONTEXT_DIR = join(
  process.env['TMPDIR'] ?? process.env['TMP'] ?? '/tmp',
  'code-hook-notify',
);

function contextPath(sessionId: string): string {
  return join(CONTEXT_DIR, `${sessionId}.json`);
}

export function saveContext(sessionId: string, ctx: SessionContext): void {
  mkdirSync(CONTEXT_DIR, { recursive: true });
  writeFileSync(contextPath(sessionId), JSON.stringify(ctx));
}

export function loadContext(sessionId: string): SessionContext | null {
  try {
    const raw = readFileSync(contextPath(sessionId), 'utf-8');
    return JSON.parse(raw) as SessionContext;
  } catch {
    return null;
  }
}

export function cleanupAll(): void {
  try {
    rmSync(CONTEXT_DIR, { recursive: true, force: true });
  } catch {
    // ignore
  }
}
