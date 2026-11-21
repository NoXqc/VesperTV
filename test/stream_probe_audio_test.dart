import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playlist_edits.dart';
import 'package:nox_iptv/services/stream_probe.dart';

/// The playlist editor's stream test reads the audio too (Discord,
/// 2026-11-19: "add audio probe to test, and sort results with 5.1
/// preferred over 2.0").
void main() {
  Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

  test('Dolby headers: AC-3 5.1, AC-3 2.0, E-AC-3 5.1', () {
    // AC-3: sync, crc, fscod/frmsizecod, bsid 8, acmod 7 + mixes + lfeon 1.
    expect(
        StreamProbe.audioFrom(StreamProbe.kindDolby,
            b([0x0B, 0x77, 0, 0, 0x1C, 0x40, 0xE1, 0, 0])),
        (codec: 'AC-3', layout: '5.1', channels: 6));
    // acmod 2 (stereo): dsurmod, then lfeon 0.
    expect(
        StreamProbe.audioFrom(StreamProbe.kindDolby,
            b([0x0B, 0x77, 0, 0, 0x1C, 0x40, 0x40, 0, 0])),
        (codec: 'AC-3', layout: '2.0', channels: 2));
    // E-AC-3: bsid 16, acmod 7 + lfeon in the fifth byte.
    expect(
        StreamProbe.audioFrom(StreamProbe.kindDolby,
            b([0x0B, 0x77, 0x00, 0xFF, 0x3F, 0x80, 0, 0, 0])),
        (codec: 'E-AC-3', layout: '5.1', channels: 6));
    // Junk before the sync word is skipped.
    expect(
        StreamProbe.audioFrom(StreamProbe.kindDolby,
                b([1, 2, 3, 0x0B, 0x77, 0, 0, 0x1C, 0x40, 0xE1, 0, 0]))
            ?.layout,
        '5.1');
  });

  test('AAC (ADTS) and MPEG audio headers', () {
    // ADTS LC 48 kHz, channel configuration 2, a 10-byte frame, then the
    // next frame's sync.
    List<int> adts(int cfg) => [
          0xFF, 0xF1, 0x4C | (cfg >> 2), ((cfg & 3) << 6), 0x01, 0x5F, //
          0xFC, 0, 0, 0, 0xFF, 0xF1,
        ];
    expect(StreamProbe.audioFrom(StreamProbe.kindAdts, b(adts(2))),
        (codec: 'AAC', layout: '2.0', channels: 2));
    expect(StreamProbe.audioFrom(StreamProbe.kindAdts, b(adts(6))),
        (codec: 'AAC', layout: '5.1', channels: 6));
    // MPEG-1 Layer II, stereo.
    expect(
        StreamProbe.audioFrom(
            StreamProbe.kindMpegAudio, b([0xFF, 0xFD, 0xC4, 0x00])),
        (codec: 'MP2', layout: '2.0', channels: 2));
  });

  test('a stream with two audio tracks reports the 5.1 one', () {
    final r = StreamProbe.parseTs(_twoAudioTs(), DateTime.now())!;
    expect(r.ok, isTrue);
    expect(r.codec, 'H.264');
    expect(r.audioLayout, '5.1');
    expect(r.audioCodec, 'AC-3');
    expect(r.audioChannels, 6);
  });

  test('label, saving, and a later size-only measurement keeps the audio',
      () {
    final at = DateTime.now();
    final tested = ProbeResult(
        ok: true,
        at: at,
        height: 2160,
        width: 3840,
        fps: 50,
        codec: 'HEVC',
        audioLayout: '5.1',
        audioCodec: 'E-AC-3',
        audioChannels: 6);
    expect(tested.label, '4K 50fps HEVC · 5.1 E-AC-3');
    final back = ProbeResult.fromJson(tested.toJson())!;
    expect(back.label, tested.label);
    expect(back.audioChannels, 6);
    // The full-screen player records the picture size only.
    final played = ProbeResult(ok: true, at: at, height: 2160, width: 3840)
        .fillFrom(tested);
    expect(played.label, '4K 50fps HEVC · 5.1 E-AC-3');
    expect(ProbeResult(ok: true, at: at, audioLayout: '2.0').label, '2.0');
  });

  test('copies: 5.1 sorts above 2.0, hiding still by picture only', () {
    Channel ch(String id) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: 'SKY SPORTS F1 4K',
        group: 'UK',
        url: 'http://x/$id.ts');
    final at = DateTime.now();
    ProbeResult p(int ch) => ProbeResult(
        ok: true, at: at, height: 2160, audioChannels: ch);
    final edits = PlaylistEdits(
        probes: {'a': p(2), 'b': p(6)}, hideLowerCopies: true);
    expect(edits.audioRank(ch('a')), 1);
    expect(edits.audioRank(ch('b')), 2);
    expect(edits.audioRank(ch('c')), 1, reason: 'not tested');
    expect(edits.copyRank(ch('a')), edits.copyRank(ch('b')));
    expect(edits.apply([ch('a'), ch('b')]), isEmpty,
        reason: 'a 2.0 copy is not hidden for its audio');
  });

  test('copies: picture, then frame rate, then audio (clayts450, 2026-11-21)',
      () {
    Channel ch(String id) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: 'SKY SPORTS +',
        group: 'UK',
        url: 'http://x/$id.ts');
    final at = DateTime.now();
    ProbeResult p(int h, double fps, int audio) => ProbeResult(
        ok: true, at: at, height: h, fps: fps, audioChannels: audio);
    final edits = PlaylistEdits(probes: {
      'hd25': p(1080, 25, 6),
      'hd50': p(1080, 50, 2),
      'hd50a': p(1080, 50, 6),
      'sd50': p(720, 50, 6),
      'sd25': p(720, 25, 2),
    });
    int byQuality(String a, String b) {
      final x = ch(a), y = ch(b);
      var c = edits.copyRank(y).compareTo(edits.copyRank(x));
      if (c == 0) c = edits.fpsRank(y).compareTo(edits.fpsRank(x));
      if (c == 0) c = edits.audioRank(y).compareTo(edits.audioRank(x));
      return c;
    }

    final order = ['sd25', 'hd25', 'sd50', 'hd50', 'hd50a']..sort(byQuality);
    expect(order, ['hd50a', 'hd50', 'hd25', 'sd50', 'sd25']);
    expect(edits.fpsRank(ch('hd50')), 50);
    expect(edits.fpsRank(ch('untested')), 0);
  });
}

