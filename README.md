# KSI2 asset package

This repository contains the asset-only KSA mod. Its `mod.toml`
registers `KSI2AssetPack.xml`; the XML gives KSA the texture and sound IDs
used by KSI2. KSI2's code asks KSA for those IDs and does not need this
folder's path.

For a manual install, copy `mod.toml`, `KSI2AssetPack.xml`, and the complete
`assets/` directory to
`Documents/My Games/Kitten Space Agency/mods/ksi2-assets/`. Enable both
`ksi2-assets` and `KSI2` in the active KSA `manifest.toml`. A Borea listing can
declare this package as a required dependency of KSI2 when the packages are
ready for release.

The package holds only the current artwork and sounds selected for KSI2. The
LCD font remains in KSI2. Do not treat the presence of files in this
repository as permission to publish them.
