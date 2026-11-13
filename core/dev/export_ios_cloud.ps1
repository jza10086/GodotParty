param([Parameter(Mandatory=$true)][string]$RequestPath, [string]$GodotPath = 'godot')
# Windows editor bridge: dispatch an immutable pushed revision and download its artifacts.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$job = Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$utf8 = New-Object Text.UTF8Encoding($false)
function Status([string]$message) { [IO.File]::WriteAllText((Join-Path $job 'status.txt'),$message,$utf8) }
function Native([string]$program, [string[]]$arguments) {
    $result = & {
        $ErrorActionPreference = 'Continue'
        $lines = & $program @arguments 2>&1 | ForEach-Object { $_.ToString() }
        $code = $LASTEXITCODE
        [pscustomobject]@{Code=$code; Text=($lines -join "`n")}
    }
    if ($result.Code -ne 0) { throw "$program failed ($($result.Code)): $($result.Text)" }
    return $result.Text
}
function Check-Target([string]$path) {
    while ($path) {
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Output contains a link: $path" }
        $parent = Split-Path -Parent $path
        if ($parent -eq $path) { break }
        $path = $parent
    }
}
if ($request.platform -ne 'iOS' -or $request.core -isnot [bool] -or $request.packages -isnot [Array] -or (!$request.core -and !$request.packages.Count)) { throw 'Invalid iOS export request' }
foreach ($id in $request.packages) { if ($id -isnot [string] -or $id -cnotmatch '^[a-z0-9_]+$') { throw 'Invalid package ID' } }
if (![IO.Path]::IsPathRooted($request.output)) { throw 'Export directory must be absolute' }
$output = [IO.Path]::GetFullPath($request.output).TrimEnd('\','/')
if ($output -eq $job -or $output.StartsWith($job + '\',[StringComparison]::OrdinalIgnoreCase) -or $job.StartsWith($output + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output and build job directories must not overlap' }
$root = $projectRoot.TrimEnd('\','/')
$inside = $output.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase)
$temporary = $output.StartsWith((Join-Path $root 'tmp/releases/').Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith((Join-Path $root 'tmp/test/').Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)
if ($output -eq $root -or $root.StartsWith($output + '\',[StringComparison]::OrdinalIgnoreCase) -or ($inside -and !$temporary)) { throw 'Choose a directory outside the project, or under tmp/releases/ or tmp/test/' }
Check-Target $output
Status 'Checking GitHub login and pushed revision'
$null = Native 'gh' @('auth','status','--hostname','github.com')
$remote = (Native 'git' @('-C',$projectRoot,'remote','get-url','origin')).Trim()
if ($remote -notmatch '^(?:git@github\.com:|https://github\.com/)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?$') { throw 'origin must be a GitHub repository' }
$repo = $Matches[1]
$revision = (Native 'git' @('-C',$projectRoot,'rev-parse','HEAD')).Trim()
if ($revision -notmatch '^[0-9a-f]{40}$') { throw 'Cannot resolve current commit' }
$null = Native 'gh' @('api',"repos/$repo/commits/$revision",'--jq','.sha')
$version = (Native $GodotPath @('--version')).Trim()
if ($version -notmatch '^(4\.\d+(?:\.\d+)?)\.stable(?:\.|$)') { throw "Cloud export requires a stable Godot 4 release: $version" }
$engineVersion = $Matches[1]
$notice = "Commit: $revision`nGodot: $engineVersion`nLocal uncommitted changes (including submodules) are NOT included."
$requestId = [guid]::NewGuid().ToString('N')
$body = @{ref='main'; inputs=@{revision=$revision; request_id=$requestId; godot_version=$engineVersion; core=$request.core.ToString().ToLowerInvariant(); packages=(ConvertTo-Json -InputObject @($request.packages) -Compress)}}
$dispatchPath = Join-Path $job 'dispatch.json'
[IO.File]::WriteAllText($dispatchPath,($body | ConvertTo-Json -Depth 6),$utf8)
Status "Dispatching GitHub iOS build`n$notice"
$null = Native 'gh' @('api',"repos/$repo/actions/workflows/build-ios.yml/dispatches",'--method','POST','--input',$dispatchPath)
$deadline = [DateTime]::UtcNow.AddMinutes(50)
$discoveryDeadline = [DateTime]::UtcNow.AddMinutes(3)
$runId = $null
$url = ''
while ([DateTime]::UtcNow -lt $deadline) {
    if (!$runId) {
        $runs = Native 'gh' @('run','list','--repo',$repo,'--workflow','build-ios.yml','--event','workflow_dispatch','--limit','50','--json','databaseId,displayTitle,url') | ConvertFrom-Json
        $matchesRun = @($runs | Where-Object { $_.displayTitle -eq "iOS $requestId" })
        if ($matchesRun.Count -gt 1) { throw 'More than one workflow matched this request' }
        if ($matchesRun.Count -eq 1) { $runId = [string]$matchesRun[0].databaseId; $url = $matchesRun[0].url }
        elseif ([DateTime]::UtcNow -gt $discoveryDeadline) { throw "Dispatched workflow not found. Inspect https://github.com/$repo/actions before trying again. Request: $requestId" }
    }
    if ($runId) {
        $run = Native 'gh' @('run','view',$runId,'--repo',$repo,'--json','status,conclusion,jobs') | ConvertFrom-Json
        $steps = @($run.jobs | ForEach-Object { $_.steps } | Where-Object { $_.status -eq 'in_progress' } | ForEach-Object { $_.name })
        Status "$($run.status): $($steps -join ', ')`n$url`n$notice"
        [IO.File]::WriteAllText((Join-Path $job 'run.json'),(@{id=$runId;url=$url;revision=$revision;request=$requestId} | ConvertTo-Json),$utf8)
        if ($run.status -eq 'completed') {
            if ($run.conclusion -ne 'success') { throw "iOS build ended: $($run.conclusion). Logs: $url" }
            break
        }
    }
    Start-Sleep -Seconds 10
}
if (!$runId -or $run.status -ne 'completed') { throw "Timed out waiting for iOS build; it may still be running: $url" }
$download = Join-Path $job 'download'
Status "Downloading completed IPA/content`n$url`n$notice"
$null = Native 'gh' @('run','download',$runId,'--repo',$repo,'--name','GodotParty-iOS-SideStore','--dir',$download)
$metadata = Get-Content -LiteralPath (Join-Path $download 'build-info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($metadata.revision -ne $revision -or $metadata.core -ne $request.core) { throw 'Downloaded build does not match this request' }
$expected = @('GodotParty-content-ios.zip','build-info.json','INSTALL.txt')
if ($request.core) { $expected += 'GodotParty-iOS-SideStore.ipa' }
foreach ($name in $expected) { if (!(Test-Path -LiteralPath (Join-Path $download $name) -PathType Leaf)) { throw "Artifact missing: $name" } }
# Each build gets a fresh directory, so unrelated exports and player files are never overwritten.
$target = Join-Path $output ("ios-" + $revision.Substring(0,12) + "-" + $runId)
Check-Target $target
if (Test-Path -LiteralPath $target) { throw "Output already exists: $target" }
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in $expected) { Copy-Item -LiteralPath (Join-Path $download $name) -Destination (Join-Path $target $name) }
[IO.File]::WriteAllText((Join-Path $job 'result.txt'),$target,$utf8)
Status "Export complete: $target`n$url`n$notice"
Write-Output "EXPORT_RELEASE_PASS $target"
