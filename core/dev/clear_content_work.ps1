param([string]$InstallationRoot = (Join-Path $PSScriptRoot '../..'))
# Offline maintenance only; no resident service and no startup-wide cache deletion.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $InstallationRoot).Path.TrimEnd('\','/')
$temporary = [IO.Path]::GetFullPath((Join-Path $root 'tmp'))
$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^Godot.*\.exe$' -or ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase))
})
if ($running.Count) { throw 'Close all Godot editors and related game instances before clearing content work.' }
function Remove-WorkDirectory([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (!$resolved.StartsWith($temporary + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Outside installation tmp: $resolved" }
    if (!(Test-Path -LiteralPath $resolved)) { return }
    $entries = @((Get-Item -LiteralPath $resolved -Force)) + @(Get-ChildItem -LiteralPath $resolved -Force -Recurse)
    if ($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Linked work directory: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
foreach ($name in @('content_download','content_classes')) {
    Remove-WorkDirectory (Join-Path $temporary $name)
}
# Retain failed build logs and requests while reclaiming reproducible source/import copies.
$build = Join-Path $temporary 'content_build'
if (Test-Path -LiteralPath $build) {
    foreach ($job in Get-ChildItem -LiteralPath $build -Directory) {
        foreach ($name in @('core','games','.godot')) { Remove-WorkDirectory (Join-Path $job.FullName $name) }
    }
}
$distribution = Join-Path $temporary 'content_distribution'
if (Test-Path -LiteralPath $distribution) {
    foreach ($pointer in Get-ChildItem -LiteralPath $distribution -Recurse -File -Filter current.json) {
        $record = Get-Content -LiteralPath $pointer.FullName -Raw | ConvertFrom-Json
        if ($record.generation -notmatch '^[a-f0-9]{32}$') { throw "Invalid cache pointer: $($pointer.FullName)" }
        foreach ($generation in Get-ChildItem -LiteralPath $pointer.DirectoryName -Directory) {
            if ($generation.Name -match '^[a-f0-9]{32}$' -and $generation.Name -ne $record.generation) { Remove-WorkDirectory $generation.FullName }
        }
    }
}
# tmp/local, content_update.zip, install recovery data and package config/ are retained.
