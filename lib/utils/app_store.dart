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
///
/// Also (App Review, 2026-11-14): no Support VesperTV row (donation links
/// outside Apple's in-app purchase), no betting odds (gambling content), no
/// Remote tips (a TV-box remote guide that names other platforms) and no
/// other platform's name in what an iPhone shows.
///
/// And (owner, 2026-11-14) no Stremio-style add-ons at all: the Media Hub
/// is the viewer's own Jellyfin / Emby / Plex server (AIOStreams can serve
/// add-ons as one) and Trakt / Simkl lists. Add-ons saved on the device
/// (a Transfer from an Android box) stay saved but never show or play
/// ([ArchiveService.sources], [AddonService.addons]); no subtitle add-ons,
/// no Discord or donation links. Collections stay, worded as the viewer's
/// own collections for their server (its libraries fill the tiles), with no
/// community pack and no From phone (they are on their phone).
bool get appStoreBuild =>
    const bool.fromEnvironment('VESPER_APPSTORE') || Platform.isIOS;
