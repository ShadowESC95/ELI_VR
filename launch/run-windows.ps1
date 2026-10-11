param(
  [ValidateSet("auto","xr","flat","compat")]
  [string]$Mode = "auto"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = "godot.exe" }
$args = @("--path", $Root)
if ($Mode -eq "xr") { $args += @("--xr-mode","on") }
elseif ($Mode -eq "flat") { $args += @("--xr-mode","off") }
elseif ($Mode -eq "compat") { $args += @("--rendering-method","gl_compatibility") }
& $Godot @args
