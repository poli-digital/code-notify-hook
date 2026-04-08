import type { HookInput } from '../types.js';

export function parseHookInput(raw: string): HookInput {
  const data = JSON.parse(raw);
  return {
    hook_event_name: data.hook_event_name ?? '',
    notification_type: data.notification_type,
    cwd: data.cwd,
    session_id: data.session_id,
  };
}

export function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
  });
}
