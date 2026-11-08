import 'dart:io';

/// A build that follows the App Store's rules: every iPhone/iPad build, or
/// an Android build made with `--dart-define=VESPER_APPSTORE=true` to
/// preview one on a box.
///
/// It leaves out what App Review objects to (dev-notes/apple-platforms.md):
/// the in-app updater (Apple installs updates), Debrid accounts and their
/// torrent-hash Ready check, and text that points at debrid services. Media
/// Hub add-ons the user adds still play as before: a debrid add-on resolves
/// its links itself, and the Ready tag falls back to asking the stream link
/// again (`ArchiveReadyWatch`).
bool get appStoreBuild =>
    const bool.fromEnvironment('VESPER_APPSTORE') || Platform.isIOS;
