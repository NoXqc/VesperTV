import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/video_fit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's picture button (owner, 2026-11-11, like Nuvio): one press
/// = the next way to size the picture.
void main() {
  const tv = Size(1920, 1080);

  void near(Size actual, Size expected) {
    expect(actual.width, closeTo(expected.width, 1));
    expect(actual.height, closeTo(expected.height, 1));
  }

  test('a 2.39:1 film on a 16:9 screen', () {
    const r = 2.39;
    near(VideoFit.fit.sizeIn(tv, r), const Size(1920, 803));
    near(VideoFit.stretch.sizeIn(tv, r), tv);
    near(VideoFit.crop.sizeIn(tv, r), const Size(2581, 1080));
    near(VideoFit.fitHeight.sizeIn(tv, r), const Size(2581, 1080));
    near(VideoFit.fitWidth.sizeIn(tv, r), const Size(1920, 803));
    near(VideoFit.zoom.sizeIn(tv, r), const Size(2150, 900));
    // The band fills the height, like Crop.
    near(VideoFit.cinema.sizeIn(tv, r), const Size(2581, 1080));
  });

  test('a 16:9 picture with a wide film burned in: Cinema zoom fills it', () {
    near(VideoFit.fit.sizeIn(tv, 16 / 9), tv);
    near(VideoFit.cinema.sizeIn(tv, 16 / 9), const Size(2581, 1452));
    near(VideoFit.crop.sizeIn(tv, 16 / 9), tv);
  });

  test('a 4:3 picture', () {
    near(VideoFit.fit.sizeIn(tv, 4 / 3), const Size(1440, 1080));
    near(VideoFit.fitWidth.sizeIn(tv, 4 / 3), const Size(1920, 1440));
    near(VideoFit.crop.sizeIn(tv, 4 / 3), const Size(1920, 1440));
    near(VideoFit.stretch.sizeIn(tv, 4 / 3), tv);
  });

  test('a portrait phone never zooms more than 1.5x for Cinema', () {
    const phone = Size(390, 844);
    final fit = VideoFit.fit.sizeIn(phone, 16 / 9);
    near(VideoFit.cinema.sizeIn(phone, 16 / 9), fit * 1.5);
  });

  test('the button cycles through every mode and back', () {
    var f = VideoFit.fit;
    final seen = <VideoFit>[];
    for (var i = 0; i < VideoFit.values.length; i++) {
      seen.add(f);
      f = f.next;
    }
    expect(f, VideoFit.fit);
    expect(seen, VideoFit.values);
    expect(seen.map((f) => f.label), [
      'Fit',
      'Stretched',
      'Crop',
      'Fit height',
      'Fit width',
      'Slight zoom',
      'Cinema zoom',
    ]);
    expect(VideoFit.byName('nope'), VideoFit.fit);
  });

  test('the old Fill switch reads as Crop, and stays in step', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyVideoFill: true});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    expect(prefs.videoFit, VideoFit.crop);
    expect(prefs.videoFill, isTrue);
    prefs.setVideoFit(VideoFit.cinema);
    await Future<void>.delayed(Duration.zero);
    expect(storage.getVideoFit(), 'cinema');
    expect(storage.getVideoFill(), isTrue,
        reason: 'an older build still sees the picture filled');
    prefs.setVideoFill(false);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.videoFit, VideoFit.fit);
    expect(storage.getVideoFill(), isFalse);
    prefs.dispose();
  });
}
