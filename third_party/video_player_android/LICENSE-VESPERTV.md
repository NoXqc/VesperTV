# Licensing of this folder

This folder started as a copy of Flutter's `video_player_android` 2.12.2 plugin and has been
changed a great deal for VesperTV. Two licenses apply here:

- **Flutter's original code** stays under the BSD 3-clause license in [LICENSE](LICENSE)
  (Copyright 2013 The Flutter Authors). The unchanged original is available from
  <https://pub.dev/packages/video_player_android> and <https://github.com/flutter/packages>.
- **Everything VesperTV added or changed** is under the GNU General Public License version 3
  ([../../LICENSE](../../LICENSE)) with VesperTV's App Store exception
  ([../../APP_STORE_EXCEPTION.md](../../APP_STORE_EXCEPTION.md)), Copyright (C) 2026 VesperTV
  contributors. That covers the whole player work in this folder: live stream splicing
  (`TsSplice`), live pause and rewind (`Timeshift`), reconnects, read-ahead, the MKV fixes,
  Atmos / DTS / passthrough audio, subtitles, DRM, stats, Multiview tiles, the native video surface
  and every change to Flutter's own files.

How to tell them apart:

- A file VesperTV wrote starts with `SPDX-License-Identifier: GPL-3.0-only`.
- A Flutter file VesperTV changed keeps Flutter's header and says so right under it; the
  changes in it are GPL-3.0.
- Generated files (`Messages.kt`, `messages.g.dart`) come from `pigeons/messages.dart`, which
  VesperTV changed: they are GPL-3.0 as well.

Using this folder as it is, or any part of it beyond Flutter's original code, means using it
under the GPL v3: the app you build with it must be released as source under the same license.
The BSD license above does not cover VesperTV's work.

The **VesperTV** name and logo are not covered by either license: see
[../../TRADEMARKS.md](../../TRADEMARKS.md).
