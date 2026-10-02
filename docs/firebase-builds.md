# Firebase in iOS builds

Firebase Analytics and Crashlytics run in every **release** iOS export and never in a **debug**
export. `scripts/systems/analytics.gd` only configures the Firebase bridge when
`OS.is_debug_build()` is false, and the Firebase export plugin only bundles
`GoogleService-Info.plist` into release exports. Editor runs and Godot tests also leave Firebase
inactive.

Build a release app with `zsh ios/native_cloud/build_ios.sh`. Build a debug app with
`zsh ios/native_cloud/build_ios.sh debug`. Both use the **iOS** preset; a debug export still
links the Firebase framework but never configures it. Exporting from the editor follows the same
rule: "Export With Debug" leaves Firebase off, a release export turns it on.

If a debug build was installed over a release build, launch the new app after installing it to
replace the previous Firebase session.
