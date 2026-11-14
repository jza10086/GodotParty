# Package-root Git ignore syntax, matching party_export_files.gd.
function ConvertTo-PartyIgnoreRegex([string]$Pattern) {
    $result = [Text.StringBuilder]::new()
    $classes = @{ alnum='a-zA-Z0-9'; alpha='a-zA-Z'; blank=' \t'; cntrl='\x00-\x1f\x7f'; digit='0-9'; graph='!-~'; lower='a-z'; print=' -~'; punct='!-/:-@\[-`{-~'; space='\s'; upper='A-Z'; xdigit='a-fA-F0-9' }
    for ($i=0; $i -lt $Pattern.Length; $i++) {
        $c = $Pattern[$i]
        if ($c -eq '\') {
            $i++
            if ($i -eq $Pattern.Length) { return '(?!)' }
            [void]$result.Append([regex]::Escape([string]$Pattern[$i]))
        } elseif ($c -eq '*') {
            $end = $i
            while ($end -lt $Pattern.Length -and $Pattern[$end] -eq '*') { $end++ }
            if ($end-$i -ge 2 -and ($i -eq 0 -or $Pattern[$i-1] -eq '/') -and ($end -eq $Pattern.Length -or $Pattern[$end] -eq '/')) {
                if ($end -lt $Pattern.Length) { [void]$result.Append('(?:[^/]+/)*'); $end++ } else { [void]$result.Append('.*') }
            } else { [void]$result.Append('[^/]*') }
            $i=$end-1
        } elseif ($c -eq '?') { [void]$result.Append('[^/]')
        } elseif ($c -eq '[') {
            $end=$i+1
            if ($end -lt $Pattern.Length -and $Pattern[$end] -in '!','^') { $end++ }
            if ($end -lt $Pattern.Length -and $Pattern[$end] -eq ']') { $end++ }
            while ($end -lt $Pattern.Length) {
                if ($Pattern.Substring($end).StartsWith('[:')) {
                    $close=$Pattern.IndexOf(':]', $end+2)
                    if ($close -ge 0) { $end=$close+2; continue }
                }
                if ($Pattern[$end] -eq ']') { break }
                $end++
            }
            if ($end -eq $Pattern.Length) { [void]$result.Append('\[') } else {
                $body=$Pattern.Substring($i+1,$end-$i-1)
                if ($body.StartsWith('!')) { $body='^'+$body.Substring(1) }
                foreach ($name in $classes.Keys) { $body=$body.Replace('[:'+$name+':]', $classes[$name]) }
                [void]$result.Append('(?!/)['+$body+']'); $i=$end
            }
        } else { [void]$result.Append([regex]::Escape([string]$c)) }
    }
    $result.ToString()
}

function Get-PartyExportRules([string]$Root) {
    $path = Join-Path $Root 'export_ignore.txt'
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { $path = Join-Path $PSScriptRoot '../content/default_export_ignore.txt' }
    $lineNumber = 0
    foreach ($raw in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        $lineNumber++
        $line = $raw
        while ($line.EndsWith(' ')) {
            $slashes=0; $cursor=$line.Length-2
            while ($cursor -ge 0 -and $line[$cursor] -eq '\') { $slashes++; $cursor-- }
            if ($slashes % 2 -eq 1) { break }
            $line=$line.Substring(0,$line.Length-1)
        }
        if (!$line -or $line.StartsWith('#')) { continue }
        $include=$line.StartsWith('!')
        if ($include) { $line=$line.Substring(1) }
        if (!$line) { continue }
        $directory=$line.EndsWith('/')
        if ($directory) { $line=$line.Substring(0,$line.Length-1) }
        $anchored=$line.Contains('/')
        if ($line.StartsWith('/')) { $line=$line.Substring(1) }
        if (!$line) { continue }
        $prefix=if ($anchored) { '' } else { '(?:.*/)?' }
        try { $regex=[regex]::new('^'+$prefix+(ConvertTo-PartyIgnoreRegex $line)+'$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) }
        catch { throw "${path}:${lineNumber}: invalid ignore pattern: $_" }
        @{ pattern=$regex; include=$include; directory=$directory }
    }
}

function Test-PartyExportIgnored([string]$Relative, [object[]]$Patterns, [bool]$Directory=$false) {
    if ($Relative -ceq 'export_ignore.txt') { return $false }
    $segments=$Relative.Split('/'); $path=''
    for ($i=0; $i -lt $segments.Length; $i++) {
        $path=if ($path) { $path+'/'+$segments[$i] } else { $segments[$i] }
        $folder=$Directory -or $i -lt $segments.Length-1
        $excluded=$false
        foreach ($rule in $Patterns) {
            if ((!$rule.directory -or $folder) -and $rule.pattern.IsMatch($path)) { $excluded=!$rule.include }
        }
        if ($excluded) { return $true }
    }
    $source = $Relative -creplace '\.import$', '' -creplace '\.uid$', ''
    if (!$Directory -and $source -cne $Relative) { return (Test-PartyExportIgnored $source $Patterns) }
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
        if ($entry.Name -in '.git','.godot' -or (Test-PartyExportIgnored $child $Patterns $entry.PSIsContainer)) { continue }
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
