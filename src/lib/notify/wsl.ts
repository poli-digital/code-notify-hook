import { spawn } from 'node:child_process';
import type { NotificationPayload } from '../../types.js';

export function notifyWSL(payload: NotificationPayload): void {
  const psTitle = `Claude Code - ${payload.subtitle}`;
  const psMessage = payload.message;

  // Escape single quotes for PowerShell string embedding
  const safeTitle = psTitle.replace(/'/g, "''");
  const safeMessage = psMessage.replace(/'/g, "''");

  const script = `
    try {
      [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime];
      [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime];
      $xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
      $xml.LoadXml('<toast><visual><binding template="ToastGeneric"><text>${safeTitle}</text><text>${safeMessage}</text></binding></visual></toast>');
      [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new($xml));
    } catch {
      Add-Type -AssemblyName System.Windows.Forms;
      $n = New-Object System.Windows.Forms.NotifyIcon;
      $n.Icon = [System.Drawing.SystemIcons]::Information;
      $n.BalloonTipTitle = '${safeTitle}';
      $n.BalloonTipText = '${safeMessage}';
      $n.Visible = $true;
      $n.ShowBalloonTip(5000);
      Start-Sleep -Milliseconds 5500;
      $n.Dispose();
    }
  `;

  const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], {
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
}
