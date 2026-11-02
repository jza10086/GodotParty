param(
    [string]$GodotPath = 'godot'
)

# Build the framework host. Protocol, avatar and game packages are installed separately.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engineVersion = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($engineVersion)) {
    throw "Unable to read system Godot version: $engineVersion"
}
$buildRoot = Join-Path $projectRoot ('tmp/windows_host_' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $buildRoot 'source'
$outputRoot = Join-Path $buildRoot 'bin'
New-Item -ItemType Directory -Path $sourceRoot, $outputRoot -Force | Out-Null
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core') -Recurse -File) {
    $relative = $file.FullName.Substring($projectRoot.Length + 1)
    if ($relative -match '^core[\\/](saves[\\/]|config[\\/].*\.(cfg|bak|pending)$)' -or $file.Name.Contains('~')) { continue }
    $destination = Join-Path $sourceRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}
foreach ($name in @('icon.svg', 'export_presets.cfg')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $sourceRoot
}
$presetPath = Join-Path $sourceRoot 'export_presets.cfg'
$presetText = (Get-Content -LiteralPath $presetPath -Raw).Replace('debug/export_console_wrapper=1', 'debug/export_console_wrapper=0').Replace('binary_format/embed_pck=false', 'binary_format/embed_pck=true')
Set-Content -LiteralPath $presetPath -Value $presetText -Encoding utf8
$projectText = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
$projectText = $projectText -replace '(?ms)^\[autoload\].*?(?=^\[)', '' -replace '(?ms)^\[editor_plugins\].*?(?=^\[)', ''
$projectText = $projectText -replace '(?m)^.*\.rhythm_web_preview=.*\r?\n', ''
Set-Content -LiteralPath (Join-Path $sourceRoot 'project.godot') -Value $projectText -Encoding utf8
$importLog = Join-Path $buildRoot 'import.log'
& $GodotPath --headless --path $sourceRoot --import *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|ERROR:')) {
    throw "Core import failed. See $importLog"
}
$exportLog = Join-Path $buildRoot 'export.log'
& $GodotPath --headless --path $sourceRoot --export-release 'Windows Desktop' (Join-Path $outputRoot 'GodotParty.exe') *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR|ERROR:')) {
    throw "Windows export failed. See $exportLog"
}
[pscustomobject]@{ Engine = $engineVersion; Directory = $outputRoot }

foreach ($category in @('protocols', 'maingame', 'minigame', 'core/config', 'core/notices')) {
    New-Item -ItemType Directory -Path (Join-Path $outputRoot $category) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'core/dev/windows_release_notices/Godot-LICENSE.txt'), (Join-Path $projectRoot 'core/dev/windows_release_notices/Godot-COPYRIGHT.txt') -Destination (Join-Path $outputRoot 'core/notices')
