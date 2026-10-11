$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
cargo build --release
Write-Host "Built target\release\eli-vr-desktop-bridge.exe"
