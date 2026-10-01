#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
cd "$project_root"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release iOS build/ios/KinuTumble.ipa
python3 ios/native_cloud/patch_export.py
xcodebuild -project build/ios/KinuTumble.xcodeproj -scheme KinuTumble -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/ios/Recovery-DerivedData DEVELOPMENT_TEAM=5976U4WSJN CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
