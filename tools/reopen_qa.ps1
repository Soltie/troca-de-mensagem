# Recompila build/FinalPolish.rbxlx a partir de src/ e reabre só a janela do Studio dessa place.
# Uso: powershell -File tools/reopen_qa.ps1 [-Name FinalPolish]
param([string]$Name = "FinalPolish")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$place = Join-Path $root "build\$Name.rbxlx"
Push-Location $root
try {
	rojo build default.project.json --output $place | Out-Null
} finally {
	Pop-Location
}
Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
	Where-Object { $_.MainWindowTitle -like "*\$Name.rbxlx*" } |
	ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Seconds 2
$exe = (Get-ChildItem "C:\Program Files\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
Start-Process $exe -ArgumentList "`"$place`""
for ($i = 0; $i -lt 60; $i++) {
	Start-Sleep -Seconds 2
	$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*\$Name.rbxlx*" }
	if ($p) { Write-Output "opened $place (pid $($p.Id))"; exit 0 }
}
Write-Output "timeout waiting for Studio"
exit 1
