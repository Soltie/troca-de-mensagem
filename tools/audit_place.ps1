[CmdletBinding()]
param([string]$PlacePath = 'build/PlaytestDupla_ATUALIZADO.rbxlx')

# Confere todo o código embutido contra src e o preset que sobrevive à migração do Studio.
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifactPath = if ([IO.Path]::IsPathRooted($PlacePath)) { $PlacePath } else { Join-Path $repoPath $PlacePath }
$buildXml = [xml][IO.File]::ReadAllText($artifactPath)
$buildScripts = @{}
function Read-Items($parent, [string]$prefix) {
    foreach ($item in $parent.SelectNodes('Item')) {
        $nameNode = $item.SelectSingleNode('Properties/*[@name="Name"]')
        $itemPath = if ($prefix) { "$prefix/$($nameNode.InnerText)" } else { $nameNode.InnerText }
        $sourceNode = $item.SelectSingleNode('Properties/*[@name="Source"]')
        if ($sourceNode) {
            $buildScripts[$itemPath] = @{ source = $sourceNode.InnerText.Replace("`r`n", "`n"); class = $item.GetAttribute('class') }
        }
        Read-Items $item $itemPath
    }
}
Read-Items $buildXml.DocumentElement ''
function Get-SourceHash([string]$sourceText) {
    $digest = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($sourceText))) }
    finally { $digest.Dispose() }
}
function Get-Signature([string]$sourceText) {
    $sourceBytes = [Text.Encoding]::UTF8.GetBytes($sourceText)
    [long]$a = 1
    [long]$b = 0
    foreach ($byte in $sourceBytes) { $a = ($a + $byte) % 65521; $b = ($b + $a) % 65521 }
    return @{ bytes = $sourceBytes.Length; adler32 = $b * 65536 + $a }
}
$sourceRoot = Join-Path $repoPath 'src'
$entries = @()
$mismatches = @()
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.luau') {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $file.FullName).Replace('\', '/')
    $instancePath = $relative -replace '\.(server|client|local)\.luau$', '' -replace '\.luau$', ''
    $expectedClass = if ($relative -match '\.local\.luau$') { 'LocalScript' } elseif ($relative -match '\.(server|client)\.luau$') { 'Script' } else { 'ModuleScript' }
    $diskSource = [IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")
    $embedded = $buildScripts[$instancePath]
    $matches = $null -ne $embedded -and $embedded.source -ceq $diskSource -and $embedded.class -eq $expectedClass
    if (-not $matches) { $mismatches += $instancePath }
    $entries += @{ file = $relative; path = $instancePath; class = $expectedClass; sha256 = Get-SourceHash $diskSource; signature = Get-Signature $diskSource; matches = $matches }
}
$extra = @($buildScripts.Keys | Where-Object { $_ -notin $entries.path })
$lighting = $buildXml.SelectSingleNode('/roblox/Item[@class="Lighting"]')
$validLighting = $null -ne $lighting -and
    $lighting.SelectSingleNode('Properties/token[@name="Technology"]').InnerText -eq '4' -and
    $lighting.SelectSingleNode('Properties/token[@name="LightingStyle"]').InnerText -eq '0' -and
    $lighting.SelectSingleNode('Properties/bool[@name="PrioritizeLightingQuality"]').InnerText -eq 'true'
$report = @{
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    artifact = $artifactPath
    artifactSha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
    head = (git -C $repoPath rev-parse HEAD)
    sourceCount = $entries.Count
    embeddedCount = $buildScripts.Count
    mismatches = $mismatches
    extraScripts = $extra
    lightingProperties = $lighting.Properties.OuterXml
    lightingPresetValid = $validLighting
    projectSha256 = (Get-FileHash -LiteralPath (Join-Path $repoPath 'default.project.json')).Hash
    worldFiles = @(Get-ChildItem (Join-Path $repoPath 'places/world') -Recurse -File | ForEach-Object { @{ path = [IO.Path]::GetRelativePath($repoPath, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash } })
    sourceFiles = $entries
}
$reportPath = [IO.Path]::ChangeExtension($artifactPath, '.audit.json')
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($mismatches.Count -or $extra.Count -or $entries.Count -ne $buildScripts.Count -or -not $validLighting) {
    throw "Artifact differs from current source or has an invalid lighting preset; inspect $reportPath"
}
$signatures = @{}
foreach ($entry in $entries) { $signatures[$entry.path] = $entry.signature }
@{ sourceCount = $entries.Count; embeddedCount = $buildScripts.Count; mismatches = $mismatches; extraScripts = $extra; lightingPresetValid = $validLighting; sha256 = $report.artifactSha256; signatures = $signatures } | ConvertTo-Json -Depth 8 -Compress
