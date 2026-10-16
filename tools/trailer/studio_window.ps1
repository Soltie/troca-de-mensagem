param(
	[string]$Action = "show",
	[int]$Hwnd = 0
)
# Utilitário de QA do trailer: mostra/foca/esconde a janela do Studio descartável e acha a área do jogo
# (quadro magenta) para o recorte do OBS. Não altera configurações do sistema.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public class S9Win {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void Focus(IntPtr h) {
    keybd_event(0x12, 0, 0, UIntPtr.Zero);       // Alt (libera o SetForegroundWindow)
    SetForegroundWindow(h);
    BringWindowToTop(h);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
  // Retângulo (tela) dos pixels magenta dentro de `area`.
  public static string FindMagenta(int x, int y, int w, int h) {
    using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bmp)) { g.CopyFromScreen(x, y, 0, 0, new Size(w, h)); }
      var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      int minX = w, minY = h, maxX = -1, maxY = -1;
      byte[] bytes = new byte[data.Stride * h];
      Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
      for (int py = 0; py < h; py++) {
        int row = py * data.Stride;
        for (int px = 0; px < w; px++) {
          int i = row + px * 4;
          byte b = bytes[i], gg = bytes[i + 1], r = bytes[i + 2];
          if (r > 235 && b > 235 && gg < 25) {
            if (px < minX) minX = px; if (px > maxX) maxX = px;
            if (py < minY) minY = py; if (py > maxY) maxY = py;
          }
        }
      }
      bmp.UnlockBits(data);
      if (maxX < 0) return "none";
      return string.Format("{0},{1},{2},{3}", x + minX, y + minY, maxX - minX + 1, maxY - minY + 1);
    }
  }
}
"@ -ReferencedAssemblies System.Drawing

$h = [IntPtr]$Hwnd
switch ($Action) {
	"show" {
		# 2º monitor (à esquerda), maximizado.
		[void][S9Win]::ShowWindow($h, 1)
		[void][S9Win]::SetWindowPos($h, [IntPtr]::Zero, -1900, 20, 1600, 900, 0x0040)
		[void][S9Win]::ShowWindow($h, 3)
		Start-Sleep -Milliseconds 400
		[S9Win]::Focus($h)
		Start-Sleep -Milliseconds 300
		$r = New-Object S9Win+RECT; [void][S9Win]::GetWindowRect($h, [ref]$r)
		"visible={0} foreground={1} rect={2},{3},{4},{5}" -f [S9Win]::IsWindowVisible($h), ([S9Win]::GetForegroundWindow() -eq $h), $r.L, $r.T, $r.R, $r.B
	}
	"focus" {
		[S9Win]::Focus($h)
		"foreground={0}" -f ([S9Win]::GetForegroundWindow() -eq $h)
	}
	"measure" {
		$c = New-Object S9Win+RECT; [void][S9Win]::GetClientRect($h, [ref]$c)
		$p = New-Object S9Win+POINT; [void][S9Win]::ClientToScreen($h, [ref]$p)
		$found = [S9Win]::FindMagenta($p.X, $p.Y, $c.R, $c.B)
		"client={0},{1},{2},{3} magenta={4}" -f $p.X, $p.Y, $c.R, $c.B, $found
	}
	"hide" {
		[void][S9Win]::ShowWindow($h, 0)
		"hidden"
	}
}
