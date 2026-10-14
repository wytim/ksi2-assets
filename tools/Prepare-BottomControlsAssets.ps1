param(
    [string]$ExportDirectory = (Join-Path $PSScriptRoot '..\..\font-guid-export\ExportedProject\Assets\Texture2D'),
    [string]$Destination = (Join-Path $PSScriptRoot '..\assets\navball')
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$images = @{
    'Button-Digital-Large-Outline-Dot_0.png' = 'Button-Digital-Large-Outline-Dot.png'
    'ICO-Flight-Cluster-ObjectCycle.png' = 'ICO-Flight-Cluster-ObjectCycle.png'
    'ICO-Flight-Cluster-Commnet.png' = 'ICO-Flight-Cluster-Commnet.png'
}
foreach ($sourceName in $images.Keys) {
    $source = Join-Path $ExportDirectory $sourceName
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing local source: $source" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $Destination $images[$sourceName])
}
