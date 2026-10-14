param(
    [Parameter(Mandatory = $true)][string]$ExportedAssets,
    [string]$Destination
)

$ErrorActionPreference = 'Stop'
if (-not $Destination) { $Destination = Join-Path $PSScriptRoot '..\assets\navball' }
$ExportedAssets = (Resolve-Path -LiteralPath $ExportedAssets).Path
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$sprites = @(
    'Flight-Readout-BG',
    'TILE-LCD-10px-11pt',
    'TILE-LCD-10px-14pt',
    'ICO-Tiny-Surface_0',
    'ICO-Tiny-Orbit',
    'ICO-Tiny-Target_0',
    'ICO-Tiny-SeaLevel',
    'ICO-Tiny-Ground'
)
foreach ($name in $sprites) {
    Copy-Item -LiteralPath (Join-Path $ExportedAssets "Texture2D\$name.png") -Destination $Destination -Force
}

Write-Host "Prepared speed readout artwork in $Destination"
