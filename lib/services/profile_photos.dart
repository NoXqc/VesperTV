import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Private, app-support files only. No photo is sent to a cloud service.
class ProfilePhotos {
  ProfilePhotos({this.directory});
  final Directory? directory;
  static const maxBytes = 2 * 1024 * 1024;
  static bool validId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id);
  Future<Directory> _root() async =>
      directory ??
      Directory('${(await getApplicationSupportDirectory()).path}/profiles');
  Future<File> file(String id) async {
    if (!validId(id)) throw const FormatException('Invalid profile id');
    return File('${(await _root()).path}/$id.jpg');
  }

  static String? mime(List<int> b) =>
      b.length >= 8 && b[0] == 137 && b[1] == 80 && b[2] == 78 && b[3] == 71
          ? 'image/png'
          : b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255
              ? 'image/jpeg'
              : null;
  static Uint8List normalize(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes || mime(bytes) == null) {
      throw const FormatException('Invalid photo');
    }
    final img.Decoder decoder =
        mime(bytes) == 'image/png' ? img.PngDecoder() : img.JpegDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 16000000) {
      throw const FormatException('Invalid photo dimensions');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const FormatException('Invalid photo');
    final image = img.bakeOrientation(decoded);
    final side = image.width < image.height ? image.width : image.height;
    final square = img.copyCrop(image,
        x: (image.width - side) ~/ 2,
        y: (image.height - side) ~/ 2,
        width: side,
        height: side);
    return Uint8List.fromList(img.encodeJpg(
        img.copyResize(square, width: 512, height: 512),
        quality: 85));
  }

  Future<void> save(String id, Uint8List bytes) async {
    final normalized = await compute(normalize, bytes);
    final target = await file(id);
    await target.parent.create(recursive: true);
    // A completed file replaces the old one; no partial upload becomes an avatar.
    final pending = File('${target.path}.tmp');
    await pending.writeAsBytes(normalized, flush: true);
    if (await target.exists()) await target.delete();
    await pending.rename(target.path);
  }

  Future<void> remove(String id) async {
    final target = await file(id);
    if (await target.exists()) await target.delete();
    final pending = File('${target.path}.tmp');
    if (await pending.exists()) await pending.delete();
  }

  Future<Map<String, String>> export(Iterable<String> ids) async {
    final result = <String, String>{};
    for (final id in ids) {
      final target = await file(id);
      if (await target.exists()) {
        final bytes = await target.readAsBytes();
        if (bytes.length <= maxBytes) result[id] = base64Encode(bytes);
      }
    }
    return result;
  }

  Future<void> restore(Map photos, Iterable<String> ids) async {
    for (final id in ids) {
      final encoded = photos[id];
      if (encoded is String &&
          encoded.length <= (maxBytes * 4 / 3).ceil() + 4) {
        try {
          await save(id, base64Decode(encoded));
          continue;
        } catch (_) {/* Reject damaged photos. */}
      }
      await remove(id);
    }
  }
}
