param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# Build Android resources in isolated projects. Never reuse desktop texture import caches.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'export_build.ps1')
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
$hostProject = Join-Path $job 'mobile_host'
$utf8 = New-Object Text.UTF8Encoding($false)
function Status([string]$message) { [IO.File]::WriteAllText((Join-Path $job 'status.txt'),$message,$utf8) }
& (Join-Path $PSScriptRoot 'export_mobile_content.ps1') -RequestPath $RequestPath -GodotPath $GodotPath
$bundlePath = Join-Path $job 'mobile_content.zip'
Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $stage 'GodotParty-content-android.zip')
if ($request.core) {
    Status 'Building Android APK'
    Set-PartyExportStage $job 'core_prepare' '准备 Android 核心'
    $contentProject = Join-Path $job 'mobile_content'
    $hostText = New-PartyMobileProject $projectRoot $hostProject 'Android' -CoreSource $contentProject
    Copy-PartyCoreImports $contentProject $hostProject
    $preset = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'android_export_presets.cfg') -Raw -Encoding UTF8
    $versionValue = ConvertTo-Json -InputObject (Get-PartyProjectVersion $projectRoot) -Compress
    $preset = Set-PartyProjectValue $preset 'preset.0.options' 'version/name' $versionValue
    [IO.File]::WriteAllText((Join-Path $hostProject 'export_presets.cfg'),$preset,$utf8)
    if ($androidSdkPath) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'android_export_settings.gd') -Destination (Join-Path $hostProject 'core/dev')
        [IO.File]::WriteAllText((Join-Path $hostProject 'core/dev/android_export_settings.cfg'), "[plugin]`nname=`"Android export settings`"`ndescription=`"Local SDK configuration`"`nauthor=`"GodotParty`"`nversion=`"1.0`"`nscript=`"android_export_settings.gd`"`n", $utf8)
        $hostText = Set-PartyProjectValue $hostText 'editor_plugins' 'enabled' 'PackedStringArray("res://core/dev/android_export_settings.cfg")'
        # Enable only after resource import; the SDK override belongs to the APK export process.
    }
    Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $hostProject 'core/bundled_content.zip')
    Copy-Item -LiteralPath (Join-Path $projectRoot 'doc/credits.md') -Destination (Join-Path $hostProject 'core/project-credits.md')
    Set-PartyExportStage $job 'core_import' '检查并导入核心资源'
    Invoke-PartyGodot $GodotPath -LogPath (Join-Path $job 'android-host-import.log') -EngineArguments @('--headless','--path',$hostProject,'--log-file',(Join-Path $job 'android-host-import-engine.log'),'--import')
    Enable-PartyTheme $projectRoot $hostProject $hostText
    $previousSdkPath = $env:GODOTPARTY_ANDROID_SDK_PATH
    try {
        if ($androidSdkPath) { $env:GODOTPARTY_ANDROID_SDK_PATH = $androidSdkPath }
        Set-PartyExportStage $job 'core_export' '生成 Android APK'
        Invoke-PartyGodot $GodotPath -LogPath (Join-Path $job 'android-apk.log') -EngineArguments @('--headless','--path',$hostProject,'--log-file',(Join-Path $job 'android-apk-engine.log'),'--export-debug','Android',(Join-Path $stage 'GodotParty.apk'))
    } finally { $env:GODOTPARTY_ANDROID_SDK_PATH = $previousSdkPath }
    if (!(Test-Path -LiteralPath (Join-Path $stage 'GodotParty.apk') -PathType Leaf)) { throw 'Android export did not produce an APK' }
}
