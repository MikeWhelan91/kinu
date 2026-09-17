# Kinu Tumble Firebase wrapper

Ported from CritterScale's `GodotApplePluginsFirebase` wrapper (same developer team, same SwiftGodot runtime). The wrapper automatically configures Firebase at scene initialization; Analytics remains enabled even though game scripts do not call its event methods directly. It wraps Firebase 11.15.0, with FirebaseCore, FirebaseAnalytics and FirebaseCrashlytics linked into its dynamic framework.

## SDK signature repair (ITMS-91065)

The original XCFramework had no outer SDK signature. Ordinary app/archive code signing does not supply that missing SDK origin signature. The existing custom wrapper bundle is now signed using this project's Apple Development identity with a secure timestamp, as permitted by Apple's XCFramework signing documentation. This identifies the custom repackager; it does not claim that the wrapper was signed by Google.

After rebuilding or modifying the XCFramework, run `tools/sign_firebase_sdk.sh` from the game project before exporting. Godot preserves the signature when copying the bundle. Do not modify the signed bundle afterward without signing it again.

In a fresh archive, inspect `Signatures/GodotApplePluginsFirebase.xcframework-ios.signature`: `signed` must be true and signer information must be present. Verify the source/exported XCFramework with `codesign --verify --strict`.

Apple documentation: https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle

This repair does not disable Analytics or Crashlytics or change the SDK's executable code. Final App Store server validation requires uploading the new archive.
