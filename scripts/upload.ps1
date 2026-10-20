# Sobe .glb/.fbx/.png para o Roblox pela Open Cloud (conta do dono) e anota os IDs em assets_ids.md.
# Uso: powershell -File scripts/upload.ps1 -Files build/arte3d/LiaPiano.glb,build/arte3d/AtticClock.glb
#      powershell -File scripts/upload.ps1 -Folder build/arte3d   (todos os .glb/.fbx/.png da pasta)
# Chave: variável de usuário ROBLOX_API_KEY (assets read/write). Nunca grava a chave em arquivo.
param(
	[string[]]$Files = @(),
	[string]$Folder = "",
	[string]$UserId = "3933707576"
)
$ErrorActionPreference = "Stop"
$key = [Environment]::GetEnvironmentVariable("ROBLOX_API_KEY", "User")
if (-not $key) { $key = $env:ROBLOX_API_KEY }
if (-not $key) { throw "ROBLOX_API_KEY não encontrada" }
if ($Folder) {
	$Files += Get-ChildItem -Path $Folder -File | Where-Object { $_.Extension -in ".glb", ".fbx", ".png" } | ForEach-Object { $_.FullName }
}
$root = Split-Path -Parent $PSScriptRoot
$log = Join-Path $root "assets_ids.md"
if (-not (Test-Path $log)) { "# IDs de assets enviados pela Open Cloud`n`n| Arquivo | Asset ID | Data |`n| --- | --- | --- |" | Out-File -Encoding utf8 $log }
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Add("x-api-key", $key)
foreach ($file in $Files) {
	$path = (Resolve-Path $file).Path
	$name = [IO.Path]::GetFileNameWithoutExtension($path)
	$ext = [IO.Path]::GetExtension($path).ToLower()
	$type, $mime = switch ($ext) {
		".glb" { "Model", "model/gltf-binary" }
		".fbx" { "Model", "model/fbx" }
		".png" { "Decal", "image/png" }
	}
	$request = @{
		assetType = $type
		displayName = $name
		description = "Tung Tung Sahur: The Cursed House"
		creationContext = @{ creator = @{ userId = $UserId } }
	} | ConvertTo-Json -Depth 5 -Compress
	$form = New-Object System.Net.Http.MultipartFormDataContent
	$form.Add((New-Object System.Net.Http.StringContent($request)), "request")
	$bytes = [IO.File]::ReadAllBytes($path)
	$content = New-Object System.Net.Http.ByteArrayContent(, $bytes)
	$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($mime)
	$form.Add($content, "fileContent", [IO.Path]::GetFileName($path))
	$response = $client.PostAsync("https://apis.roblox.com/assets/v1/assets", $form).Result
	$body = $response.Content.ReadAsStringAsync().Result
	if (-not $response.IsSuccessStatusCode) { Write-Output "$name FAIL $($response.StatusCode) $body"; continue }
	$operation = ($body | ConvertFrom-Json).path
	$assetId = $null
	for ($i = 0; $i -lt 40 -and -not $assetId; $i++) {
		Start-Sleep -Seconds 3
		$poll = $client.GetAsync("https://apis.roblox.com/assets/v1/$operation").Result.Content.ReadAsStringAsync().Result
		$state = $poll | ConvertFrom-Json
		if ($state.done) {
			if ($state.response) { $assetId = $state.response.assetId } else { Write-Output "$name FAIL $poll"; break }
		}
	}
	if ($assetId) {
		Write-Output "$name $assetId"
		"| $([IO.Path]::GetFileName($path)) | $assetId | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |" | Out-File -Append -Encoding utf8 $log
	} elseif (-not $state.done) {
		Write-Output "$name TIMEOUT $operation"
	}
}
