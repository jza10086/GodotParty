param([Parameter(Mandatory=$true)][string]$JobDirectory)
# Explicit cleanup of one completed job. Keep outputs, logs, request and rollback backups.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$root = (Resolve-Path -LiteralPath $JobDirectory).Path.TrimEnd('\','/')
$temporary = [IO.Path]::GetFullPath((Join-Path $projectRoot 'tmp')).TrimEnd('\','/')
if (!$root.StartsWith($temporary + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Only project tmp export jobs can be cleaned' }
if (!(Test-Path -LiteralPath (Join-Path $root 'request.json') -PathType Leaf) -or !(Test-Path -LiteralPath (Join-Path $root 'job-result.json') -PathType Leaf)) { throw 'A completed export job is required' }
$current = $root
while ($current) {
    if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked job path: $current" }
    $parent = Split-Path -Parent $current
    if ($parent -eq $current) { break }
    $current = $parent
}
$lock = [IO.File]::Open((Join-Path $root 'job.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $targets = @('host/source','mobile_content','mobile_host','mobile_payload')
    $contentWork = Join-Path $root 'content_work'
    if (Test-Path -LiteralPath $contentWork) {
        if ((Get-Item -LiteralPath $contentWork -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked content workspace' }
        foreach ($stage in Get-ChildItem -LiteralPath $contentWork -Directory) {
            if ($stage.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked content stage' }
            foreach ($name in @('core','games','.godot')) { $targets += 'content_work/' + $stage.Name + '/' + $name }
        }
    }
    # Preflight the whole deletion set before removing any generated directory.
    $resolved = @()
    foreach ($relative in $targets) {
        $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (!$path.StartsWith($root + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Cleanup path escaped its job' }
        if (!(Test-Path -LiteralPath $path)) { continue }
        $parent = $path
        while ($parent -ne $root) {
            if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked cleanup path: $parent" }
            $parent = Split-Path -Parent $parent
        }
        $entries = @((Get-Item -LiteralPath $path -Force)) + @(Get-ChildItem -LiteralPath $path -Force -Recurse)
        if ($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Linked cleanup tree: $path" }
        $resolved += $path
    }
    foreach ($path in $resolved) { Remove-Item -LiteralPath $path -Recurse -Force }
    Write-Output "EXPORT_WORK_CLEARED $root"
} finally { $lock.Dispose() }
