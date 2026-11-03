$Root = Split-Path -Parent $PSScriptRoot
$Bin = Join-Path $Root "native\desktop_bridge\target\release\eli-vr-desktop-bridge.exe"
if (-not (Test-Path $Bin)) { throw "Bridge not built. Run native\desktop_bridge\build-windows.ps1" }

$Fps = if ($env:ELI_VR_CAPTURE_FPS) { $env:ELI_VR_CAPTURE_FPS } else { "15" }
$Width = if ($env:ELI_VR_CAPTURE_WIDTH) { $env:ELI_VR_CAPTURE_WIDTH } else { "0" }
# ELI_VR_DESKTOP_INPUT=0 shows the desktop and never moves the pointer or clicks.
$NoInput = if ($env:ELI_VR_DESKTOP_INPUT -eq "0") { @("--no-input") } else { @() }
& $Bin --fps $Fps --width $Width @NoInput
