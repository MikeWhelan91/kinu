# Firebase in iOS builds

Firebase Analytics and Crashlytics are enabled only in the **iOS Production** export preset.
The ordinary **iOS** preset is for local and device testing: it excludes the
Firebase GDExtension entirely, so its native framework cannot initialize at
startup. It also does not bundle `GoogleService-Info.plist`.
`scripts/systems/analytics.gd` never calls the Firebase bridge in this preset.
Editor runs and Godot tests also leave Firebase inactive.

Build a test app with `zsh ios/native_cloud/build_ios.sh`. Build a production app with
`zsh ios/native_cloud/build_ios.sh production`. The production argument selects the preset
with the `production` feature and includes the Firebase configuration. Both use Xcode's
Release compiler configuration; that setting alone does not enable Firebase.

Use the production command only for a distribution build. If a test build was installed
over a production build, launch the new app after installing it to replace the previous
Firebase session.
