#!/bin/bash
# Sign Kinu Tumble's custom Firebase wrapper after rebuilding its XCFramework.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
identity="${1:-Apple Development: Mike Whelan (B4Z9B6V598)}"
framework="$project_dir/addons/GodotApplePluginsFirebase/bin/GodotApplePluginsFirebase.xcframework"
codesign --force --timestamp --sign "$identity" "$framework"
codesign --verify --strict --verbose=2 "$framework"