/// PAT + PMT (H.264 on 0x100, DVB AC-3 on 0x101 via descriptor 0x6A, AAC
/// on 0x102) + one PES start for each audio track.
Uint8List _twoAudioTs() {
  final out = BytesBuilder();
  List<int> packet(int pid, bool pusi, List<int> payload) {
    final p = List<int>.filled(188, 0xFF);
    p[0] = 0x47;
    p[1] = (pusi ? 0x40 : 0) | (pid >> 8);
    p[2] = pid & 0xFF;
    p[3] = 0x10;
    for (var i = 0; i < payload.length && i + 4 < 188; i++) {
      p[4 + i] = payload[i];
    }
    return p;
  }

  out.add(packet(0, true,
      [0, 0x00, 0xB0, 13, 0, 1, 0xC1, 0, 0, 0, 1, 0xF0, 0x00, 0, 0, 0, 0]));
  final entries = [
    0x1B, 0xE1, 0x00, 0xF0, 0x00, // video
    0x0F, 0xE1, 0x02, 0xF0, 0x00, // AAC first in the PMT
    0x06, 0xE1, 0x01, 0xF0, 0x03, 0x6A, 0x01, 0x00, // AC-3 (DVB)
  ];
  final secLen = 9 + entries.length + 4;
  out.add(packet(0x1000, true, [
    0, // pointer field
    0x02, 0xB0, secLen, 0, 1, 0xC1, 0, 0, 0xE1, 0x00, 0xF0, 0x00,
    ...entries,
    0, 0, 0, 0, // CRC (not checked)
  ]));
  const pes = [0, 0, 1, 0xC0, 0, 0, 0x80, 0x00, 0x00];
  out.add(packet(0x102, true, [
    ...pes,
    0xFF, 0xF1, 0x4C, 0x80, 0x01, 0x5F, 0xFC, 0, 0, 0, 0xFF, 0xF1, //
  ]));
  out.add(packet(0x101, true, [
    ...pes,
    0x0B, 0x77, 0, 0, 0x1C, 0x40, 0xE1, 0, 0,
  ]));
  return out.takeBytes();
}
