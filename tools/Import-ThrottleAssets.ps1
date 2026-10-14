param(
    [Parameter(Mandatory = $true)][string]$ExportRoot,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $scriptDirectory '..\assets\throttle' }
$assetRoot = (Resolve-Path -LiteralPath $ExportRoot).Path
$textureRoot = Join-Path $assetRoot 'Texture2D'
$spriteRoot = Join-Path $assetRoot 'Sprite'
$prefabPath = Join-Path $assetRoot 'group_throttle.prefab'
$names = @(
    'Throttle-BG.png', 'Throttle-BG-Border.png', 'Throttle-BG-Bracket.png',
    'Throttle-ELE-Bars.png', 'Throttle-MSK-Bars 1.png', 'Throttle-MSK-Radial.png',
    'Throttle-ELE-Handle.png', 'Throttle-Handle-ELE.png'
)
$roles = @{
    'Throttle-BG.png' = 'Background'; 'Throttle-BG-Border.png' = 'Border'; 'Throttle-BG-Bracket.png' = 'Bracket'
    'Throttle-ELE-Bars.png' = 'Bars'; 'Throttle-MSK-Bars 1.png' = 'BarsMask'; 'Throttle-MSK-Radial.png' = 'RadialMask'
    'Throttle-ELE-Handle.png' = 'Handle'; 'Throttle-Handle-ELE.png' = 'AlternateHandle'
}
$expectedDimensions = @{
    'Throttle-BG.png' = '170x580'; 'Throttle-BG-Border.png' = '170x580'; 'Throttle-BG-Bracket.png' = '170x580'
    'Throttle-ELE-Bars.png' = '170x580'; 'Throttle-MSK-Bars 1.png' = '170x580'; 'Throttle-MSK-Radial.png' = '832x832'
    'Throttle-ELE-Handle.png' = '130x68'; 'Throttle-Handle-ELE.png' = '100x70'
}
foreach ($required in @($textureRoot, $spriteRoot, $prefabPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "AssetRipper export is missing $required" }
}
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$destination = (Resolve-Path -LiteralPath $OutputDirectory).Path
$textureManifest = @()
foreach ($name in $names) {
    $source = Join-Path $textureRoot $name
    if (-not (Test-Path -LiteralPath $source)) { throw "Required throttle texture not found: $source" }
    $bytes = [IO.File]::ReadAllBytes($source)
    if ($bytes.Length -lt 24 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) { throw "Invalid PNG: $source" }
    $w = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $h = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    if ($w -le 0 -or $h -le 0) { throw "Invalid PNG dimensions: $source" }
    if ("${w}x${h}" -ne $expectedDimensions[$name]) { throw "Unexpected dimensions for ${name}: ${w}x${h}, expected $($expectedDimensions[$name])" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $destination $name) -Force
    $textureManifest += [ordered]@{ name = $name; role = $roles[$name]; width = $w; height = $h; source = "Texture2D/$name" }
}
& (Join-Path $scriptDirectory 'Generate-ThrottleFill.ps1') -AssetDirectory $destination
$textureManifest += [ordered]@{ name = 'Throttle-ELE-Fill.png'; role = 'Fill'; width = 170; height = 580; source = 'derived from Throttle-MSK-Bars 1 and Throttle-MSK-Radial with bilinear radial sampling' }

