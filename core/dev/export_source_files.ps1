# Shared Windows/Android source boundary. iOS consumes the Android staging output.
# Keep import settings and UIDs; never copy an ignored subtree without its marker.
function Get-PartySourceFiles([string]$Root) {
    $directory = Get-Item -LiteralPath $Root -Force
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked directory: $Root" }
    if (Test-Path -LiteralPath (Join-Path $Root '.gdignore')) { return }
    $package = Test-Path -LiteralPath (Join-Path $Root 'manifest.json')
    $protocol = $package -and ((Get-Content -LiteralPath (Join-Path $Root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json).kind -eq 'protocols')
    foreach ($entry in Get-ChildItem -LiteralPath $Root -Force | Sort-Object Name) {
        if ($entry.Name.StartsWith('.')) { continue }
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked path: $($entry.FullName)" }
        if ($entry.PSIsContainer) {
            if (($package -and $entry.Name -eq 'config') -or ($protocol -and $entry.Name -eq 'avatars')) { continue }
            Get-PartySourceFiles $entry.FullName
        } elseif (!$entry.Name.Contains('~') -and $entry.Extension -notin '.tmp','.bak','.pending') {
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
