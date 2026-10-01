#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
cd "$project_root"
export_preset="iOS"
if [[ "${1:-}" == "production" ]]; then
	export_preset="iOS Production"
fi
# Import newly added catalogue PNGs before exporting; the book loads their imported textures.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "$export_preset" build/ios/KinuTumble.ipa
if [[ "$export_preset" == "iOS" ]] && grep -q "GodotApplePluginsFirebase" build/ios/KinuTumble.xcodeproj/project.pbxproj; then
	print -u2 "Test export unexpectedly links Firebase"
	exit 1
fi
python3 ios/native_cloud/patch_export.py
xcodebuild -project build/ios/KinuTumble.xcodeproj -scheme KinuTumble -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/ios/Recovery-DerivedData DEVELOPMENT_TEAM=5976U4WSJN CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
if [[ "$export_preset" == "iOS" ]] && [[ -e build/ios/Recovery-DerivedData/Build/Products/Release-iphoneos/KinuTumble.app/Frameworks/GodotApplePluginsFirebase.framework ]]; then
	print -u2 "Test app unexpectedly embeds Firebase"
	exit 1
fi
