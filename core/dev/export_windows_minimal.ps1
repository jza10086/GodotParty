param([string]$GodotPath = 'godot')
# The minimal preset uses the same backend and dependency closure as the visual exporter.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp = [guid]::NewGuid().ToString('N')
$job = Join-Path $root ('tmp/exports/minimal_' + $stamp)
$output = Join-Path $root ('tmp/releases/GodotParty-Minimal-Avalon-' + $stamp)
New-Item -ItemType Directory $job | Out-Null
$requestPath = Join-Path $job 'request.json'
@{core=$true; output=$output; packages=@('godot_party_default_maingame_minigame_playlist','godot_party_default_identity_party')} |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $requestPath -Encoding UTF8
& (Join-Path $PSScriptRoot 'export_release.ps1') -RequestPath $requestPath -GodotPath $GodotPath
Compress-Archive -LiteralPath $output -DestinationPath ($output + '.zip')
[pscustomobject]@{ Directory=$output; Archive=($output + '.zip'); BuildRoot=$job }
