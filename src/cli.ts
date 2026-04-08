#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { detectOS } from './lib/detect-os.js';
import { commandExists } from './lib/exec.js';
import { cleanupAll } from './lib/context.js';

// ─── Colors ──────────────────────────────────────────────────────────

const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const NC = '\x1b[0m';

const info  = (msg: string) => console.log(`${CYAN}[info]${NC}  ${msg}`);
const ok    = (msg: string) => console.log(`${GREEN}[ok]${NC}    ${msg}`);
const warn  = (msg: string) => console.log(`${YELLOW}[warn]${NC}  ${msg}`);
const error = (msg: string) => console.log(`${RED}[error]${NC} ${msg}`);

// ─── Paths ───────────────────────────────────────────────────────────

const CLAUDE_DIR = join(homedir(), '.claude');
const SETTINGS_PATH = join(CLAUDE_DIR, 'settings.json');

// ─── Hook entry template ─────────────────────────────────────────────

const HOOK_ENTRY = {
  matcher: '',
  hooks: [
    {
      type: 'command',
      command: 'code-notify-hook-hook',
      timeout: 10,
      async: true,
    },
  ],
};

// ─── Install ─────────────────────────────────────────────────────────

function install(): void {
  console.log('');
  console.log('  code-notify-hook installer');
  console.log('  ─────────────────────────');
  console.log('');

  const os = detectOS();
  info(`Detected OS: ${os}`);
  console.log('');

  // Check dependencies
  const missing: string[] = [];

  switch (os) {
    case 'macos':
      if (!commandExists('terminal-notifier')) missing.push('terminal-notifier');
      break;
    case 'linux':
      if (!commandExists('notify-send')) missing.push('libnotify / notify-send');
      break;
    case 'wsl':
      if (!commandExists('powershell.exe')) missing.push('powershell.exe');
      break;
  }

  if (missing.length > 0) {
    error('Missing dependencies:');
    for (const dep of missing) console.log(`       - ${dep}`);
    console.log('');

    if (os === 'macos') {
      info('Install with:');
      console.log('       brew install terminal-notifier');
    } else if (os === 'linux') {
      info('Install with (Debian/Ubuntu):');
      console.log('       sudo apt install libnotify-bin');
      info('Or (Fedora):');
      console.log('       sudo dnf install libnotify');
      info('Or (Arch):');
      console.log('       sudo pacman -S libnotify');
    }

    console.log('');
    error('Please install the missing dependencies and run this again.');
    process.exit(1);
  }

  ok('All dependencies found.');

  // Optional focus tools (Linux)
  if (os === 'linux') {
    const hasAny = ['xdotool', 'wmctrl', 'swaymsg', 'hyprctl'].some(commandExists);
    if (!hasAny) {
      warn('No window-focus tool found (xdotool, wmctrl, swaymsg, hyprctl).');
      warn('Click-to-focus will rely on IDE CLIs only (code, zed, cursor).');
      console.log('');
    }
  }

  // Patch settings.json
  info(`Configuring hooks in ${SETTINGS_PATH} ...`);
  mkdirSync(CLAUDE_DIR, { recursive: true });

  if (!existsSync(SETTINGS_PATH)) {
    const settings = {
      hooks: {
        Notification: [HOOK_ENTRY],
        Stop: [HOOK_ENTRY],
      },
    };
    writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2));
    ok(`Created ${SETTINGS_PATH} with notification hooks.`);
  } else {
    // Backup
    const backup = `${SETTINGS_PATH}.backup.${Date.now()}`;
    copyFileSync(SETTINGS_PATH, backup);
    info(`Backup saved to ${backup}`);

    const settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf-8'));
    settings.hooks ??= {};
    settings.hooks.Notification ??= [];
    settings.hooks.Stop ??= [];

    const hasHook = (arr: Array<{ hooks?: Array<{ command?: string }> }>) =>
      arr.some((entry) => entry.hooks?.some((h) => String(h.command ?? '').includes('code-notify-hook')));

    if (!hasHook(settings.hooks.Notification)) {
      settings.hooks.Notification.push(HOOK_ENTRY);
    }
    if (!hasHook(settings.hooks.Stop)) {
      settings.hooks.Stop.push(HOOK_ENTRY);
    }

    writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2));
    ok('Updated settings.json with notification hooks.');
  }

  console.log('');
  console.log(`${GREEN}  Installation complete!${NC}`);
  console.log('');
  console.log('  Hooks installed:');
  console.log('    - Notification  → push notification when Claude needs input');
  console.log('    - Stop          → push notification when Claude finishes');
  console.log('');
  console.log('  Restart Claude Code to activate.');
  console.log('');
}

