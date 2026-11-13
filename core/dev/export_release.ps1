param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# A private build finishes before touching the installation. Formal external payload joins rollback.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$platform = if ($request.platform) { [string]$request.platform } else { 'Windows' }
if ($platform -notin 'Windows','Android') { throw 'Unsupported export platform' }
if ($request.core -isnot [bool] -or $request.packages -isnot [Array] -or (!$request.core -and $request.packages.Count -eq 0)) { throw 'Select core or at least one package' }
if (![IO.Path]::IsPathRooted($request.output)) { throw 'Export directory must be absolute' }
$output = [IO.Path]::GetFullPath($request.output).TrimEnd('\','/')
$projectPath = $projectRoot.TrimEnd('\','/')
$releasePrefix = Join-Path $projectRoot 'tmp/releases'
$testPrefix = Join-Path $projectRoot 'tmp/test'
if ($output -eq $projectPath -or $projectPath.StartsWith($output + '\',[StringComparison]::OrdinalIgnoreCase) -or ($output.StartsWith($projectPath + '\',[StringComparison]::OrdinalIgnoreCase) -and !$output.StartsWith($releasePrefix + '\',[StringComparison]::OrdinalIgnoreCase) -and !$output.StartsWith($testPrefix + '\',[StringComparison]::OrdinalIgnoreCase))) { throw 'Choose a directory outside the development project, or under tmp/releases/ or tmp/test/' }
$buildRoot = Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$stage = Join-Path $buildRoot 'build'
$statusPath = Join-Path $buildRoot 'status.txt'
$utf8 = New-Object Text.UTF8Encoding($false)
function Status([string]$message) { [IO.File]::WriteAllText($statusPath,$message,$utf8) }
function Check-Target([string]$path) {
    $current = $path
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Output contains a link: $current" }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
Check-Target $output
if (!(Test-Path -LiteralPath $output)) { New-Item -ItemType Directory -Path $output | Out-Null }
$lockPath = Join-Path $output '.godotparty-export.lock'
$lock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    if(Test-Path -LiteralPath $stage) { throw "Build already exists: $stage" }
    New-Item -ItemType Directory -Path $stage | Out-Null
    Status 'Checking system Godot'
    $version = (& $GodotPath --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or !$version) { throw 'Cannot run system Godot' }
    if ($platform -eq 'Android') {
        & (Join-Path $PSScriptRoot 'export_android.ps1') -GodotPath $GodotPath -RequestPath $RequestPath
    } elseif ($request.core) {
        Status 'Exporting Windows core'
        & (Join-Path $PSScriptRoot 'export_windows_host.ps1') -GodotPath $GodotPath -BuildRoot (Join-Path $buildRoot 'host') -OutputDirectory $stage | Out-Null
    }
    if ($platform -eq 'Windows' -and $request.packages.Count -gt 0) {
        Status 'Exporting content and dependencies'
        $log = Join-Path $buildRoot 'content.log'
        & $GodotPath --headless --path $projectRoot --log-file (Join-Path $buildRoot 'content-engine.log') --script res://core/dev/export_content.gd -- "--output=$stage" "--request=$RequestPath" *> $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:') -or !(Select-String -LiteralPath $log -Pattern 'CONTENT_EXPORT_PASS')) { throw "Content export failed. See $log" }
    }
    Status 'Publishing completed build'
    # Preflight every output, and save overwritten build artifacts for rollback.
    $writes = @()
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
        $relative = $file.FullName.Substring($stage.Length + 1)
        $target = Join-Path $output $relative
        Check-Target $target
        if (Test-Path -LiteralPath $target -PathType Container) { throw "File conflicts with directory: $target" }
        $packageArtifact = $relative -match '^(protocols|maingame|minigame|assets)\\[^\\]+\\(avatars\\[^\\]+\\)?content\.pck(\.json)?$'
        $formalExternal = $relative -match '^(protocols|maingame|minigame|assets)\\[^\\]+\\(avatars\\[^\\]+\\)?external\\'
        $replace = $relative -in 'GodotParty.exe','GodotParty.apk','GodotParty-content-android.zip' -or $packageArtifact -or $formalExternal -or $relative.StartsWith('core\notices\')
        if ((Test-Path -LiteralPath $target) -and !$replace) { continue }
        $backup = Join-Path (Join-Path $buildRoot 'previous') $relative
        $existed = Test-Path -LiteralPath $target
        if ($existed) {
            New-Item -ItemType Directory (Split-Path $backup) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $backup
        }
        $writes += [pscustomobject]@{ Source=$file.FullName; Target=$target; Backup=$backup; Existed=$existed; Delete=$false }
    }
    foreach ($descriptor in Get-ChildItem -LiteralPath $stage -Recurse -Filter 'content.pck.json' -File) {
        $relative = $descriptor.DirectoryName.Substring($stage.Length + 1)
        $targetRoot = Join-Path $output $relative
        $previousDescriptor = Join-Path $targetRoot 'content.pck.json'
        if (!(Test-Path -LiteralPath $previousDescriptor -PathType Leaf)) { continue }
        $previous = Get-Content -LiteralPath $previousDescriptor -Raw -Encoding UTF8 | ConvertFrom-Json
        $next = Get-Content -LiteralPath $descriptor.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($name in $previous.external_files) {
            if ($name -in $next.external_files) { continue }
            if ($name -isnot [string] -or !$name.StartsWith('external/') -or $name.Contains('\') -or $name.Split('/') -contains '..') { throw 'Invalid retired external path' }
            $target = [IO.Path]::GetFullPath((Join-Path $targetRoot $name))
            $externalRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'external')).TrimEnd('\') + '\'
            if (!$target.StartsWith($externalRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Retired payload escaped its package' }
            Check-Target $target
            if (!(Test-Path -LiteralPath $target -PathType Leaf)) { continue }
            $backup = Join-Path (Join-Path (Join-Path $buildRoot 'previous') $relative) $name
            New-Item -ItemType Directory (Split-Path $backup) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $backup
            $writes += [pscustomobject]@{ Source=$null; Target=$target; Backup=$backup; Existed=$true; Delete=$true }
        }
    }
    foreach ($dir in Get-ChildItem -LiteralPath $stage -Recurse -Directory) {
        $target = Join-Path $output $dir.FullName.Substring($stage.Length + 1)
        Check-Target $target
        New-Item -ItemType Directory $target -Force | Out-Null
    }
    $applied = [Collections.Generic.List[object]]::new()
    try {
        foreach ($write in $writes) {
            $applied.Add($write)
            if ($write.Delete) { Remove-Item -LiteralPath $write.Target }
            else { Copy-Item -LiteralPath $write.Source -Destination $write.Target -Force }
        }
    } catch {
        for ($i=$applied.Count-1; $i -ge 0; $i--) {
            $write=$applied[$i]
            if ($write.Existed) { Copy-Item -LiteralPath $write.Backup -Destination $write.Target -Force }
            elseif (Test-Path -LiteralPath $write.Target) { Remove-Item -LiteralPath $write.Target }
        }
        throw
    }
    Status "Export complete: $output"
    Write-Output "EXPORT_RELEASE_PASS $output ($version)"
} catch {
    Status ("Export failed: " + $_.Exception.Message)
    throw
} finally {
    $lock.Dispose()
    # Keep the zero-byte lock inode so two exporters cannot race deletion/recreation.
}