# ELE-percent is a TMP '%' glyph, not a PNG sprite. Extract only that glyph
# from its original font atlas so the installed mod remains self-contained.
$fontName = 'sbliquid-open1 SDF'
$fontPath = Join-Path $assetRoot "MonoBehaviour\$fontName.asset"
$atlasName = "$fontName Atlas.png"
$atlasPath = Join-Path $textureRoot $atlasName
if (-not (Test-Path -LiteralPath $fontPath) -or -not (Test-Path -LiteralPath $atlasPath)) {
    throw "Missing KSP2 percentage font or atlas: $fontName"
}
$fontYaml = Get-Content -LiteralPath $fontPath -Raw
$glyphIndexMatch = [regex]::Match($fontYaml, 'm_Unicode: 37\s+m_GlyphIndex: (\d+)')
if (-not $glyphIndexMatch.Success) { throw 'The percentage glyph is absent from the source font.' }
$glyphIndex = $glyphIndexMatch.Groups[1].Value
$glyphMatch = [regex]::Match($fontYaml, "(?ms)^  - m_Index: $glyphIndex\r?\n.*?m_GlyphRect:\s+m_X: (\d+)\s+m_Y: (\d+)\s+m_Width: (\d+)\s+m_Height: (\d+)")
if (-not $glyphMatch.Success) { throw 'The percentage glyph rectangle is absent from the source font.' }
$glyphX = [int]$glyphMatch.Groups[1].Value; $glyphY = [int]$glyphMatch.Groups[2].Value
$glyphWidth = [int]$glyphMatch.Groups[3].Value; $glyphHeight = [int]$glyphMatch.Groups[4].Value
Add-Type -AssemblyName System.Drawing
$atlas = [Drawing.Bitmap]::new($atlasPath)
try {
    $glyphTop = $atlas.Height - $glyphY - $glyphHeight
    if ($glyphX -lt 0 -or $glyphTop -lt 0 -or $glyphX + $glyphWidth -gt $atlas.Width -or $glyphTop + $glyphHeight -gt $atlas.Height) {
        throw 'Percentage glyph is outside its atlas.'
    }
    $glyph = [Drawing.Bitmap]::new($glyphWidth, $glyphHeight, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        for ($gy = 0; $gy -lt $glyphHeight; $gy++) {
            for ($gx = 0; $gx -lt $glyphWidth; $gx++) {
                $distance = $atlas.GetPixel($glyphX + $gx, $glyphTop + $gy).A
                $coverage = [int][Math]::Round([Math]::Min(1.0, [Math]::Max(0.0, ($distance - 79.0) / 97.0)) * 255.0)
                $glyph.SetPixel($gx, $gy, [Drawing.Color]::FromArgb($coverage, 255, 255, 255))
            }
        }
        $glyph.Save((Join-Path $destination 'Throttle-ELE-PercentGlyph.png'), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $glyph.Dispose() }
} finally { $atlas.Dispose() }
$textureManifest += [ordered]@{ name = 'Throttle-ELE-PercentGlyph.png'; role = 'PercentGlyph'; width = $glyphWidth; height = $glyphHeight; source = "TMP font $fontName, Unicode 37, atlas rectangle $glyphX,$glyphY,$glyphWidth,$glyphHeight" }

$spriteGuids = @{}
Get-ChildItem -LiteralPath $spriteRoot -Filter '*.asset' | ForEach-Object {
    $yaml = Get-Content -LiteralPath $_.FullName -Raw
    if ($yaml -notmatch 'm_Name: (Throttle-[^\r\n]+)') { return }
    $metaPath = "$($_.FullName).meta"
    if (-not (Test-Path -LiteralPath $metaPath)) { throw "Sprite metadata is missing: $metaPath" }
    $assetGuid = [regex]::Match((Get-Content -LiteralPath $metaPath -Raw), 'guid: ([0-9a-f]{32})').Groups[1].Value
    if (-not $assetGuid) { throw "Sprite GUID is missing: $metaPath" }
    $name = [regex]::Match($yaml, 'm_Name: ([^\r\n]+)').Groups[1].Value
    $textureGuid = [regex]::Match($yaml, 'm_RD:\s+serializedVersion: 3\s+texture: \{fileID: 2800000, guid: ([0-9a-f]{32})').Groups[1].Value
    $rectText = [regex]::Match($yaml, '(?s)m_Rect:\s*(.*?)(?=\s+m_Offset:)').Groups[1].Value
    $rect = [ordered]@{}
    foreach ($field in @('x', 'y', 'width', 'height')) { $rect[$field] = [double][regex]::Match($rectText, "${field}: ([^\s]+)").Groups[1].Value }
    $spriteGuids[$assetGuid] = [ordered]@{
        name = $name; file = $_.Name; texture = "$name.png"; textureGuid = $textureGuid
        rect = $rect
        offset = [regex]::Match($yaml, 'm_Offset: \{[^}]+\}').Value
        pivot = [regex]::Match($yaml, 'm_Pivot: \{[^}]+\}').Value
        pixelsPerUnit = [regex]::Match($yaml, 'm_PixelsToUnits: [^\r\n]+').Value
    }
}

$prefab = Get-Content -LiteralPath $prefabPath -Raw
$blocks = [regex]::Split($prefab, '(?m)^--- ')
$objectNames = @{}
$transforms = @{}
foreach ($block in $blocks) {
    $objectId = [regex]::Match($block, '^!u!1 &(\d+)')
    $objectNameMatch = [regex]::Match($block, 'm_Name: ([^\r\n]+)')
    if ($objectId.Success -and $objectNameMatch.Success) { $objectNames[$objectId.Groups[1].Value] = $objectNameMatch.Groups[1].Value }
    if ($block -match '^!u!224 &' -and $block -match 'm_GameObject: \{fileID: (\d+)') {
        $goId = $Matches[1]
        $transforms[$goId] = [ordered]@{
            object = $objectNames[$goId]
            rotation = [regex]::Match($block, 'm_LocalRotation: \{[^}]+\}').Value
            scale = [regex]::Match($block, 'm_LocalScale: \{[^}]+\}').Value
            anchorMin = [regex]::Match($block, 'm_AnchorMin: \{[^}]+\}').Value
            anchorMax = [regex]::Match($block, 'm_AnchorMax: \{[^}]+\}').Value
            anchoredPosition = [regex]::Match($block, 'm_AnchoredPosition: \{[^}]+\}').Value
            size = [regex]::Match($block, 'm_SizeDelta: \{[^}]+\}').Value
            pivot = [regex]::Match($block, 'm_Pivot: \{[^}]+\}').Value
        }
    }
}
$entries = @()
foreach ($block in $blocks) {
    $goMatch = [regex]::Match($block, 'm_GameObject: \{fileID: (\d+)')
    if (-not $goMatch.Success) { continue }
    $goId = $goMatch.Groups[1].Value
    $objectName = $objectNames[$goId]
    if ($objectName -notin @('BG-Throttle-Ticks', 'ELE-BG', 'ELE-Border', 'ELE-Bracket', 'MSK-progress bar', 'MSK-circle', 'BG-Throttle-Handle', 'BG-Throttle-Handle (1)')) { continue }
    $guidMatch = [regex]::Match($block, 'm_Sprite: \{fileID: 21300000, guid: ([0-9a-f]{32})')
    if (-not $guidMatch.Success) { continue }
    $entries += [ordered]@{
        object = $objectName
        spriteGuid = if ($guidMatch.Success) { $guidMatch.Groups[1].Value } else { $null }
        sprite = $spriteGuids[$guidMatch.Groups[1].Value]
        tint = [regex]::Match($block, 'm_Color: \{[^}]+\}').Value
        imageType = [regex]::Match($block, 'm_Type: \d+').Value
        fillAmount = [regex]::Match($block, 'm_FillAmount: [^\r\n]+').Value
        transform = $transforms[$goId]
    }
}
$handleHierarchy = @()
foreach ($handleName in @('Binding - Throttle Slider', 'SliderHandleYPosition', 'Binding - HandleXPosition', 'HandleXPositionNodes', 'SliderHandle', 'handle_hitarea', 'BG-Throttle-Handle')) {
    $handleTransform = $transforms.Values | Where-Object { $_.object -eq $handleName } | Select-Object -First 1
    if ($null -ne $handleTransform) { $handleHierarchy += $handleTransform }
}
$manifest = [ordered]@{
    sourcePrefab = 'group_throttle.prefab'
    logicalSize = @{ width = 85; height = 290 }
    rootLayout = @{ position = '90,141.2'; size = '147.7,282.5'; pivot = '0.5,0.5'; anchor = 'bottom-left'; hierarchyId = '22'; prefab = 'group_throttle' }
    widgetLayout = @{ position = '-9.849976,-4.25'; size = '85,290'; pivot = '0,0'; hierarchy = 'group_throttle/Container/widget_slider_throttle_vertical/Bound UI - Throttle' }
    layerOrder = @('BG-Throttle-Ticks', 'ELE-BG', 'ELE-Border', 'ELE-Bracket', 'MSK-progress bar', 'MSK-circle', 'ELE-percent', 'BG-Throttle-Handle', 'BG-Throttle-Handle (1)')
    serializedFill = @{ object = 'MSK-circle'; quaternion = @{ z = -0.37460646; w = 0.9271839 }; rotationDegrees = -44; color = '#00FF66'; normalizedFill = 'throttle / 4'; method = 'Radial360'; clockwise = $true; origin = 'Bottom'; size = '416,416'; centerInWidgetScreenCoordinates = '204.5,145'; mask = 'MSK-progress bar'; showMaskGraphic = $false; maskOperation = 'stencil alpha test, not alpha multiplication' }
    handlePath = @(
        @{ throttle = 0.0; x = 10; y = 21; rotation = -140 }, @{ throttle = 0.1; x = -2; y = 8; rotation = -146 },
        @{ throttle = 0.2; x = -16; y = 7; rotation = -154 }, @{ throttle = 0.3; x = -26; y = 6; rotation = -165 },
        @{ throttle = 0.4; x = -32; y = 5; rotation = -173 }, @{ throttle = 0.5; x = -33; y = 0; rotation = -180 },
        @{ throttle = 0.6; x = -32; y = -5; rotation = -187 }, @{ throttle = 0.7; x = -26; y = -6; rotation = -195 },
        @{ throttle = 0.8; x = -16; y = -7; rotation = -206 }, @{ throttle = 0.9; x = -2; y = -8; rotation = -214 },
        @{ throttle = 1.0; x = 10; y = -21; rotation = -220 }
    )
    handleTransform = @{ rect = @{ width = 65; height = 34; pivot = '0.5,0.5' }; localQuaternion = @{ z = 1; w = 0 }; localRotationDegrees = 180; sprite = 'Throttle-ELE-Handle.png'; spriteRect = 'x=0,y=0.076120496,width=120.92388,height=67.84776'; pixelsPerUnit = 200; effectiveVisualRotation = 'path quaternion plus child 180 degree quaternion' }
    handleHierarchy = $handleHierarchy
    originalUnityRotationCorrection = 'Prefab quaternions are authoritative; Unity Z angles unwrap continuously from -140 through -180 to -220 degrees. Earlier Euler hints with opposite sign are not used.'
    layers = $entries
    textures = $textureManifest
    sprites = $spriteGuids
    inactiveAlternateHandle = @{ sprite = 'Throttle-Handle-ELE.png'; rendered = $false; prefabObject = 'BG-Throttle-Handle (1)' }
    percentGlyph = @{ font = $fontName; unicode = 37; atlas = $atlasName; glyphIndex = [int]$glyphIndex; rectangle = @{ x = $glyphX; y = $glyphY; width = $glyphWidth; height = $glyphHeight }; sdfAlphaTransfer = 'clamp((alpha - 79) / 97, 0, 1)'; tint = '#101114'; logicalSize = '13.22,18.07'; rasterScale = 0.9; displaySize = '11.898,16.263'; approximateLogicalTopLeft = '54.551,253.369'; sourceRectTransform = @{ parent = 'BG-Throttle-Ticks'; anchorMin = '1,0'; anchorMax = '1,0'; anchoredPosition = '-12,16'; sizeDelta = '25,25'; pivot = '1,0'; localRotationDegrees = 0 }; sourceWidgetBounds = @{ topLeft = '48,249'; size = '25,25'; center = '60.5,261.5' } }
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $destination 'throttle-assets.json') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $destination 'throttle-assets.json') -Destination (Join-Path $scriptDirectory '..\docs\throttle-assets.reference.json') -Force
Write-Host "Imported $($names.Count) throttle textures and wrote $destination\throttle-assets.json"
