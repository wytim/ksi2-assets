param(
    [Parameter(Mandatory = $true)][string]$OtfPath,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $PSScriptRoot '..\assets\throttle'
}
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$destination = (Resolve-Path -LiteralPath $OutputDirectory).Path
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'HandleFontAtlasBuilder.cs') -Raw) -ReferencedAssemblies 'System.Drawing'
[HandleFontAtlasBuilder]::FromOtf($OtfPath, (Join-Path $destination 'Handle-OTF.png'))
Write-Host "Generated optional handle number atlas in $destination"
