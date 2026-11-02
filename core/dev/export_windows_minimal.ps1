param(
    [string]$GodotPath = 'godot'
)

# Build an isolated, bundled Avalon release from the current working files.
# All release-only configuration changes stay under tmp; author packages are untouched.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engineVersion = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($engineVersion)) {
    throw "Unable to read the selected Godot version: $engineVersion"
}
$buildRoot = Join-Path $projectRoot ('tmp/windows_minimal_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
if (Test-Path -LiteralPath $buildRoot) { throw "Build directory already exists: $buildRoot" }
$sourceRoot = Join-Path $buildRoot 'source'
$outputRoot = Join-Path $buildRoot 'GodotParty-Minimal-Avalon-Windows-x64'
New-Item -ItemType Directory -Path $sourceRoot, $outputRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Write-Json([string]$Path, $Value) {
    Write-Text $Path ($Value | ConvertTo-Json -Depth 40)
}
$packagePaths = @(
    'games/protocols/godot_party_default_protocol',
    'games/protocols/godot_party_default_protocol/avatars/godot_party_default_avatars',
    'games/maingame/godot_party_default_maingame_minigame_playlist',
    'games/minigame/godot_party_default_identity_party'
)
foreach ($relativeRoot in @('core') + $packagePaths) {
    $directory = Join-Path $projectRoot $relativeRoot
    foreach ($file in Get-ChildItem -LiteralPath $directory -Recurse -File -Force) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected link: $($file.FullName)" }
        # Never package backup files, build tooling, documentation or local caches.
        if ($file.FullName -match '[\\/]core[\\/](saves[\\/]|config[\\/].*\.(cfg|bak|pending)$)') { continue }
        if ($file.Extension -in @('.tmp', '.ps1', '.py', '.pyc', '.cmd', '.bat', '.md', '.txt') -or $file.Name.Contains('~')) { continue }
        $relative = $file.FullName.Substring($projectRoot.Length + 1)
        $destination = Join-Path $sourceRoot $relative
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination $sourceRoot

$miniRoot = Join-Path $sourceRoot $packagePaths[3]
$miniManifestPath = Join-Path $miniRoot 'manifest.json'
$miniManifest = Get-Content -LiteralPath $miniManifestPath -Raw | ConvertFrom-Json
$miniManifest.name = 'GodotPartyDefault · 阿瓦隆'
$miniManifest.introduction = '5–8 人联机阿瓦隆：队长提名、队伍投票、远征与终局刺杀。'
$miniManifest.package_version = '1.0.0-minimal-avalon.1'
$miniManifest.player_counts = @(5, 6, 7, 8)
$miniManifest.PSObject.Properties.Remove('player_count_rules')
Write-Json $miniManifestPath $miniManifest
$miniSchemaPath = Join-Path $miniRoot 'config_schema.json'
$miniSchema = Get-Content -LiteralPath $miniSchemaPath -Raw | ConvertFrom-Json
$miniSchema.fields.mode.default = '阿瓦隆'
$miniSchema.fields.mode.values = @('阿瓦隆')
Write-Json $miniSchemaPath $miniSchema
$mainRoot = Join-Path $sourceRoot $packagePaths[2]
$mainManifestPath = Join-Path $mainRoot 'manifest.json'
$mainManifest = Get-Content -LiteralPath $mainManifestPath -Raw | ConvertFrom-Json
$mainManifest.package_version = '1.0.0-minimal-avalon.1'
Write-Json $mainManifestPath $mainManifest
$mainSchemaPath = Join-Path $mainRoot 'config_schema.json'
$mainSchema = Get-Content -LiteralPath $mainSchemaPath -Raw | ConvertFrom-Json
$mainSchema.fields.rounds.default = 1
Write-Json $mainSchemaPath $mainSchema

$projectText = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
$projectText = $projectText -replace '(?ms)^\[autoload\].*?(?=^\[)', '' -replace '(?ms)^\[editor_plugins\].*?(?=^\[)', ''
$projectText = $projectText -replace '(?m)^.*\.rhythm_web_preview=.*\r?\n', ''
$projectText = $projectText.Replace('config/name="GodotParty"', 'config/name="GodotParty Minimal Avalon"')
$projectText = $projectText.Replace('"Forward Plus"', '"GL Compatibility"')
$projectText = $projectText.Replace('rendering_device/driver.windows="d3d12"', 'renderer/rendering_method="gl_compatibility"')
$projectText = $projectText.Replace('[display]', "[display]`nwindow/size/window_width_override=1280`nwindow/size/window_height_override=720")
Write-Text (Join-Path $sourceRoot 'project.godot') $projectText
$presetText = Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw
$presetText = ($presetText -split '(?m)^\[preset\.1\]')[0]
$presetText = $presetText -replace 'debug/export_console_wrapper=\d+', 'debug/export_console_wrapper=0'
$presetText = $presetText.Replace('binary_format/embed_pck=false', 'binary_format/embed_pck=true')
$presetText = $presetText -replace '(?m)^exclude_filter=.*$', 'exclude_filter="games/*,core/dev/export_content.gd,core/config/*.cfg,core/config/*.bak,core/saves/*"'
Write-Text (Join-Path $sourceRoot 'export_presets.cfg') $presetText

# Include notices as readable sidecar files, preserving their source-relative locations.
$noticesRoot = Join-Path $outputRoot 'core/notices'
foreach ($relativeRoot in @('core') + $packagePaths) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $relativeRoot) -Recurse -File) {
        if ($file.Name -notmatch '(?i)license|copying|copyright|ofl|attribution|sources|upstream_art' -and $file.FullName -notmatch 'avatar_sources.*README\.md$') { continue }
        if ($file.Extension -notin @('.md', '.txt')) { continue }
        $destination = Join-Path $noticesRoot $file.FullName.Substring($projectRoot.Length + 1)
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'doc/credits.md') -Destination (Join-Path $noticesRoot 'project-credits.md')
$engineNotices = Join-Path $projectRoot 'core/dev/windows_release_notices'
Copy-Item -LiteralPath (Join-Path $engineNotices 'Godot-LICENSE.txt'), (Join-Path $engineNotices 'Godot-COPYRIGHT.txt') -Destination $noticesRoot
$importLog = Join-Path $buildRoot 'import.log'
& $GodotPath --headless --path $sourceRoot --import *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|ERROR:')) {
    throw "Minimal release import failed. See $importLog"
}
$contentLog = Join-Path $buildRoot 'content.log'
& $GodotPath --headless --path $sourceRoot --script 'res://core/dev/export_content.gd' -- "--output=$outputRoot" *> $contentLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $contentLog -Pattern 'SCRIPT ERROR|ERROR:')) {
    throw "Content export failed. See $contentLog"
}
$exportLog = Join-Path $buildRoot 'export.log'
& $GodotPath --headless --path $sourceRoot --export-release 'Windows Desktop' (Join-Path $outputRoot 'GodotParty.exe') *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR|ERROR:')) {
    throw "Minimal release export failed. See $exportLog"
}
foreach ($name in @('GodotParty.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $outputRoot $name))) { throw "Missing release file: $name" }
}
$archive = Join-Path $buildRoot 'GodotParty-Minimal-Avalon-Windows-x64.zip'
Compress-Archive -LiteralPath $outputRoot -DestinationPath $archive -CompressionLevel Optimal
[pscustomobject]@{ Engine = $engineVersion; Directory = $outputRoot; Archive = $archive; BuildRoot = $buildRoot }
