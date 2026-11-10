import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'profile_photos.dart';

/// Home's own wallpaper (Settings > Interface > Tabs > Home wallpaper; idea
/// from a Discord user, owner 2026-11-10). One 16:9 JPEG per viewer in app
/// support, never sent anywhere and never part of a transfer or backup
/// (it's a file, not a setting). Home shows it behind the hero whenever the
/// focused card has no art of its own; it replaces the live channels'
/// colour glow (owner: "when wallpaper is used it supersedes the channel
/// banner").
class HomeWallpaper {
  HomeWallpaper({this.directory});

  static final instance = HomeWallpaper();

  /// Tests point this at a temporary folder.
  final Directory? directory;

  /// Bumped on every save / removal so a mounted Home reloads it.
  final changes = ValueNotifier<int>(0);

  /// What a phone may send (the phone page already resizes it to 1920 wide)
  /// and what a computer's file picker may hand over.
  static const maxBytes = 15 * 1024 * 1024;
  static const width = 1920, height = 1080;

  Future<Directory> _root() async =>
      directory ??
      Directory('${(await getApplicationSupportDirectory()).path}/wallpapers');

  Future<File> file(String viewerId) async {
    if (!ProfilePhotos.validId(viewerId)) {
      throw const FormatException('Invalid profile id');
    }
    return File('${(await _root()).path}/$viewerId.jpg');
  }

  /// The viewer's wallpaper, or null when there is none (or it can't be read).
  Future<Uint8List?> load(String viewerId) async {
    try {
      final f = await file(viewerId);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(String viewerId) async => await load(viewerId) != null;

  /// Any JPEG / PNG -> a 16:9 crop (centre), at most [width] x [height],
  /// JPEG 85. Throws [FormatException] for anything else.
  static Uint8List normalize(Uint8List bytes) {
    final mime = ProfilePhotos.mime(bytes);
    if (bytes.isEmpty || bytes.length > maxBytes || mime == null) {
      throw const FormatException('Invalid picture');
    }
    final img.Decoder decoder =
        mime == 'image/png' ? img.PngDecoder() : img.JpegDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 40000000) {
      throw const FormatException('Invalid picture dimensions');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const FormatException('Invalid picture');
    final image = img.bakeOrientation(decoded);
    // Centre crop to 16:9.
    var w = image.width, h = image.height;
    if (w * 9 > h * 16) {
      w = (h * 16 / 9).round();
    } else {
      h = (w * 9 / 16).round();
    }
    final crop = img.copyCrop(
      image,
      x: (image.width - w) ~/ 2,
      y: (image.height - h) ~/ 2,
      width: w,
      height: h,
    );
    final out = w > width
        ? img.copyResize(
            crop,
            width: width,
            height: height,
            interpolation: img.Interpolation.average,
          )
        : crop;
    return Uint8List.fromList(img.encodeJpg(out, quality: 85));
  }

  Future<void> save(String viewerId, Uint8List bytes) async {
    final normalized = await compute(normalize, bytes);
    final target = await file(viewerId);
    await target.parent.create(recursive: true);
    // Only a finished file replaces the old one.
    final pending = File('${target.path}.tmp');
    await pending.writeAsBytes(normalized, flush: true);
    if (await target.exists()) await target.delete();
    await pending.rename(target.path);
    changes.value++;
  }

  Future<void> remove(String viewerId) async {
    final target = await file(viewerId);
    if (await target.exists()) await target.delete();
    final pending = File('${target.path}.tmp');
    if (await pending.exists()) await pending.delete();
    changes.value++;
  }
}
