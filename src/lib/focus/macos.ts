import { basename } from 'node:path';
import { commandExists, exec } from '../exec.js';
import type { App } from '../../types.js';

async function focusWithCli(cmd: string, cwd: string): Promise<boolean> {
  if (!commandExists(cmd)) return false;
  await exec(`${cmd} "${cwd}"`).catch(() => {});
  return true;
}

async function focusIterm(project: string): Promise<void> {
  const script = `
tell application "iTerm"
  activate
  set found to false
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if name of s contains "${project}" then
          select t
          set found to true
          exit repeat
        end if
      end repeat
      if found then exit repeat
    end repeat
    if found then
      set index of w to 1
      exit repeat
    end if
  end repeat
end tell`;
  await exec(`osascript -e '${script.replace(/'/g, "'\\''")}'`).catch(() => {});
}

async function focusAppleTerminal(project: string): Promise<void> {
  const script = `
tell application "Terminal"
  activate
  set found to false
  repeat with w in windows
    repeat with t in tabs of w
      try
        if custom title of t contains "${project}" or processes of t contains "claude" then
          set selected tab of w to t
          set index of w to 1
          set found to true
          exit repeat
        end if
      end try
    end repeat
    if found then exit repeat
  end repeat
end tell`;
  await exec(`osascript -e '${script.replace(/'/g, "'\\''")}'`).catch(() => {});
}

async function focusFallback(project: string): Promise<void> {
  const script = `
tell application "System Events"
  set allProcs to every application process whose visible is true
  repeat with proc in allProcs
    try
      repeat with w in windows of proc
        if name of w contains "${project}" then
          set frontmost of proc to true
          perform action "AXRaise" of w
          return
        end if
      end repeat
    end try
  end repeat
end tell`;
  await exec(`osascript -e '${script.replace(/'/g, "'\\''")}'`).catch(() => {});
}

export async function focusMacOS(app: App, cwd: string): Promise<void> {
  const project = basename(cwd);

  switch (app) {
    case 'vscode':
      if (!(await focusWithCli('code', cwd))) await exec(`open -a "Visual Studio Code" "${cwd}"`).catch(() => {});
      break;
    case 'cursor':
      if (!(await focusWithCli('cursor', cwd))) await exec(`open -a "Cursor" "${cwd}"`).catch(() => {});
      break;
    case 'zed':
      if (!(await focusWithCli('zed', cwd))) await exec(`open -a "Zed" "${cwd}"`).catch(() => {});
      break;
    case 'iterm':
      await focusIterm(project);
      break;
    case 'apple-terminal':
      await focusAppleTerminal(project);
      break;
    case 'warp':
      if (!(await focusWithCli('warp', cwd))) await exec('open -a "Warp"').catch(() => {});
      break;
    case 'kitty':
      if (commandExists('kitty')) {
        await exec(`kitty @ focus-window --match "cwd:${cwd}"`).catch(() => exec('open -a "kitty"').catch(() => {}));
      } else {
        await exec('open -a "kitty"').catch(() => {});
      }
      break;
    case 'ghostty':  await exec('open -a "Ghostty"').catch(() => {}); break;
    case 'alacritty': await exec('open -a "Alacritty"').catch(() => {}); break;
    case 'rio':       await exec('open -a "Rio"').catch(() => {}); break;
    default:
      await focusFallback(project);
      break;
  }
}
