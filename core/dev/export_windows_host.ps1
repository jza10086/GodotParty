param(
    [string]$GodotPath = 'godot',
    [string]$BuildRoot,
    [string]$OutputDirectory
)
# Build the core from a clean copy. User data and content never enter the EXE.
$ErrorActionPreference = 'Stop'
Get-Command $GodotPath -CommandType Application -ErrorAction Stop | Out-Null
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (!$BuildRoot) { $BuildRoot = Join-Path $projectRoot ('tmp/exports/host_' + [guid]::NewGuid().ToString('N')) }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $BuildRoot 'bin' }
$sourceRoot = Join-Path $BuildRoot 'source'
New-Item -ItemType Directory -Path $sourceRoot, $OutputDirectory -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core') -Recurse -File) {
    $relative = $file.FullName.Substring($projectRoot.Length + 1)
    if ($relative -match '^core[\\/](saves[\\/]|dev[\\/]|config[\\/].*\.(json|cfg|bak|pending)$)' -or $file.Name.Contains('~') -or $file.Extension -in '.tmp','.bak','.pending') { continue }
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked file: $relative" }
    $destination = Join-Path $sourceRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}
# Stamp only the staged framework; the editor declaration remains pc.
$dataFile = Join-Path $sourceRoot 'core/runtime/party_data.gd'
$dataText = (Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8).Replace('const SYSTEM: String = "pc"', 'const SYSTEM: String = "windows"')
[IO.File]::WriteAllText($dataFile, $dataText, $utf8)
# The formal application uses this small argument reader.
New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'core/dev') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'core/dev/party_arguments.gd') -Destination (Join-Path $sourceRoot 'core/dev')
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination $sourceRoot
$presetText = (Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw -Encoding UTF8) -split '(?m)^\[preset\.1\]'
$presetText = $presetText[0] -replace 'debug/export_console_wrapper=\d+', 'debug/export_console_wrapper=0'
$presetText = $presetText -replace 'binary_format/embed_pck=false', 'binary_format/embed_pck=true'
$presetText = $presetText -replace '(?m)^exclude_filter=.*$', 'exclude_filter="core/config/*.json,core/config/*.bak,core/config/*.pending,core/saves/*"'
[IO.File]::WriteAllText((Join-Path $sourceRoot 'export_presets.cfg'), $presetText, $utf8)
$projectText = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8
$projectText = $projectText -replace '(?ms)^\[autoload\].*?(?=^\[)', '' -replace '(?ms)^\[editor_plugins\].*?(?=^\[)', ''
$projectText = $projectText -replace '(?m)^export/convert_text_resources_to_binary=.*\r?\n', ''
$projectText = $projectText -replace '(?m)^\[editor\]', "[editor]`nexport/convert_text_resources_to_binary=false"
if ($projectText -notmatch '(?m)^\[editor\]') { $projectText += "`n[editor]`nexport/convert_text_resources_to_binary=false`n" }
$projectFile = Join-Path $sourceRoot 'project.godot'
# Startup themes load before the first import. Their textures/fonts do not exist yet
# in this clean copy; restore the real theme immediately after importing its assets.
$importProjectText = $projectText -replace '(?m)^theme/custom(?:_font)?=.*\r?\n', ''
[IO.File]::WriteAllText($projectFile, $importProjectText, $utf8)
foreach ($step in @('import','export')) {
    $log = Join-Path $BuildRoot ($step + '.log')
    if ($step -eq 'import') {
        $engineArguments = @('--headless', '--path', $sourceRoot, '--log-file', (Join-Path $BuildRoot 'import-engine.log'), '--import')
    } else {
        $engineArguments = @('--headless', '--path', $sourceRoot, '--log-file', (Join-Path $BuildRoot 'export-engine.log'), '--export-release', 'Windows Desktop', (Join-Path $OutputDirectory 'GodotParty.exe'))
    }
    try {
        # Windows PowerShell 5 treats native stderr as ErrorRecords. Capture all of it
        # before checking the process result instead of aborting at the first line.
        $exitCode = & {
            $ErrorActionPreference = 'Continue'
            & $GodotPath @engineArguments 2>&1 | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $log -Encoding UTF8 -ErrorAction Stop
            $LASTEXITCODE
        }
    } finally {
        if ($step -eq 'import') { [IO.File]::WriteAllText($projectFile, $projectText, $utf8) }
    }
    if ($exitCode -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Core $step failed. See $log" }
}
$notices = Join-Path $OutputDirectory 'core/notices'
New-Item -ItemType Directory $notices -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'doc/credits.md') -Destination (Join-Path $notices 'project-credits.md')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core') -Recurse -File) {
    if ($file.Extension -notin '.md','.txt' -or $file.Name -notmatch '(?i)license|copyright|copying|ofl|source|attribution') { continue }
    $target = Join-Path $notices $file.FullName.Substring($projectRoot.Length + 1)
    New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target
}
[pscustomobject]@{ Directory = $OutputDirectory; BuildRoot = $BuildRoot }
