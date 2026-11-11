param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# Build Android resources in isolated projects. Never reuse desktop texture import caches.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$androidSdkPath = ''
$localSettingsPath = Join-Path $projectRoot 'tmp/local/android_export.json'
if ($request.core -and (Test-Path -LiteralPath $localSettingsPath)) {
    $localSettings = Get-Content -LiteralPath $localSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $androidSdkPath = [string]$localSettings.android_sdk_path
    if (!$androidSdkPath -or ![IO.Path]::IsPathRooted($androidSdkPath)) { throw "android_sdk_path must be absolute: $localSettingsPath" }
    if (!(Test-Path -LiteralPath (Join-Path $androidSdkPath 'platform-tools/adb.exe') -PathType Leaf)) { throw "Android SDK is missing platform-tools/adb.exe: $androidSdkPath" }
    $buildTools = Join-Path $androidSdkPath 'build-tools'
    if (!(Test-Path -LiteralPath $buildTools -PathType Container) -or !(Get-ChildItem -LiteralPath $buildTools -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') -PathType Leaf })) { throw "Android SDK is missing build-tools/apksigner.bat: $androidSdkPath" }
}
$job = Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$stage = Join-Path $job 'build'
$contentProject = Join-Path $job 'android_content'
$hostProject = Join-Path $job 'android_host'
$payload = Join-Path $job 'android_payload'
$utf8 = New-Object Text.UTF8Encoding($false)
function Status([string]$message) { [IO.File]::WriteAllText((Join-Path $job 'status.txt'),$message,$utf8) }
function Run-Godot([string]$name, [string[]]$engineArguments) {
    $log = Join-Path $job ($name + '.log')
    $code = & {
        $ErrorActionPreference = 'Continue'
        & $GodotPath @engineArguments 2>&1 | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $log -Encoding UTF8 -ErrorAction Stop
        $LASTEXITCODE
    }
    if ($code -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:')) { throw "$name failed. See $log" }
}
function Set-ProjectValue([string]$text, [string]$section, [string]$key, [string]$value) {
    $sectionPattern = '(?ms)^\[' + [regex]::Escape($section) + '\]\r?\n.*?(?=^\[|\z)'
    $match = [regex]::Match($text,$sectionPattern)
    $line = $key + '=' + $value
    if (!$match.Success) { return $text + "`n[$section]`n$line`n" }
    $block = $match.Value -replace ('(?m)^' + [regex]::Escape($key) + '=.*\r?\n'), ''
    $block = $block.TrimEnd() + "`n$line`n`n"
    return $text.Substring(0,$match.Index) + $block + $text.Substring($match.Index+$match.Length)
}
function New-AndroidProject([string]$destination) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core') -Recurse -File) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1)
        if ($relative -match '^core[\\/](saves[\\/]|dev[\\/]|config[\\/].*\.(json|cfg|bak|pending)$)' -or $file.Name.StartsWith('.') -or $file.Name.Contains('~') -or $file.Extension -in '.tmp','.bak','.pending') { continue }
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked file: $relative" }
        $target = Join-Path $destination $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
    # Stamp only the staged framework; the editor declaration remains pc.
    $dataFile = Join-Path $destination 'core/runtime/party_data.gd'
    $dataText = (Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8).Replace('const SYSTEM: String = "pc"', 'const SYSTEM: String = "android"')
    [IO.File]::WriteAllText($dataFile, $dataText, $utf8)
    New-Item -ItemType Directory -Path (Join-Path $destination 'core/dev') -Force | Out-Null
    foreach ($name in @('party_arguments.gd','export_content.gd','party_export_selection.gd')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $destination 'core/dev')
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination $destination
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'android_export_presets.cfg') -Destination (Join-Path $destination 'export_presets.cfg')
    $text = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8
    $text = $text -replace '(?ms)^\[autoload\].*?(?=^\[)', '' -replace '(?ms)^\[editor_plugins\].*?(?=^\[)', ''
    $text = $text -replace '(?m)^theme/custom(?:_font)?=.*\r?\n', ''
    # Editor imports do not use runtime override.cfg; put build-only values in the staged project.
    $text = Set-ProjectValue $text 'application' 'config/quit_on_go_back' 'false'
    $text = Set-ProjectValue $text 'display' 'window/handheld/orientation' '0'
    $text = Set-ProjectValue $text 'editor' 'export/convert_text_resources_to_binary' 'false'
    $text = Set-ProjectValue $text 'rendering' 'renderer/rendering_method' '"gl_compatibility"'
    $text = Set-ProjectValue $text 'rendering' 'renderer/rendering_method.mobile' '"gl_compatibility"'
    $text = Set-ProjectValue $text 'rendering' 'textures/vram_compression/import_etc2_astc' 'true'
    $text = Set-ProjectValue $text 'input_devices' 'pointing/emulate_mouse_from_touch' 'true'
    $text = Set-ProjectValue $text 'input_devices' 'pointing/emulate_touch_from_mouse' 'false'
    [IO.File]::WriteAllText((Join-Path $destination 'project.godot'),$text,$utf8)
    return $text
}
function Enable-Theme([string]$destination, [string]$text) {
    $original = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8
    $themes = [regex]::Matches($original,'(?m)^theme/custom(?:_font)?=.*$') | ForEach-Object { $_.Value.TrimEnd() }
    if ($themes.Count -gt 0) { $text = $text -replace '(?m)^\[gui\]', ("[gui]`n" + ($themes -join "`n")) }
    [IO.File]::WriteAllText((Join-Path $destination 'project.godot'),$text,$utf8)
}
Status 'Preparing selected Android content'
$contentText = New-AndroidProject $contentProject
Run-Godot 'android-stage' @('--headless','--path',$projectRoot,'--log-file',(Join-Path $job 'android-stage-engine.log'),'--script','res://core/dev/export_content.gd','--',"--output=$payload","--request=$RequestPath","--stage-source=$contentProject")
Status 'Importing Android content resources'
Run-Godot 'android-content-import' @('--headless','--path',$contentProject,'--log-file',(Join-Path $job 'android-content-import-engine.log'),'--import')
Enable-Theme $contentProject $contentText
Run-Godot 'android-content' @('--headless','--path',$contentProject,'--log-file',(Join-Path $job 'android-content-engine.log'),'--script','res://core/dev/export_content.gd','--',"--output=$payload","--request=$RequestPath")
if (!(Select-String -LiteralPath (Join-Path $job 'android-content.log') -Pattern 'CONTENT_EXPORT_PASS')) { throw 'Android content export did not finish' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$bundlePath = Join-Path $stage 'GodotParty-content-android.zip'
$packages = @(Get-ChildItem -LiteralPath $payload -Recurse -Filter 'content.pck.json' | ForEach-Object { $_.DirectoryName.Substring($payload.Length+1).Replace('\','/') })
$header = @{format=1;id=[guid]::NewGuid().ToString('N');platform=$request.platform;packages=$packages} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $payload 'bundle.json'),$header,$utf8)
$archive = [IO.Compression.ZipFile]::Open($bundlePath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $payload -Recurse -File) {
        $relative = $file.FullName.Substring($payload.Length+1).Replace('\','/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
if ($request.core) {
    Status 'Building Android APK'
    $hostText = New-AndroidProject $hostProject
    if ($androidSdkPath) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'android_export_settings.gd') -Destination (Join-Path $hostProject 'core/dev')
        [IO.File]::WriteAllText((Join-Path $hostProject 'core/dev/android_export_settings.cfg'), "[plugin]`nname=`"Android export settings`"`ndescription=`"Local SDK configuration`"`nauthor=`"GodotParty`"`nversion=`"1.0`"`nscript=`"android_export_settings.gd`"`n", $utf8)
        $hostText = Set-ProjectValue $hostText 'editor_plugins' 'enabled' 'PackedStringArray("res://core/dev/android_export_settings.cfg")'
        # Enable only after resource import; the SDK override belongs to the APK export process.
    }
    Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $hostProject 'core/bundled_content.zip')
    Copy-Item -LiteralPath (Join-Path $projectRoot 'doc/credits.md') -Destination (Join-Path $hostProject 'core/project-credits.md')
    Run-Godot 'android-host-import' @('--headless','--path',$hostProject,'--log-file',(Join-Path $job 'android-host-import-engine.log'),'--import')
    Enable-Theme $hostProject $hostText
    $previousSdkPath = $env:GODOTPARTY_ANDROID_SDK_PATH
    try {
        if ($androidSdkPath) { $env:GODOTPARTY_ANDROID_SDK_PATH = $androidSdkPath }
        Run-Godot 'android-apk' @('--headless','--path',$hostProject,'--log-file',(Join-Path $job 'android-apk-engine.log'),'--export-debug','Android',(Join-Path $stage 'GodotParty.apk'))
    } finally { $env:GODOTPARTY_ANDROID_SDK_PATH = $previousSdkPath }
}
