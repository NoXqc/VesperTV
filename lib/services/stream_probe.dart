import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'playlist_edits.dart';
import '../utils/desktop_platform.dart';

/// Opt-in playlist-editor stream test: opens ONE stream for a few seconds
/// and reads what it really is (resolution, frame rate, codec) without a
/// decoder. HLS: the master playlist's `RESOLUTION`/`FRAME-RATE` (often no
/// video bytes at all), else the first segment. MPEG-TS: the video PID's
/// SPS (H.264 / HEVC) + PES timestamps for the frame rate.
///
/// Callers run it strictly one stream at a time (see
/// `PlaylistEditorServer._runProbe`); providers often allow 1 connection.
class StreamProbe {
  StreamProbe({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _readLimit = 600 * 1024;
  static const _readTime = Duration(seconds: 6);

  /// Statuses that mean "stop the whole test, the provider is refusing us".
  static bool isRefusal(ProbeResult r) =>
      !r.ok &&
      (r.error == 'HTTP 401' ||
          r.error == 'HTTP 403' ||
          r.error == 'HTTP 429' ||
          r.error == 'HTTP 458' ||
          r.error == 'connection limit');

  Future<ProbeResult> probe(Channel channel) async {
    final now = DateTime.now();
    try {
      final first = await _read(Uri.parse(channel.url), channel.httpHeaders);
      if (first.status >= 400) {
        return ProbeResult(ok: false, at: now, error: 'HTTP ${first.status}');
      }
      final bytes = first.bytes;
      if (_startsWith(bytes, '#EXTM3U')) {
        return await _hls(
            first.uri, String.fromCharCodes(bytes), channel.httpHeaders, now);
      }
      return parseTs(bytes, now) ??
          ProbeResult(
              ok: bytes.length > 4096,
              at: now,
              error: bytes.length > 4096 ? null : 'no video');
    } on TimeoutException {
      return ProbeResult(ok: false, at: now, error: 'timeout');
    } catch (e) {
      final text = e.toString().toLowerCase();
      return ProbeResult(
          ok: false,
          at: now,
          error: text.contains('max') && text.contains('connection')
              ? 'connection limit'
              : 'no reply');
    }
  }

  void close() => _client.close();

  Future<ProbeResult> _hls(
      Uri base, String text, Map<String, String> headers, DateTime now) async {
    final lines = text.split(RegExp(r'\r?\n'));
    int? bestH, bestW;
    double? fps;
    String? codec;
    String? audioCodec;
    String? bestVariant;
    // Audio renditions' CHANNELS ("6", "16/JOC"): the most speakers.
    int? audioChannels;
    for (final line in lines) {
      if (!line.startsWith('#EXT-X-MEDIA') || !line.contains('TYPE=AUDIO')) {
        continue;
      }
      final n = int.tryParse(
          RegExp(r'CHANNELS="(\d+)').firstMatch(line)?.group(1) ?? '');
      if (n != null && n > (audioChannels ?? 0)) audioChannels = n;
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      final res = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
      final h = res == null ? null : int.parse(res.group(2)!);
      if (bestVariant == null || (h != null && h > (bestH ?? 0))) {
        bestH = h;
        bestW = res == null ? null : int.parse(res.group(1)!);
        final f = RegExp(r'FRAME-RATE=([\d.]+)').firstMatch(line);
        fps = f == null ? null : double.tryParse(f.group(1)!);
        final c = RegExp(r'CODECS="([^"]+)"').firstMatch(line)?.group(1);
        codec = c == null
            ? null
            : c.contains('hvc1') || c.contains('hev1')
                ? 'HEVC'
                : c.contains('avc1')
                    ? 'H.264'
                    : null;
        audioCodec = c == null
            ? null
            : c.contains('ec-3')
                ? 'E-AC-3'
                : c.contains('ac-3')
                    ? 'AC-3'
                    : c.contains('mp4a')
                        ? 'AAC'
                        : null;
        for (var j = i + 1; j < lines.length; j++) {
          final v = lines[j].trim();
          if (v.isNotEmpty && !v.startsWith('#')) {
            bestVariant = v;
            break;
          }
        }
      }
    }
    if (bestH != null) {
      // 16 is Atmos (JOC) over 5.1 in Apple's spelling: shown as 5.1.
      final ch = audioChannels == 16 ? 6 : audioChannels?.clamp(1, 8);
      return ProbeResult(
          ok: true,
          at: now,
          height: bestH,
          width: bestW,
          fps: fps,
          codec: codec,
          audioCodec: audioCodec,
          audioChannels: ch,
          audioLayout: switch (ch) {
            null => null,
            6 => '5.1',
            8 => '7.1',
            final n => '$n.0',
          });
    }
    // A media playlist (or a master without RESOLUTION): read a segment.
    var media = text;
    var mediaUri = base;
    if (bestVariant != null) {
      mediaUri = base.resolve(bestVariant);
      final r = await _read(mediaUri, headers, limit: 256 * 1024);
      if (r.status >= 400) {
        return ProbeResult(ok: false, at: now, error: 'HTTP ${r.status}');
      }
      media = String.fromCharCodes(r.bytes);
      mediaUri = r.uri;
    }
    final segment = media
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .lastOrNull;
    if (segment == null) return ProbeResult(ok: false, at: now, error: 'empty');
    final seg = await _read(mediaUri.resolve(segment), headers);
    if (seg.status >= 400) {
      return ProbeResult(ok: false, at: now, error: 'HTTP ${seg.status}');
    }
    return parseTs(seg.bytes, now) ?? ProbeResult(ok: true, at: now);
  }

  Future<({int status, Uint8List bytes, Uri uri})> _read(
      Uri uri, Map<String, String> headers,
      {int limit = _readLimit}) async {
    final req = http.Request('GET', uri)
      ..headers.addAll(headers)
      ..followRedirects = true;
    final res = await _client.send(req).timeout(const Duration(seconds: 8));
    final out = BytesBuilder(copy: false);
    if (res.statusCode < 400) {
      final done = Completer<void>();
      late StreamSubscription<List<int>> sub;
      final timer = Timer(_readTime, () {
        if (!done.isCompleted) done.complete();
      });
      sub = res.stream.listen((chunk) {
        out.add(chunk);
        if (out.length >= limit && !done.isCompleted) done.complete();
      }, onDone: () {
        if (!done.isCompleted) done.complete();
      }, onError: (Object _) {
        if (!done.isCompleted) done.complete();
      }, cancelOnError: true);
      await done.future;
      timer.cancel();
      // Closes the provider connection right away.
      await sub.cancel();
    } else {
      unawaited(res.stream.listen((_) {}).cancel());
    }
    return (
      status: res.statusCode,
      bytes: out.takeBytes(),
      uri: res.request?.url ?? uri
    );
  }

  static bool _startsWith(Uint8List b, String s) {
    var i = 0;
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) i = 3;
    if (b.length < i + s.length) return false;
    for (var k = 0; k < s.length; k++) {
      if (b[i + k] != s.codeUnitAt(k)) return false;
    }
    return true;
  }

  // ------------------------------------------------------------- MPEG-TS

  /// Null when [bytes] isn't MPEG-TS.
  @visibleForTesting
  static ProbeResult? parseTs(Uint8List bytes, DateTime at) {
    var start = -1;
    for (var i = 0; i + 376 < bytes.length && i < 188; i++) {
      if (bytes[i] == 0x47 && bytes[i + 188] == 0x47) {
        start = i;
        break;
      }
    }
    if (start < 0) return null;
    int? pmtPid;
    int? videoPid;
    var videoType = 0;
    var pmtRead = false;
    // Audio tracks: pid -> the kind [_audioOf] reads (Discord, 2026-11-19:
    // "add audio probe to test ... 5.1 preferred over 2.0").
    final audioKind = <int, int>{};
    final audioEs = <int, BytesBuilder>{};
    final es = BytesBuilder(copy: false);
    final pts = <int>[];
    for (var p = start; p + 188 <= bytes.length; p += 188) {
      if (bytes[p] != 0x47) continue;
      final pusi = bytes[p + 1] & 0x40 != 0;
      final pid = ((bytes[p + 1] & 0x1F) << 8) | bytes[p + 2];
      final afc = (bytes[p + 3] >> 4) & 0x3;
      var off = p + 4;
      if (afc == 2 || afc == 0) continue;
      if (afc == 3) off += 1 + bytes[p + 4];
      if (off >= p + 188) continue;
      if (pid == 0 && pusi && pmtPid == null) {
        final t = off + 1 + bytes[off];
        // First program in the PAT.
        for (var k = t + 8; k + 4 <= t + 3 + _secLen(bytes, t) - 4; k += 4) {
          final prog = (bytes[k] << 8) | bytes[k + 1];
          if (prog != 0) {
            pmtPid = ((bytes[k + 2] & 0x1F) << 8) | bytes[k + 3];
            break;
          }
        }
      } else if (pid == pmtPid && pusi && !pmtRead) {
        pmtRead = true;
        final t = off + 1 + bytes[off];
        final end = t + 3 + _secLen(bytes, t) - 4;
        final infoLen = ((bytes[t + 10] & 0x0F) << 8) | bytes[t + 11];
        for (var k = t + 12 + infoLen; k + 5 <= end && k + 5 < bytes.length;) {
          final type = bytes[k];
          final epid = ((bytes[k + 1] & 0x1F) << 8) | bytes[k + 2];
          final esLen = ((bytes[k + 3] & 0x0F) << 8) | bytes[k + 4];
          if ((type == 0x1B || type == 0x24) && videoPid == null) {
            videoPid = epid;
            videoType = type;
          } else {
            final kind = _audioKind(
                type, bytes, k + 5, (k + 5 + esLen).clamp(0, bytes.length));
            if (kind != null) audioKind[epid] = kind;
          }
          k += 5 + esLen;
        }
      } else if (audioKind.containsKey(pid)) {
        // The first few frames of each audio track, from a PES start.
        var o = off;
        if (pusi &&
            o + 9 < p + 188 &&
            bytes[o] == 0 &&
            bytes[o + 1] == 0 &&
            bytes[o + 2] == 1) {
          o += 9 + bytes[o + 8];
        }
        final b = audioEs[pid];
        if (o < p + 188 && (b != null || pusi)) {
          final into = b ?? (audioEs[pid] = BytesBuilder(copy: false));
          if (into.length < 16 * 1024) {
            into.add(Uint8List.sublistView(bytes, o, p + 188));
          }
        }
      } else if (videoPid != null && pid == videoPid) {
        if (pusi &&
            off + 9 < p + 188 &&
            bytes[off] == 0 &&
            bytes[off + 1] == 0 &&
            bytes[off + 2] == 1) {
          final flags = bytes[off + 7];
          if (flags & 0x80 != 0 && off + 14 <= p + 188) {
            final b = off + 9;
            pts.add(((bytes[b] >> 1) & 0x07) << 30 |
                bytes[b + 1] << 22 |
                (bytes[b + 2] >> 1) << 15 |
                bytes[b + 3] << 7 |
                bytes[b + 4] >> 1);
          }
          off += 9 + bytes[off + 8];
        }
        if (off < p + 188 && es.length < 400 * 1024) {
          es.add(Uint8List.sublistView(bytes, off, p + 188));
        }
      }
    }
    // The richest audio track (most speakers; the first on a tie).
    ({String codec, String? layout, int? channels})? audio;
    for (final e in audioKind.entries) {
      final data = audioEs[e.key]?.takeBytes() ?? Uint8List(0);
      final a = audioFrom(e.value, data);
      if (a == null) continue;
      if (audio == null || (a.channels ?? 0) > (audio.channels ?? 0)) {
        audio = a;
      }
    }
    if (videoPid == null) {
      return ProbeResult(
          ok: true,
          at: at,
          codec: null,
          audioLayout: audio?.layout,
          audioCodec: audio?.codec,
          audioChannels: audio?.channels);
    }
    final hevc = videoType == 0x24;
    final dims = _findSps(es.takeBytes(), hevc);
    return ProbeResult(
      ok: true,
      at: at,
      width: dims?.$1,
      height: dims?.$2,
      fps: _fpsFromPts(pts),
      codec: hevc ? 'HEVC' : 'H.264',
      audioLayout: audio?.layout,
      audioCodec: audio?.codec,
      audioChannels: audio?.channels,
    );
  }

  /// Kinds of audio track [audioFrom] reads.
  static const kindMpegAudio = 1,
      kindAdts = 2,
      kindLatm = 3,
      kindDolby = 4,
      kindDts = 5;

  /// The audio kind of a PMT entry ([type] + its descriptors in
  /// [from]..[to]), or null for anything that isn't audio. DVB carries
  /// Dolby and DTS as private data (0x06) marked by a descriptor; ATSC by
  /// their own stream types.
  static int? _audioKind(int type, Uint8List b, int from, int to) {
    switch (type) {
      case 0x03 || 0x04:
        return kindMpegAudio;
      case 0x0F:
        return kindAdts;
      case 0x11:
        return kindLatm;
      case 0x81 || 0x87:
        return kindDolby;
      case 0x82:
        return kindDts;
      case 0x06:
        for (var d = from; d + 2 <= to;) {
          final tag = b[d], len = b[d + 1];
          if (tag == 0x6A || tag == 0x7A) return kindDolby;
          if (tag == 0x7B) return kindDts;
          if (tag == 0x05 && len >= 4 && d + 6 <= to) {
            final id = String.fromCharCodes(b, d + 2, d + 6);
            if (id == 'AC-3' || id == 'EAC3') return kindDolby;
            if (id.startsWith('DTS')) return kindDts;
          }
          d += 2 + len;
        }
        return null;
    }
    return null;
  }

  /// Codec, speaker layout (`5.1`) and speaker count (with the LFE) from the
  /// first frame headers of one audio track; layout and count null when
  /// the header doesn't say (LATM, DTS) or no frame was found.
  @visibleForTesting
  static ({String codec, String? layout, int? channels})? audioFrom(
      int kind, Uint8List d) {
    switch (kind) {
      case kindAdts:
        for (var i = 0; i + 7 <= d.length; i++) {
          if (d[i] != 0xFF || (d[i + 1] & 0xF6) != 0xF0) continue;
          if ((d[i + 2] >> 2) & 0x0F > 12) continue;
          final len =
              ((d[i + 3] & 0x03) << 11) | (d[i + 4] << 3) | (d[i + 5] >> 5);
          if (len < 7) continue;
          // The next frame must follow, when it's in the bytes read.
          final next = i + len;
          if (next + 2 <= d.length &&
              (d[next] != 0xFF || (d[next + 1] & 0xF6) != 0xF0)) {
            continue;
          }
          final cfg = ((d[i + 2] & 0x01) << 2) | (d[i + 3] >> 6);
          return switch (cfg) {
            0 => (codec: 'AAC', layout: null, channels: null),
            7 => (codec: 'AAC', layout: '7.1', channels: 8),
            6 => (codec: 'AAC', layout: '5.1', channels: 6),
            _ => (codec: 'AAC', layout: '$cfg.0', channels: cfg),
          };
        }
        return (codec: 'AAC', layout: null, channels: null);
      case kindLatm:
        return (codec: 'AAC', layout: null, channels: null);
      case kindDts:
        return (codec: 'DTS', layout: null, channels: null);
      case kindMpegAudio:
        for (var i = 0; i + 4 <= d.length; i++) {
          if (d[i] != 0xFF || (d[i + 1] & 0xE0) != 0xE0) continue;
          final layer = (d[i + 1] >> 1) & 0x03;
          final bitrate = d[i + 2] >> 4;
          if (layer == 0 || bitrate == 0 || bitrate == 15) continue;
          if ((d[i + 2] >> 2) & 0x03 == 3) continue;
          final mono = d[i + 3] >> 6 == 3;
          return (
            codec: layer == 1 ? 'MP3' : 'MP2',
            layout: mono ? '1.0' : '2.0',
            channels: mono ? 1 : 2,
          );
        }
        return (codec: 'MP2', layout: null, channels: null);
      case kindDolby:
        for (var i = 0; i + 8 <= d.length; i++) {
          if (d[i] != 0x0B || d[i + 1] != 0x77) continue;
          final bsid = d[i + 5] >> 3;
          int acmod, lfe;
          String codec;
          if (bsid > 10 && bsid <= 16) {
            // E-AC-3: acmod and lfeon right after fscod / numblkscod.
            codec = 'E-AC-3';
            acmod = (d[i + 4] >> 1) & 0x07;
            lfe = d[i + 4] & 0x01;
          } else if (bsid <= 8) {
            // AC-3 BSI: acmod, mix levels that depend on it, then lfeon.
            codec = 'AC-3';
            final bits = _Bits(Uint8List.sublistView(d, i + 6));
            try {
              acmod = bits.u(3);
              if (acmod & 0x1 != 0 && acmod != 0x1) bits.skip(2);
              if (acmod & 0x4 != 0) bits.skip(2);
              if (acmod == 0x2) bits.skip(2);
              lfe = bits.u(1);
            } on FormatException {
              continue;
            }
          } else {
            continue;
          }
          const fronts = [2, 1, 2, 3, 3, 4, 4, 5];
          final n = fronts[acmod];
          return (codec: codec, layout: '$n.$lfe', channels: n + lfe);
        }
        return (codec: 'Dolby', layout: null, channels: null);
    }
    return null;
  }

  static int _secLen(Uint8List b, int t) =>
      t + 2 < b.length ? ((b[t + 1] & 0x0F) << 8) | b[t + 2] : 0;

  static double? _fpsFromPts(List<int> pts) {
    if (pts.length < 4) return null;
    final sorted = [...pts]..sort();
    final gaps = <int>[
      for (var i = 1; i < sorted.length; i++)
        if (sorted[i] - sorted[i - 1] > 0) sorted[i] - sorted[i - 1]
    ]..sort();
    if (gaps.isEmpty) return null;
    final gap = gaps[gaps.length ~/ 2];
    final fps = 90000 / gap;
    if (fps < 10 || fps > 130) return null;
    // A field-coded 25i stream reports 50 PES per second, as viewers count it.
    return (fps * 100).roundToDouble() / 100;
  }

  static (int, int)? _findSps(Uint8List es, bool hevc) {
    for (var i = 0; i + 4 < es.length; i++) {
      if (es[i] != 0 || es[i + 1] != 0 || es[i + 2] != 1) continue;
      final h = es[i + 3];
      final type = hevc ? (h >> 1) & 0x3F : h & 0x1F;
      if (type != (hevc ? 33 : 7)) continue;
      var end = i + 3;
      while (end + 2 < es.length &&
          !(es[end] == 0 && es[end + 1] == 0 && es[end + 2] == 1)) {
        end++;
      }
      final rbsp =
          _unescape(Uint8List.sublistView(es, i + (hevc ? 5 : 4), end));
      try {
        return hevc ? _hevcSps(rbsp) : _avcSps(rbsp);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Uint8List _unescape(Uint8List b) {
    final out = BytesBuilder(copy: false);
    var zeros = 0;
    for (final x in b) {
      if (zeros >= 2 && x == 3) {
        zeros = 0;
        continue;
      }
      out.addByte(x);
      zeros = x == 0 ? zeros + 1 : 0;
    }
    return out.takeBytes();
  }

  static (int, int) _avcSps(Uint8List b) {
    final r = _Bits(b);
    final profile = r.u(8);
    r.u(16); // constraint flags + level
    r.ue();
    if (const {100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135}
        .contains(profile)) {
      final chroma = r.ue();
      if (chroma == 3) r.u(1);
      r.ue();
      r.ue();
      r.u(1);
      if (r.u(1) == 1) {
        for (var i = 0; i < (chroma != 3 ? 8 : 12); i++) {
          if (r.u(1) == 1) {
            var last = 8, next = 8;
            for (var j = 0; j < (i < 6 ? 16 : 64); j++) {
              if (next != 0) next = (last + r.se() + 256) % 256;
              last = next == 0 ? last : next;
            }
          }
        }
      }
    }
    r.ue();
    final poc = r.ue();
    if (poc == 0) {
      r.ue();
    } else if (poc == 1) {
      r.u(1);
      r.se();
      r.se();
      final n = r.ue();
      for (var i = 0; i < n; i++) {
        r.se();
      }
    }
    r.ue();
    r.u(1);
    final wMbs = r.ue() + 1;
    final hMaps = r.ue() + 1;
    final frameMbsOnly = r.u(1);
    if (frameMbsOnly == 0) r.u(1);
    r.u(1);
    var cl = 0, cr = 0, ct = 0, cb = 0;
    if (r.u(1) == 1) {
      cl = r.ue();
      cr = r.ue();
      ct = r.ue();
      cb = r.ue();
    }
    final w = wMbs * 16 - (cl + cr) * 2;
    final h =
        (2 - frameMbsOnly) * hMaps * 16 - (ct + cb) * 2 * (2 - frameMbsOnly);
    return (w, h);
  }

  static (int, int) _hevcSps(Uint8List b) {
    final r = _Bits(b);
    r.u(4);
    final subLayers = r.u(3);
    r.u(1);
    // profile_tier_level: general part = 88 bits + level 8.
    r.skip(88);
    r.u(8);
    final profilePresent = <bool>[];
    final levelPresent = <bool>[];
    for (var i = 0; i < subLayers; i++) {
      profilePresent.add(r.u(1) == 1);
      levelPresent.add(r.u(1) == 1);
    }
    if (subLayers > 0) {
      for (var i = subLayers; i < 8; i++) {
        r.u(2);
      }
    }
    for (var i = 0; i < subLayers; i++) {
      if (profilePresent[i]) r.skip(88);
      if (levelPresent[i]) r.u(8);
    }
    r.ue();
    final chroma = r.ue();
    if (chroma == 3) r.u(1);
    var w = r.ue();
    var h = r.ue();
    if (r.u(1) == 1) {
      final sub = chroma == 1 || chroma == 2 ? 2 : 1;
      final subH = chroma == 1 ? 2 : 1;
      final l = r.ue(), rr = r.ue(), t = r.ue(), bb = r.ue();
      w -= (l + rr) * sub;
      h -= (t + bb) * subH;
    }
    return (w, h);
  }
}

class _Bits {
  _Bits(this.b);
  final Uint8List b;
  int pos = 0;

  int u(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      if (pos >> 3 >= b.length) throw const FormatException('end');
      v = (v << 1) | ((b[pos >> 3] >> (7 - (pos & 7))) & 1);
      pos++;
    }
    return v;
  }

  void skip(int n) => pos += n;

  int ue() {
    var zeros = 0;
    while (u(1) == 0) {
      if (++zeros > 31) throw const FormatException('ue');
    }
    return (1 << zeros) - 1 + (zeros == 0 ? 0 : u(zeros));
  }

  int se() {
    final k = ue();
    return k.isOdd ? (k + 1) ~/ 2 : -(k ~/ 2);
  }
}

/// Safety checks before a stream test starts, shown in the warning.
typedef ProbeGate = ({int? maxConnections, int? activeConnections});

/// Where the probe can't run (a Windows desktop works too: plain HTTP).
bool get streamProbeSupported => !kIsWeb && (Platform.isAndroid || usesMediaKit);
