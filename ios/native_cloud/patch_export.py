#!/usr/bin/env python3
"""Add the native iCloud key-value bridge to a freshly exported Godot iOS project."""

from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
export = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/ios"
swift = export / "KinuTumble/dummy.swift"
cpp = export / "KinuTumble/dummy.cpp"
entitlements = export / "KinuTumble/KinuTumble.entitlements"
bridge = (Path(__file__).parent / "CloudBridge.swift").read_text()

if "com.apple.developer.ubiquity-kvstore-identifier" not in entitlements.read_text():
    raise SystemExit("Export is missing the iCloud key-value entitlement")

swift_text = swift.read_text()
if "kinu_cloud_bridge_start" not in swift_text:
    swift.write_text(swift_text + "\n" + bridge)

cpp_text = cpp.read_text()
if "kinu_cloud_bridge_start" not in cpp_text:
    cpp_text = cpp_text.replace(
        "// Use Plugins\n",
        '// Use Plugins\nextern "C" void kinu_cloud_bridge_start();\n',
        1,
    ).replace(
        "void godot_apple_embedded_plugins_initialize() {\n",
        "void godot_apple_embedded_plugins_initialize() {\n\tkinu_cloud_bridge_start();\n",
        1,
    )
    cpp.write_text(cpp_text)

print("Patched Godot iOS export with native iCloud save bridge")
