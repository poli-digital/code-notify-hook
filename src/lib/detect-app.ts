import type { App } from '../types.js';
import { execSafe } from './exec.js';

const TERM_PROGRAM_MAP: Record<string, App> = {
  vscode: 'vscode',
  cursor: 'cursor',
  zed: 'zed',
  'iTerm.app': 'iterm',
  Apple_Terminal: 'apple-terminal',
  WarpTerminal: 'warp',
  kitty: 'kitty',
  alacritty: 'alacritty',
  ghostty: 'ghostty',
  tmux: 'tmux',
  rio: 'rio',
};

const PROCESS_NAME_PATTERNS: [RegExp, App][] = [
  [/Code Helper|Electron|^code$/i, 'vscode'],
  [/Cursor/i, 'cursor'],
  [/^[Zz]ed$/, 'zed'],
  [/iTerm/i, 'iterm'],
  [/^Terminal$/, 'apple-terminal'],
  [/Warp/i, 'warp'],
  [/kitty/i, 'kitty'],
  [/ghostty/i, 'ghostty'],
  [/alacritty/i, 'alacritty'],
  [/rio/i, 'rio'],
  [/gnome-terminal|mate-terminal/, 'gnome-terminal'],
  [/konsole/, 'konsole'],
  [/xfce4-terminal/, 'xfce4-terminal'],
  [/tilix/, 'tilix'],
];

function walkProcessTree(): App {
  let pid = process.ppid;

  while (pid > 1) {
    const comm = execSafe(`ps -p ${pid} -o comm=`);
    if (!comm) break;

    for (const [pattern, app] of PROCESS_NAME_PATTERNS) {
      if (pattern.test(comm)) return app;
    }

    const ppidStr = execSafe(`ps -p ${pid} -o ppid=`);
    const nextPid = parseInt(ppidStr, 10);
    if (isNaN(nextPid) || nextPid === pid) break;
    pid = nextPid;
  }

  return 'unknown';
}

export function detectApp(): App {
  const termProgram = process.env['TERM_PROGRAM'] ?? '';
  if (termProgram && termProgram in TERM_PROGRAM_MAP) {
    return TERM_PROGRAM_MAP[termProgram]!;
  }

  return walkProcessTree();
}
