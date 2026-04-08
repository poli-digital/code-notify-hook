#!/usr/bin/env node

import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readStdin, parseHookInput } from './lib/parse-hook-input.js';
import { detectOS } from './lib/detect-os.js';
import { detectApp } from './lib/detect-app.js';
import { saveContext } from './lib/context.js';
import { sendNotification } from './lib/notify/index.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

interface Message {
  subtitle: string;
  message: string;
}

function buildMessage(hookEvent: string, notificationType?: string, cwd?: string): Message | null {
  let subtitle: string;
  let message: string;

  switch (hookEvent) {
    case 'Notification':
      switch (notificationType) {
        case 'permission_prompt':
          subtitle = 'Approval Required';
          message = 'Claude needs your permission to continue.';
          break;
        case 'idle_prompt':
          subtitle = 'Waiting for Input';
          message = 'Claude is waiting for your response.';
          break;
        default:
          subtitle = 'Attention';
          message = 'Claude needs your attention.';
          break;
      }
      break;
    case 'Stop':
      subtitle = 'Task Complete';
      message = 'Claude finished processing.';
      break;
    default:
      return null;
  }

  if (cwd) {
    const project = cwd.split('/').pop() ?? cwd;
    message = `${message} [${project}]`;
  }

  return { subtitle, message };
}

async function main(): Promise<void> {
  const raw = await readStdin();
  const input = parseHookInput(raw);
  const msg = buildMessage(input.hook_event_name, input.notification_type, input.cwd);
  if (!msg) process.exit(0);

  const os = detectOS();
  const app = detectApp();
  const sessionId = input.session_id ?? 'unknown';

  saveContext(sessionId, { app, cwd: input.cwd ?? process.cwd(), os });

  const focusBin = resolve(__dirname, 'focus.js');

  sendNotification(os, {
    title: 'Claude Code',
    subtitle: msg.subtitle,
    message: msg.message,
    sessionId,
    focusBin: `node ${focusBin}`,
  });
}

main().catch(() => process.exit(0));
