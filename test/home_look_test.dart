import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nox_iptv/services/home_wallpaper.dart';
import 'package:nox_iptv/services/logo_colors.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart';

/// Straight RGBA pixels: [count] of each (r, g, b, a).
Uint8List _pixels(List<(int, int, int, int, int)> runs) {
  final out = <int>[];
  for (final (n, r, g, b, a) in runs) {
    for (var i = 0; i < n; i++) {
      out.addAll([r, g, b, a]);
    }
  }
  return Uint8List.fromList(out);
}

void main() {
  group('LogoColors.dominant', () {
    test('a red logo on a transparent background is red', () {
      final c = LogoColors.dominant(
          _pixels([(300, 0, 0, 0, 0), (100, 220, 20, 30, 255)]));
      expect(c, hasLength(1));
      expect(c.first.r, greaterThan(0.7));
      expect(c.first.g, lessThan(0.2));
    });

    test('white, black and grey logos have no colour', () {
      expect(
          LogoColors.dominant(_pixels([
            (200, 255, 255, 255, 255),
            (200, 10, 10, 10, 255),
            (200, 128, 128, 128, 255),
          ])),
          isEmpty);
    });

    test('a few coloured anti-aliasing pixels in a grey logo do not count',
        () {
      expect(
          LogoColors.dominant(_pixels([
            (1000, 200, 200, 200, 255),
            (5, 30, 60, 220, 255),
          ])),
          isEmpty);
    });

    test('a two-colour logo gives both, strongest first', () {
      final c = LogoColors.dominant(_pixels([
        (300, 20, 60, 230, 255), // blue
        (120, 230, 30, 30, 255), // red
      ]));
      expect(c, hasLength(2));
      expect(c[0].b, greaterThan(c[0].r));
      expect(c[1].r, greaterThan(c[1].b));
    });

    test('a neighbouring hue is not a second colour', () {
      final c = LogoColors.dominant(_pixels([
        (300, 230, 30, 30, 255), // red
        (200, 230, 70, 30, 255), // red-orange, next hue bin
      ]));
      expect(c, hasLength(1));
    });

    test('glow keeps the hue, lifts dull and tames bright colours', () {
      final dark = LogoColors.glow(const Color(0xFF301010));
      final light = LogoColors.glow(const Color(0xFFFFE0E0));
      for (final c in [dark, light]) {
        final hsl = HSLColor.fromColor(c);
        expect(hsl.lightness, inInclusiveRange(0.39, 0.56));
        expect(hsl.saturation, greaterThanOrEqualTo(0.59));
        expect(hsl.hue, anyOf(lessThan(15), greaterThan(345)));
      }
    });
  });

  group('HomeWallpaper', () {
    test('any picture becomes a 16:9 JPEG at most 1920 wide', () {
      final square =
          Uint8List.fromList(img.encodePng(img.Image(width: 2400, height: 2400)));
      final out = img.decodeJpg(HomeWallpaper.normalize(square))!;
      expect(out.width, 1920);
      expect(out.height, 1080);

      final small =
          Uint8List.fromList(img.encodeJpg(img.Image(width: 1280, height: 1000)));
      final s = img.decodeJpg(HomeWallpaper.normalize(small))!;
      expect(s.width, 1280);
      expect(s.height, 720);
    });

    test('refuses something that is not a picture', () {
      expect(() => HomeWallpaper.normalize(Uint8List.fromList([1, 2, 3, 4])),
          throwsFormatException);
    });

    test('save, load and remove one per viewer', () async {
      final dir = await Directory.systemTemp.createTemp('wallpaper');
      addTearDown(() => dir.delete(recursive: true));
      final w = HomeWallpaper(directory: dir);
      final pic =
          Uint8List.fromList(img.encodeJpg(img.Image(width: 640, height: 360)));
      var changes = 0;
      w.changes.addListener(() => changes++);

      expect(await w.load('main'), isNull);
      await w.save('main', pic);
      expect(await w.load('main'), isNotNull);
      expect(await w.load('kid'), isNull);
      await w.remove('main');
      expect(await w.load('main'), isNull);
      expect(changes, 2);
      expect(() => w.file('../x'), throwsFormatException);
    });
  });

  test('wallpaper pairing sends the photo payload', () {
    expect(PairingKind.wallpaper.mode, 'photo');
    expect(PairingKind.wallpaper.isWifiOnly, isTrue);
  });
}
