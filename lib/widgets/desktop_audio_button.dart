import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/app_preferences.dart';
import '../services/audio_delay.dart';
import '../services/desktop_audio.dart';
import '../services/storage_service.dart';
import 'audio_delay_adjuster.dart';
import 'tv_menu_tile.dart';

/// The Windows player bar's Audio button: the file's audio tracks (when it
/// has two or more, same labels as the Android picker) and Audio sync. A
/// movie / episode remembers the picked track for next time
/// ([DesktopAudio.remember]).
class DesktopAudioButton extends StatefulWidget {
  const DesktopAudioButton(
      {super.key, required this.player, required this.channel});

  final mk.Player player;
  final Channel channel;

  @override
  State<DesktopAudioButton> createState() => _DesktopAudioButtonState();
}

class _DesktopAudioButtonState extends State<DesktopAudioButton> {
  StreamSubscription<mk.Tracks>? _tracksSub;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    // The track list fills once the file's header is read.
    _tracksSub = widget.player.stream.tracks.listen((_) {
      if (!mounted) return;
      if (!_logged && DesktopAudio.tracksOf(widget.player).isNotEmpty) {
        _logged = true;
        DesktopAudio.logTracks(widget.channel, widget.player);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tracksSub?.cancel();
    super.dispose();
  }

  Future<void> _openPicker() async {
    final tracks = DesktopAudio.tracksOf(widget.player);
    final currentId = widget.player.state.track.audio.id;
    final delay = context.read<AppPreferences>().audioDelayMs;
    // An mk.AudioTrack, or 'sync'.
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.8),
          // Not lazy: autofocus needs the selected track's tile built.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(tr('Audio Track'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                if (tracks.length > 1)
                  for (final (i, track) in tracks.indexed)
                    TvMenuTile(
                      autofocus: track.id == currentId,
                      leading: Icon(
                        track.id == currentId
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: track.id == currentId
                            ? Colors.amber
                            : Colors.white54,
                      ),
                      title: DesktopAudio.label(track, i),
                      onTap: () => Navigator.of(sheet).pop(track),
                    ),
                TvMenuTile(
                  autofocus: tracks.length < 2,
                  leading: const Icon(Icons.av_timer, color: Colors.white54),
                  title: tr('Audio sync'),
                  subtitle: AudioDelay.label(delay),
                  onTap: () => Navigator.of(sheet).pop('sync'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == 'sync') {
      await showAudioDelayAdjuster(context);
      return;
    }
    if (chosen is! mk.AudioTrack) return;
    final storage = context.read<StorageService>();
    final viewer = storage.getActiveViewerId();
    await widget.player.setAudioTrack(chosen);
    if (mounted && storage.getActiveViewerId() == viewer) {
      await DesktopAudio.remember(storage, widget.channel, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.multitrack_audio, color: Colors.white),
      tooltip: tr('Audio track'),
      onPressed: _openPicker,
    );
  }
}
