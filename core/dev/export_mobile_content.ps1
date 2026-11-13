param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# Android and iOS use this shared content stage; no platform SDK or host binary is needed.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'export_build.ps1')
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($request.packages -isnot [Array] -or $request.platform -notin 'Android','iOS') { throw 'Invalid mobile content request' }
$job = Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$contentProject = Join-Path $job 'mobile_content'
$payload = Join-Path $job 'mobile_payload'
$utf8 = New-Object Text.UTF8Encoding($false)
function Status([string]$message) { [IO.File]::WriteAllText((Join-Path $job 'status.txt'),$message,$utf8) }
if ((Test-Path -LiteralPath $contentProject) -or (Test-Path -LiteralPath $payload)) { throw 'Use a fresh mobile build job' }
New-Item -ItemType Directory -Path $payload | Out-Null
Set-PartyExportStage $job 'mobile_prepare' '复制移动端资源'
Status 'Preparing mobile content'
$contentText = New-PartyMobileProject $projectRoot $contentProject $request.platform
# A core-only build deliberately ships a valid empty bundle and needs no content import.
if ($request.packages.Count -gt 0) {
    Set-PartyExportStage $job 'mobile_stage' '准备所选内容及依赖'
    Invoke-PartyGodot $GodotPath -LogPath (Join-Path $job 'mobile-stage.log') -Marker 'CONTENT_SOURCE_STAGE_PASS' -EngineArguments @('--headless','--path',$projectRoot,'--log-file',(Join-Path $job 'mobile-stage-engine.log'),'--script','res://core/dev/export_content.gd','--',"--output=$payload","--request=$RequestPath","--stage-source=$contentProject")
    Set-PartyExportStage $job 'mobile_import' '导入内容资源'
    Status 'Importing mobile content resources'
    Invoke-PartyGodot $GodotPath -LogPath (Join-Path $job 'mobile-import.log') -EngineArguments @('--headless','--path',$contentProject,'--log-file',(Join-Path $job 'mobile-import-engine.log'),'--import')
    Save-PartyCoreImportIndex $contentProject (Join-Path $job 'core_import_files.json')
    Enable-PartyTheme $projectRoot $contentProject $contentText
    Set-PartyExportStage $job 'mobile_pack' '生成内容包'
    Invoke-PartyGodot $GodotPath -LogPath (Join-Path $job 'mobile-content.log') -Marker 'CONTENT_EXPORT_PASS' -EngineArguments @('--headless','--path',$contentProject,'--log-file',(Join-Path $job 'mobile-content-engine.log'),'--script','res://core/dev/export_content.gd','--',"--output=$payload","--request=$RequestPath")
} else {
    [IO.File]::WriteAllText((Join-Path $job 'core_import_files.json'),'[]',$utf8)
    Enable-PartyTheme $projectRoot $contentProject $contentText
}
Set-PartyExportStage $job 'mobile_zip' '压缩内容包'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$bundlePath = Join-Path $job 'mobile_content.zip'
$packages = @(Get-ChildItem -LiteralPath $payload -Recurse -Filter 'content.pck.json' -File | Sort-Object FullName | ForEach-Object { $_.DirectoryName.Substring($payload.Length+1).Replace('\','/') })
$header = @{format=2;id=[guid]::NewGuid().ToString('N');packages=$packages} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $payload 'bundle.json'),$header,$utf8)
$archive = [IO.Compression.ZipFile]::Open($bundlePath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $payload -Recurse -File | Sort-Object FullName) {
        $relative = $file.FullName.Substring($payload.Length+1).Replace('\','/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Fastest) | Out-Null
    }
} finally { $archive.Dispose() }
Write-Output "MOBILE_CONTENT_PASS $bundlePath"
