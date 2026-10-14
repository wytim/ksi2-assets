param([string]$AssetDirectory = (Join-Path $PSScriptRoot '..\assets\throttle'))

$ErrorActionPreference = 'Stop'
$directory = (Resolve-Path -LiteralPath $AssetDirectory).Path
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ThrottleFillBuilder.cs') -Raw) -ReferencedAssemblies 'System.Drawing'
[ThrottleFillBuilder]::Generate(
    (Join-Path $directory 'Throttle-MSK-Bars 1.png'),
    (Join-Path $directory 'Throttle-MSK-Radial.png'),
    (Join-Path $directory 'Throttle-ELE-Fill.png'))
