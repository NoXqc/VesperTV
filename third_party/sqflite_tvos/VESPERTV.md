# sqflite_tvos (vendored)

Copy of `sqflite_tvos` 0.0.2 from pub.dev (example/ and test/ left out), with one
change: `tvos/Resources/PrivacyInfo.xcprivacy` (copied from `sqflite_darwin` 2.4.4)
bundled by the podspec's `resource_bundles`.

Why: Apple's TestFlight review rejected Apple TV build 802 with ITMS-91061
"Missing privacy manifest" for `Frameworks/sqflite_tvos.framework` (sqflite is on
Apple's list of commonly used SDKs). Drop this copy once an upstream release
ships its own manifest.
