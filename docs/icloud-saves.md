# iCloud saves

The offline save is `user://nest_save.json`. On iPhone, `CloudKvsService` writes a sanitized snapshot to `user://cloud_kvs_outbox.json`; the native Swift bridge copies it into eight rotating `NSUbiquitousKeyValueStore` slots. The bridge writes the iCloud slots to `user://cloud_kvs_inbox.json`, which Godot validates and can restore. Empty new installs do not upload a default save.

The snapshot includes progress, currency balances, and purchase receipts. It excludes the anonymous Supabase session, debug unlock switch, and local transfer timestamps. A newer cloud snapshot restores automatically when the local save is empty. If both saves contain progress and purchase ledgers differ, Settings asks which complete save to keep.

The Game Center saved-game API remains available as a secondary copy, but **its successful save callback is not proof that the file survives uninstall**. On the test iPhone it returned an empty list after uninstall, twice. Settings reports the native iCloud key-value sync instead.

## Build

The iOS export presets include the iCloud Documents/container and `com.apple.developer.ubiquity-kvstore-identifier` entitlements. The native bridge is in `ios/native_cloud/CloudBridge.swift`. A fresh Godot export overwrites its generated `dummy.swift` and `dummy.cpp`, so patch the export before building in Xcode:

```sh
zsh ios/native_cloud/build_ios.sh
```

Or, after a manual Godot export, run `python3 ios/native_cloud/patch_export.py` before building the generated Xcode project. The patch script fails if the key-value entitlement is missing.

## Device verification

On 30 September 2026, a signed development build on the connected iPhone wrote a save with best 38, 4 runs and 795 beans to the native iCloud key-value store. After an actual uninstall and reinstall of the same build, the game restored those values, the owned outfit, and the discovered flavours without copying a local file back to the device. The separate iCloud device backup was not restored or modified.

iCloud sync is asynchronous. The Settings timestamp means the snapshot was handed to iCloud sync; it is not a guarantee of immediate availability on another device. Keep an offline copy of a valuable save until a restore is confirmed. `NSUbiquitousKeyValueStore` is limited to small data; the current snapshot is about 2.4 KB and eight slots remain well below its 1 MB quota.
