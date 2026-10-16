param([string]$Which = "start")
# Atalho global do perfil S9Trailer do OBS: Ctrl+Alt+Shift+F9 (gravar) / F10 (parar), segurado 200 ms.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class S9Keys {
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
$key = if ($Which -eq "start") { 0x67 } else { 0x68 }
foreach ($vk in 0x11, 0x10, 0x12) { [S9Keys]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero) }
Start-Sleep -Milliseconds 60
[S9Keys]::keybd_event([byte]$key, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 200
[S9Keys]::keybd_event([byte]$key, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
foreach ($vk in 0x12, 0x10, 0x11) { [S9Keys]::keybd_event([byte]$vk, 0, 2, [UIntPtr]::Zero) }
"sent $Which"
