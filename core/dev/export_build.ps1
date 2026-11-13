# Shared build subprocess handling and mobile project preparation. Never edits the author project.
. (Join-Path $PSScriptRoot 'export_source_files.ps1')

function Write-PartyExportProgress([string]$JobDirectory, $Record) {
    $path = Join-Path $JobDirectory 'progress.json'
    $pending = Join-Path $JobDirectory 'progress.next.json'
    [IO.File]::WriteAllText($pending,($Record | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $path) { [IO.File]::Replace($pending,$path,[NullString]::Value) }
    else { [IO.File]::Move($pending,$path) }
}

function Initialize-PartyExportProgress([string]$JobDirectory, $Request) {
    $steps = @('prepare')
    if ($Request.platform -eq 'iOS') { $steps += 'cloud','download','publish' }
    elseif ($Request.platform -eq 'Android') {
        $steps += 'mobile_prepare'
        if ($Request.packages.Count) { $steps += 'mobile_stage','mobile_import','mobile_pack' }
        $steps += 'mobile_zip'
        if ($Request.core) { $steps += 'core_prepare','core_import','core_export' }
        $steps += 'publish'
    } else {
        if ($Request.core) { $steps += 'core_prepare','core_import','core_export' }
        if ($Request.packages.Count) { $steps += 'content' }
        $steps += 'publish'
    }
    Write-PartyExportProgress $JobDirectory @{steps=$steps; completed=0; total=$steps.Count; stage='准备导出'; indeterminate=$false}
}

function Set-PartyExportStage([string]$JobDirectory, [string]$Step, [string]$Label, [bool]$Indeterminate = $false) {
    if (!$JobDirectory) { return }
    $path = Join-Path $JobDirectory 'progress.json'
    # Low-level command-line builders can run without an editor job/progress record.
    if (!(Test-Path -LiteralPath $path)) { return }
    $record = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $completed = if ($Step -eq 'complete') { $record.total } else { [Array]::IndexOf($record.steps,$Step) }
    if ($completed -lt $record.completed) { throw "Invalid export stage order: $Step" }
    $record.completed = $completed
    $record.stage = $Label
    $record.indeterminate = $Indeterminate
    Write-PartyExportProgress $JobDirectory $record
}

# Inputs are already checked by the source collector. Avoid PowerShell cmdlet dispatch per file.
function Copy-PartyBuildFiles([string]$SourceRoot, [string]$DestinationRoot, [object[]]$Files) {
    $directories = [Collections.Generic.HashSet[string]]::new()
    foreach ($file in $Files) {
        $target = Join-Path $DestinationRoot $file.FullName.Substring($SourceRoot.Length + 1)
        $parent = [IO.Path]::GetDirectoryName($target)
        if ($directories.Add($parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
        [IO.File]::Copy($file.FullName,$target,$false)
    }
}

# Record only core remaps and their Godot-generated outputs/validation metadata, never game caches.
function Save-PartyCoreImportIndex([string]$Project, [string]$IndexPath) {
    $paths = [Collections.Generic.HashSet[string]]::new()
    $maps = @(Get-ChildItem -LiteralPath (Join-Path $Project 'core') -Recurse -Filter '*.import' -File)
    $maps += Get-Item -LiteralPath (Join-Path $Project 'icon.svg.import')
    foreach ($map in $maps) {
        [void]$paths.Add($map.FullName.Substring($Project.Length+1).Replace('\','/'))
        $text = [IO.File]::ReadAllText($map.FullName)
        foreach ($reference in [regex]::Matches($text,'"res://(\.godot/imported/[^"\r\n]+)"')) {
            $relative = $reference.Groups[1].Value
            [void]$paths.Add($relative)
            # Godot uses one validation sidecar per imported source, including multi-format textures.
            $stem = [regex]::Match([IO.Path]::GetFileName($relative),'^(.+-[a-f0-9]{32})\.').Groups[1].Value
            if (!$stem) { throw "Unknown Godot import output: $relative" }
            [void]$paths.Add('.godot/imported/' + $stem + '.md5')
        }
    }
    [IO.File]::WriteAllText($IndexPath,(ConvertTo-Json -InputObject @($paths | Sort-Object)),(New-Object Text.UTF8Encoding($false)))
}

function Copy-PartyCoreImports([string]$SourceProject, [string]$DestinationProject) {
    $paths = Get-Content -LiteralPath (Join-Path (Split-Path $SourceProject) 'core_import_files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($relative in $paths) {
        $target = Join-Path $DestinationProject $relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.File]::Copy((Join-Path $SourceProject $relative),$target,$true)
    }
    Write-Output "CORE_IMPORT_REUSE files=$($paths.Count)"
}

function Invoke-PartyGodot([string]$GodotPath, [string[]]$EngineArguments, [string]$LogPath, [string]$Marker = '') {
    Get-Command $GodotPath -CommandType Application -ErrorAction Stop | Out-Null
    # PowerShell 5 turns native stderr into ErrorRecords; judge the completed process and its log.
    $code = & {
        $ErrorActionPreference = 'Continue'
        & $GodotPath @EngineArguments 2>&1 | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $LogPath -Encoding UTF8 -ErrorAction Stop
        $LASTEXITCODE
    }
    if ($code -ne 0 -or (Select-String -LiteralPath $LogPath -Pattern 'SCRIPT ERROR|ERROR:') -or ($Marker -and !(Select-String -LiteralPath $LogPath -SimpleMatch -Pattern $Marker))) {
        throw "Godot build failed ($code). See $LogPath"
    }
}

function Get-PartyProjectVersion([string]$ProjectRoot) {
    $text = Get-Content -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Raw -Encoding UTF8
    $application = [regex]::Match($text, '(?ms)^\[application\]\r?\n.*?(?=^\[|\z)').Value
    $match = [regex]::Match($application, '(?m)^config/version=(.+)\r?$')
    if (!$match.Success) { throw 'project.godot must declare application/config/version' }
    $version = $match.Groups[1].Value.Trim() | ConvertFrom-Json
    if ($version -isnot [string] -or !$version.Trim()) { throw 'Invalid application/config/version' }
    return $version
}

function Set-PartyProjectValue([string]$text, [string]$section, [string]$key, [string]$value) {
    $sectionPattern = '(?ms)^\[' + [regex]::Escape($section) + '\]\r?\n.*?(?=^\[|\z)'
    $match = [regex]::Match($text,$sectionPattern)
    $line = $key + '=' + $value
    if (!$match.Success) { return $text + "`n[$section]`n$line`n" }
    $block = $match.Value -replace ('(?m)^' + [regex]::Escape($key) + '=.*(?:\r?\n|\z)'), ''
    $block = $block.TrimEnd() + "`n$line`n`n"
    return $text.Substring(0,$match.Index) + $block + $text.Substring($match.Index+$match.Length)
}
function New-PartyMobileProject([string]$projectRoot, [string]$destination, [string]$platform, [string]$CoreSource = '') {
    $utf8 = New-Object Text.UTF8Encoding($false)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $coreRoot = if ($CoreSource) { $CoreSource } else { $projectRoot }
    Copy-PartyBuildFiles $coreRoot $destination @(Get-PartyCoreFiles $coreRoot)
    # Stamp only the staged framework; the editor declaration remains editor.
    $dataFile = Join-Path $destination 'core/runtime/party_data.gd'
    $dataText = (Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8).Replace('const SYSTEM: String = "editor"', ('const SYSTEM: String = "' + $platform.ToLowerInvariant() + '"'))
    [IO.File]::WriteAllText($dataFile, $dataText, $utf8)
    New-Item -ItemType Directory -Path (Join-Path $destination 'core/dev') -Force | Out-Null
    foreach ($name in @('export_content.gd','party_shared_pack_builder.gd','export_shared_pack.gd')) {
        Copy-Item -LiteralPath (Join-Path (Join-Path $projectRoot 'core/dev') $name) -Destination (Join-Path $destination 'core/dev')
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination $destination
    $text = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8
    $text = $text -replace '(?ms)^\[autoload\].*?(?=^\[|\z)', '' -replace '(?ms)^\[editor_plugins\].*?(?=^\[|\z)', ''
    $text = $text -replace '(?m)^theme/custom(?:_font)?=.*\r?\n', ''
    # Editor imports do not use runtime override.cfg; put build-only values in the staged project.
    $text = Set-PartyProjectValue $text 'application' 'config/quit_on_go_back' 'false'
    $text = Set-PartyProjectValue $text 'display' 'window/handheld/orientation' '0'
    $text = Set-PartyProjectValue $text 'editor' 'export/convert_text_resources_to_binary' 'false'
    $text = Set-PartyProjectValue $text 'rendering' 'renderer/rendering_method' '"gl_compatibility"'
    $text = Set-PartyProjectValue $text 'rendering' 'renderer/rendering_method.mobile' '"gl_compatibility"'
    $text = Set-PartyProjectValue $text 'rendering' 'textures/vram_compression/import_etc2_astc' 'true'
    $text = Set-PartyProjectValue $text 'rendering' 'textures/vram_compression/import_s3tc_bptc' 'true'
    $text = Set-PartyProjectValue $text 'editor' 'import/use_multiple_threads' 'false'
    $text = Set-PartyProjectValue $text 'content' 'shared_import' 'true'
    $text = Set-PartyProjectValue $text 'input_devices' 'pointing/emulate_mouse_from_touch' 'true'
    $text = Set-PartyProjectValue $text 'input_devices' 'pointing/emulate_touch_from_mouse' 'false'
    [IO.File]::WriteAllText((Join-Path $destination 'project.godot'),$text,$utf8)
    return $text
}
function Enable-PartyTheme([string]$projectRoot, [string]$destination, [string]$text) {
    $utf8 = New-Object Text.UTF8Encoding($false)
    $original = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8
    $themes = [regex]::Matches($original,'(?m)^theme/custom(?:_font)?=.*$') | ForEach-Object { $_.Value.TrimEnd() }
    if ($themes.Count -gt 0) { $text = $text -replace '(?m)^\[gui\]', ("[gui]`n" + ($themes -join "`n")) }
    [IO.File]::WriteAllText((Join-Path $destination 'project.godot'),$text,$utf8)
}
