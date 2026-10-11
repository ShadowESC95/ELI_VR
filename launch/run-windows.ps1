param(
  [ValidateSet("auto","xr","flat","compat")]
  [string]$Mode = "auto",
  # Switch the link to a local ELI v3 on for this run.
  [switch]$Eli
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = "godot.exe" }
$GodotArgs = @("--path", $Root)
if ($Mode -eq "xr") { $GodotArgs += @("--xr-mode","on") }
elseif ($Mode -eq "flat") { $GodotArgs += @("--xr-mode","off") }
elseif ($Mode -eq "compat") { $GodotArgs += @("--rendering-method","gl_compatibility") }
if ($Eli) { $GodotArgs += @("--", "--eli-link=on") }
& $Godot @GodotArgs
