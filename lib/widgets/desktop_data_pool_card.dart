import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/media_file_info.dart';
import '../services/desktop_audio.dart';
import 'data_pool_card.dart';

/// Data pool on Windows: the same card as Android's [DataPoolCard], fed
/// from mpv's own properties instead of ExoPlayer's tracks. Polls once a
/// second, only while it's open. Never shows the server address (users post
/// photos of the screen).
class DesktopDataPoolCard extends StatefulWidget {
  const DesktopDataPoolCard(
      {super.key, required this.player, required this.channel, this.since});

  final Player player;
  final Channel channel;

  /// When the stream was opened: a live stream's position stays put, so
  /// "Playing for" counts from this.
  final DateTime? since;

  @override
  State<DesktopDataPoolCard> createState() => _DesktopDataPoolCardState();
}

/// One reading of the mpv properties the card shows ('' = not reported).
class DesktopStreamStats {
  const DesktopStreamStats(this.values);

  static const names = [
    'video-params/w',
    'video-params/h',
    'video-params/gamma',
    'video-format',
    'container-fps',
    'estimated-vf-fps',
    'video-bitrate',
    'audio-bitrate',
    'audio-codec-name',
    'audio-params/channel-count',
    'audio-params/samplerate',
    'demuxer-cache-duration',
    'frame-drop-count',
    'decoder-frame-drop-count',
    'file-format',
    'hwdec-current',
    'file-size',
  ];

  final Map<String, String> values;

  String operator [](String name) => values[name] ?? '';

  int? integer(String name) => int.tryParse(this[name]);
  double? decimal(String name) => double.tryParse(this[name]);

  static Future<DesktopStreamStats> read(Player player) async {
    final native = player.platform;
    final values = <String, String>{};
    if (native is NativePlayer) {
      for (final name in names) {
        try {
          values[name] = (await native.getProperty(name)).trim();
        } catch (_) {
          // Not available for this stream (no video, not yet decoded…).
        }
      }
    }
    return DesktopStreamStats(values);
  }

  /// mpv's `file-format` ("hls,applehttp", "mpegts", "matroska,webm"…).
  String get container {
    final f = this['file-format'].toLowerCase();
    if (f.contains('hls') || f.contains('applehttp')) return 'HLS';
    if (f.contains('dash')) return 'DASH';
    if (f.contains('mpegts')) return 'MPEG-TS';
    if (f.contains('matroska')) return 'MKV';
    if (f.contains('mp4') || f.contains('mov')) return 'MP4';
    return f.isEmpty ? tr('Direct stream') : f.split(',').first.toUpperCase();
  }

  /// mpv's transfer function: PQ = HDR10, HLG, else SDR (null = no video).
  String? get hdr => switch (this['video-params/gamma'].toLowerCase()) {
        '' => null,
        'pq' => 'HDR10',
        'hlg' => 'HLG',
        _ => 'SDR',
      };

  /// "Hardware (d3d11va)" or "Software" (mpv's `hwdec-current`).
  String? get decoder {
    final hw = this['hwdec-current'];
    if (this['video-format'].isEmpty) return null;
    return hw.isEmpty || hw == 'no'
        ? tr('Software')
        : tr('Hardware ({api})', {'api': hw});
  }
}

class _DesktopDataPoolCardState extends State<DesktopDataPoolCard> {
  DesktopStreamStats? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final stats = await DesktopStreamStats.read(widget.player);
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    const row = DataPoolFrame.row;
    if (s == null) return const DataPoolFrame(read: false, left: [], right: []);
    final notReported = tr('Not reported by the stream');
    final player = widget.player;
    final w = s.integer('video-params/w'), h = s.integer('video-params/h');
    final declaredFps = s.decimal('container-fps');
    final measuredFps = s.decimal('estimated-vf-fps');
    final videoParts = [
      if (w != null && h != null) '$w×$h',
      if (declaredFps != null && declaredFps > 0)
        '${declaredFps.toStringAsFixed(2)} fps'
      else if (measuredFps != null && measuredFps > 0)
        '${measuredFps.toStringAsFixed(2)} fps ${tr('(measured)')}',
      DataPoolCard.codecName(s['video-format']),
    ].whereType<String>().where((p) => p.isNotEmpty).toList();
    final sampleRate = s.integer('audio-params/samplerate');
    final audioParts = [
      DataPoolCard.codecName(s['audio-codec-name']),
      DataPoolCard.channelsName(s.integer('audio-params/channel-count')),
      if (sampleRate != null && sampleRate > 0)
        '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz',
      DataPoolCard.rateName(s.integer('audio-bitrate')),
    ].whereType<String>().where((p) => p.isNotEmpty).toList();
    final heights = {
      for (final t in player.state.tracks.video)
        if ((t.h ?? 0) > 0) t.h!
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final audioTracks = DesktopAudio.tracksOf(player);
    final languages = {
      for (final t in audioTracks)
        if ((t.language ?? '').isNotEmpty && t.language != 'und')
          t.language!.toUpperCase()
    };
    final dropped = (s.integer('frame-drop-count') ?? 0) +
        (s.integer('decoder-frame-drop-count') ?? 0);
    final cache = s.decimal('demuxer-cache-duration');
    final onDemand = !widget.channel.isLive;
    final fileSize =
        onDemand ? MediaFileInfo.formatSize(s.integer('file-size')) : null;
    final https = widget.channel.url.toLowerCase().startsWith('https');
    final since = widget.since;
    return DataPoolFrame(
      read: true,
      left: [
        row(tr('Video'),
            videoParts.isEmpty ? notReported : videoParts.join(' · ')),
        row(
            tr('Stream bitrate'),
            DataPoolCard.rateName(s.integer('video-bitrate')) == null
                ? notReported
                : '${DataPoolCard.rateName(s.integer('video-bitrate'))} '
                    '${tr('(measured)')}'),
        if (s['frame-drop-count'].isNotEmpty ||
            s['decoder-frame-drop-count'].isNotEmpty)
          row(tr('Dropped frames'), '$dropped'),
        if (w != null && h != null && w > 0 && h > 0)
          row(tr('Picture'),
              '$w×$h · ${DataPoolCard.aspectName(Size(w.toDouble(), h.toDouble()))}'),
        if (s.hdr != null) row(tr('Video HDR'), s.hdr!),
        if (s.decoder != null) row(tr('Decoder'), s.decoder!),
        row(
            tr('Quality variants'),
            heights.length > 1
                ? heights.map((h) => '${h}p').join(' · ')
                : tr('One (not adaptive)')),
      ],
      right: [
        row(tr('Audio'),
            audioParts.isEmpty ? notReported : audioParts.join(' · ')),
        if (audioTracks.length > 1)
          row(
              tr('Audio tracks'),
              languages.isEmpty
                  ? '${audioTracks.length}'
                  : '${audioTracks.length} · ${languages.join(', ')}'),
        if (onDemand)
          row(tr('File size'), fileSize ?? tr('File size unavailable')),
        row(tr('Stream'), '${s.container} · ${https ? 'HTTPS' : 'HTTP'}'),
        row(
            tr('Buffered'),
            cache == null
                ? notReported
                : tr('{seconds} s', {'seconds': cache.toStringAsFixed(1)})),
        row(
            tr('State'),
            player.state.buffering
                ? tr('Buffering…')
                : player.state.playing
                    ? tr('Playing for {time}', {
                        'time': DataPoolCard.clockName(onDemand || since == null
                            ? player.state.position
                            : DateTime.now().difference(since))
                      })
                    : tr('Paused')),
      ],
    );
  }
}
