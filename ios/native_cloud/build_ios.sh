#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
cd "$project_root"
# Release builds (the default) run Firebase. `debug` makes a debug export, which never configures it.
export_preset="iOS"
export_mode="--export-release"
if [[ "${1:-}" == "debug" ]]; then
	export_mode="--export-debug"
fi
# Import newly added catalogue PNGs before exporting; the book loads their imported textures.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . $export_mode "$export_preset" build/ios/KinuTumble.ipa
if [[ "$export_mode" == "--export-release" ]] && ! grep -q "GodotApplePluginsFirebase" build/ios/KinuTumble.xcodeproj/project.pbxproj; then
	print -u2 "Release export is missing Firebase"
	exit 1
fi
python3 ios/native_cloud/patch_export.py
xcodebuild -project build/ios/KinuTumble.xcodeproj -scheme KinuTumble -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/ios/Recovery-DerivedData DEVELOPMENT_TEAM=5976U4WSJN CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
