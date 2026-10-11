$Root = Split-Path -Parent $PSScriptRoot
$Bin = Join-Path $Root "native\desktop_bridge\target\release\eli-vr-desktop-bridge.exe"
if (-not (Test-Path $Bin)) { throw "Bridge not built. Run native\desktop_bridge\build-windows.ps1" }

$Fps = if ($env:ELI_VR_CAPTURE_FPS) { $env:ELI_VR_CAPTURE_FPS } else { "15" }
$Width = if ($env:ELI_VR_CAPTURE_WIDTH) { $env:ELI_VR_CAPTURE_WIDTH } else { "1600" }
$Quality = if ($env:ELI_VR_CAPTURE_QUALITY) { $env:ELI_VR_CAPTURE_QUALITY } else { "72" }
& $Bin --fps $Fps --width $Width --quality $Quality
