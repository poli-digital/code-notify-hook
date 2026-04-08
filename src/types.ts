export type OS = 'macos' | 'linux' | 'wsl' | 'unknown';

export type App =
  | 'vscode'
  | 'cursor'
  | 'zed'
  | 'iterm'
  | 'apple-terminal'
  | 'warp'
  | 'kitty'
  | 'ghostty'
  | 'alacritty'
  | 'rio'
  | 'gnome-terminal'
  | 'konsole'
  | 'xfce4-terminal'
  | 'tilix'
  | 'tmux'
  | 'unknown';

export interface HookInput {
  hook_event_name: string;
  notification_type?: string;
  cwd?: string;
  session_id?: string;
}

export interface SessionContext {
  app: App;
  cwd: string;
  os: OS;
}

export interface NotificationPayload {
  title: string;
  subtitle: string;
  message: string;
  sessionId: string;
  focusBin: string;
}
