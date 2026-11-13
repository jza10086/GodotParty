# Shared build subprocess handling and mobile project preparation. Never edits the author project.
. (Join-Path $PSScriptRoot 'export_source_files.ps1')

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
function New-PartyMobileProject([string]$projectRoot, [string]$destination, [string]$platform) {
    $utf8 = New-Object Text.UTF8Encoding($false)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($file in Get-PartyCoreFiles $projectRoot) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1)
        $target = Join-Path $destination $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
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
