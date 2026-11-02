#Requires -Version 5.1
# Delegate engine selection, ports and extra arguments to shared configuration.
[CmdletBinding()]
param([switch]$DryRun, [switch]$Interactive)
& 'F:\GodotProjects\GodotTools\editor_launcher\launch.ps1' -Project godot_party -Mode Editor -DryRun:$DryRun -Interactive:$Interactive
exit $LASTEXITCODE
