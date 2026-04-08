#!/usr/bin/env node

import { loadContext } from './lib/context.js';
import { focusWindow } from './lib/focus/index.js';

async function main(): Promise<void> {
  const sessionId = process.argv[2];
  if (!sessionId) process.exit(0);

  const ctx = loadContext(sessionId);
  if (!ctx) process.exit(0);

  await focusWindow(ctx.os, ctx.app, ctx.cwd);
}

main().catch(() => process.exit(0));
