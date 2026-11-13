# Shared source boundary for Windows, Android and iOS staging.
# Keep authoring visible in Godot; exclude it only from publication. Preserve import settings and UIDs.
function Get-PartySourceFiles([string]$Root) {
    $directory = Get-Item -LiteralPath $Root -Force
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot export linked directory: $Root" }
    if ($directory.Name -eq 'authoring' -or (Test-Path -LiteralPath (Join-Path $Root '.gdignore'))) { return }
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
