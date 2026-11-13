param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# Detached editor job. Owns its lock, persistent log and completion result, not the editor lifetime.
$ErrorActionPreference = 'Stop'
$job = Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$utf8 = New-Object Text.UTF8Encoding($false)
$lock = [IO.File]::Open((Join-Path $job 'job.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
if (Test-Path -LiteralPath (Join-Path $job 'job-result.json')) {
    $lock.Dispose()
    throw 'Use a new request directory for each export'
}
$exitCode = 1
try {
    $request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $backend = if ($request.platform -eq 'iOS') { 'export_ios_cloud.ps1' } else { 'export_release.ps1' }
    & (Join-Path $PSScriptRoot $backend) -RequestPath $RequestPath -GodotPath $GodotPath *> (Join-Path $job 'export.log')
    $output = if ($request.platform -eq 'iOS') { Get-Content -LiteralPath (Join-Path $job 'result.txt') -Raw -Encoding UTF8 } else { $request.output }
    $result = @{ok=$true; output=$output; error=''}
    $exitCode = 0
} catch {
    $message = $_.Exception.Message
    ($_ | Out-String) + $_.ScriptStackTrace | Add-Content -LiteralPath (Join-Path $job 'export.log') -Encoding UTF8
    [IO.File]::WriteAllText((Join-Path $job 'status.txt'),("Export failed: " + $message),$utf8)
    $result = @{ok=$false; output=''; error=$message}
} finally {
    [IO.File]::WriteAllText((Join-Path $job 'job-result.json'),($result | ConvertTo-Json),$utf8)
    $lock.Dispose()
}
exit $exitCode
