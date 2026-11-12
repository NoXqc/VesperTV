import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/auto_subtitles.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';

/// One ustar entry: a 512-byte header, the data padded to 512.
List<int> tarEntry(String name, List<int> data, {int type = 0x30}) {
  final header = Uint8List(512);
  void put(int at, String text) =>
      header.setRange(at, at + text.length, ascii.encode(text));
  put(0, name);
  put(124, '${data.length.toRadixString(8).padLeft(11, '0')}\u0000');
  header[156] = type;
  put(257, 'ustar\u000000');
  final padded = Uint8List(((data.length + 511) ~/ 512) * 512)
    ..setRange(0, data.length, data);
  return [...header, ...padded];
}

void main() {
  group('automatic subtitles', () {
    test('model text in sentence case', () {
      expect(AutoSubtitles.tidy('HELLO AND WELCOME TO THE SHOW', 'en'),
          'Hello and welcome to the show');
      expect(
          AutoSubtitles.tidy("I THINK I'M  RIGHT", 'en'), "I think I'm right");
      expect(AutoSubtitles.tidy('BONJOUR À TOUS', 'fr'), 'Bonjour à tous');
      expect(AutoSubtitles.tidy('  ', 'en'), '');
    });

    test('the engine archive is read without a tar package', () {
      final so = List<int>.generate(1300, (i) => i % 251);
      final tar = [
        ...tarEntry('android/src/main/jniLibs/arm64-v8a/', [], type: 0x35),
        ...tarEntry('android/src/main/jniLibs/arm64-v8a/libonnxruntime.so', so),
        ...tarEntry('pubspec.yaml', utf8.encode('name: x')),
        ...List<int>.filled(1024, 0),
      ];
      final files = {
        for (final (name, data) in AutoSubtitles.untar(tar)) name: data
      };
      expect(files.keys, [
        'android/src/main/jniLibs/arm64-v8a/libonnxruntime.so',
        'pubspec.yaml',
      ]);
      expect(files['android/src/main/jniLibs/arm64-v8a/libonnxruntime.so'], so);
    });

    test('every language has its four model files', () {
      for (final m in autoSubtitleModels) {
        expect(m.files, hasLength(4), reason: m.language);
        expect(m.files.last, 'tokens.txt');
        expect(m.urlOf(m.encoder),
            startsWith('https://huggingface.co/${m.repo}/resolve/main/'));
        expect(autoSubtitleModel(m.language), same(m));
      }
      expect(autoSubtitleModel('xx'), isNull);
    });

    test('not on this test computer (Android ARM only)', () {
      expect(AutoSubtitles.supported, isFalse);
    });
  });

  group('picture subtitles (DVB / PGS)', () {
    test('a cue event carries its images', () {
      final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
      final event = SubtitleCueEvent.fromMap({
        'playerId': 3,
        'text': '',
        'cues': const [],
        'images': [
          {
            'png': png,
            'w': 960,
            'h': 120,
            'position': 0.25,
            'line': 0.8,
            'size': 0.5
          },
          {'png': Uint8List(0)},
        ],
        'enabled': true,
        'cc': false,
        'mime': 'application/dvbsubs',
      });
      expect(event.images, hasLength(1));
      final image = event.images.single;
      expect(image.png, png);
      expect(image.width, 960);
      expect(image.centre, 0.5);
      expect(image.top, 0.8);
    });

    test('no place given: centred', () {
      final image = SubtitleImage.fromMap({
        'png': Uint8List.fromList([1]),
        'w': 10,
        'h': 2
      })!;
      expect(image.centre, 0.5);
      expect(image.size, isNull);
    });
  });
}
