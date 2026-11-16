param([string]$GodotPath = 'godot')
# The preset explicitly includes its required content, just like manual selections in the exporter.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp = [guid]::NewGuid().ToString('N')
$job = Join-Path $root ('tmp/exports/minimal_' + $stamp)
$output = Join-Path $root ('tmp/releases/GodotParty-Minimal-Avalon-' + $stamp)
New-Item -ItemType Directory $job | Out-Null
$requestPath = Join-Path $job 'request.json'
@{core=$true; output=$output; packages=@('GP_minigame_playlist','GP_avalon','GP_default_protocol','GP_default_ui','GP_default_avatars','GP_default_avatars_2d')} |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $requestPath -Encoding UTF8
& powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'export_job.ps1') -RequestPath $requestPath -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) { throw "Minimal export failed. See $job/export.log" }
Compress-Archive -LiteralPath $output -DestinationPath ($output + '.zip')
[pscustomobject]@{ Directory=$output; Archive=($output + '.zip'); BuildRoot=$job }
