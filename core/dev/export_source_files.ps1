# Same simple root-relative pattern contract as party_export_files.gd.
function Get-PartyExportRules([string]$Root) {
    $path = Join-Path $Root 'export_ignore.txt'
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { $path = Join-Path $PSScriptRoot '../content/default_export_ignore.txt' }
    $lineNumber = 0
    foreach ($raw in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        $lineNumber++
        $line = $raw.Trim()
        if (!$line -or $line.StartsWith('#')) { continue }
        if ($line.StartsWith('!') -or $line.StartsWith('/') -or $line.Contains('\') -or $line.Contains(':') -or $line.Split('/') -contains '..') { throw "${path}:${lineNumber}: use relative paths with /; negation is not supported" }
        $expression = [regex]::Escape($line.TrimEnd('/')).Replace('\*','.*').Replace('\?','.')
        if ($line.EndsWith('/')) { $expression += '(?:/.*)?' }
        [regex]::new('^' + $expression + '$', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }
}

function Test-PartyExportIgnored([string]$Relative, [object[]]$Patterns) {
    if ($Relative -eq 'export_ignore.txt') { return $false }
    $source = $Relative -creplace '\.import$', '' -creplace '\.uid$', ''
    foreach ($pattern in $Patterns) {
        if ($pattern.IsMatch($Relative) -or $pattern.IsMatch($source)) { return $true }
    }
    return $false
}

function Get-PartySourceFiles([string]$Root) {
    $patterns = @(Get-PartyExportRules $Root)
    $package = Test-Path -LiteralPath (Join-Path $Root 'manifest.json') -PathType Leaf
    if ($package -and (Test-PartyExportIgnored 'manifest.json' $patterns)) { throw "Export rules exclude required manifest.json: $Root" }
    Get-PartySourceTree $Root '' $patterns $package
}

function Get-PartySourceTree([string]$Root, [string]$Relative, [object[]]$Patterns, [bool]$Package) {
    $path = if ($Relative) { Join-Path $Root $Relative } else { $Root }
    $directory = Get-Item -LiteralPath $path -Force
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked directory: $path" }
    foreach ($entry in Get-ChildItem -LiteralPath $path -Force | Sort-Object Name) {
        $child = if ($Relative) { $Relative + '/' + $entry.Name } else { $entry.Name }
        if ($entry.Name -in '.git','.godot' -or (Test-PartyExportIgnored $child $Patterns)) { continue }
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked path: $($entry.FullName)" }
        if ($entry.PSIsContainer) {
            if ($Package -and !$Relative -and $entry.Name -eq 'config') { continue }
            if ($Package -and $child -ne 'external' -and !$child.StartsWith('external/') -and (Test-Path -LiteralPath (Join-Path $entry.FullName 'manifest.json') -PathType Leaf)) { continue }
            Get-PartySourceTree $Root $child $Patterns $Package
        } else {
            $entry
        }
    }
}

function Get-PartyCoreFiles([string]$ProjectRoot) {
    foreach ($file in Get-PartySourceFiles (Join-Path $ProjectRoot 'core')) {
        $relative = $file.FullName.Substring($ProjectRoot.Length + 1).Replace('\','/')
        if ($relative -match '^core/(saves/|dev/|config/.*\.(json|cfg|bak|pending)$)' -or $relative -eq 'core/bundled_content.zip') { continue }
        $file
    }
}