// ─── Uninstall ───────────────────────────────────────────────────────

function uninstall(): void {
  console.log('');
  console.log('  code-notify-hook uninstaller');
  console.log('  ───────────────────────────');
  console.log('');

  if (existsSync(SETTINGS_PATH)) {
    const backup = `${SETTINGS_PATH}.backup.${Date.now()}`;
    copyFileSync(SETTINGS_PATH, backup);
    info(`Backup saved to ${backup}`);

    const settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf-8'));

    if (settings.hooks) {
      const filterHooks = (arr: Array<{ hooks?: Array<{ command?: string }> }>) =>
        arr.filter((entry) => !entry.hooks?.some((h) => String(h.command ?? '').includes('code-notify-hook')));

      if (settings.hooks.Notification) {
        settings.hooks.Notification = filterHooks(settings.hooks.Notification);
        if (settings.hooks.Notification.length === 0) delete settings.hooks.Notification;
      }
      if (settings.hooks.Stop) {
        settings.hooks.Stop = filterHooks(settings.hooks.Stop);
        if (settings.hooks.Stop.length === 0) delete settings.hooks.Stop;
      }
      if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
    }

    writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2));
    ok('Cleaned hooks from settings.json');
  }

  cleanupAll();
  ok('Cleaned temporary files.');

  console.log('');
  console.log(`${GREEN}  Uninstall complete.${NC}`);
  console.log('');
}

// ─── Doctor ──────────────────────────────────────────────────────────

function doctor(): void {
  console.log('');
  console.log('  code-notify-hook doctor');
  console.log('  ──────────────────────');
  console.log('');

  const os = detectOS();
  info(`OS: ${os}`);

  const checks: [string, boolean | 'skip'][] = [
    ['node', true],
    ['terminal-notifier', os === 'macos' ? commandExists('terminal-notifier') : 'skip'],
    ['notify-send', os === 'linux' ? commandExists('notify-send') : 'skip'],
    ['powershell.exe', os === 'wsl' ? commandExists('powershell.exe') : 'skip'],
    ['xdotool (optional)', os === 'linux' ? commandExists('xdotool') : 'skip'],
    ['wmctrl (optional)', os === 'linux' ? commandExists('wmctrl') : 'skip'],
  ];

  for (const [name, status] of checks) {
    if (status === 'skip') continue;
    if (status) ok(name);
    else if (name.includes('optional')) warn(`${name} — not found`);
    else error(`${name} — not found`);
  }

  console.log('');

  // Check settings.json
  if (existsSync(SETTINGS_PATH)) {
    try {
      const settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf-8'));
      const hasNotif = settings.hooks?.Notification?.some((e: { hooks?: Array<{ command?: string }> }) =>
        e.hooks?.some((h) => String(h.command ?? '').includes('code-notify-hook')));
      const hasStop = settings.hooks?.Stop?.some((e: { hooks?: Array<{ command?: string }> }) =>
        e.hooks?.some((h) => String(h.command ?? '').includes('code-notify-hook')));

      if (hasNotif && hasStop) ok('Hooks configured in settings.json');
      else warn('Hooks partially configured — run "code-notify-hook install"');
    } catch {
      error('settings.json is not valid JSON');
    }
  } else {
    warn('~/.claude/settings.json not found — run "code-notify-hook install"');
  }

  console.log('');
}

// ─── Main ────────────────────────────────────────────────────────────

const command = process.argv[2];

switch (command) {
  case 'install':   install(); break;
  case 'uninstall': uninstall(); break;
  case 'doctor':    doctor(); break;
  default:
    console.log('');
    console.log('  Usage: code-notify-hook <command>');
    console.log('');
    console.log('  Commands:');
    console.log('    install     Install hooks into ~/.claude/settings.json');
    console.log('    uninstall   Remove hooks and clean up');
    console.log('    doctor      Check dependencies and configuration');
    console.log('');
    process.exit(command ? 1 : 0);
}
