import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../services/vod_buffering.dart';
import '../utils/desktop_platform.dart';
import 'tv_dialog_option.dart';

/// Live buffer choices: how much live video is stored before playing (and
/// after a stall). Bigger hides server dropouts, but the channel starts
/// later and plays that much behind live. Shared by Settings > Playback >
/// Live buffer and the player's options row.
const _liveBufferChoices = [
  (0, 'Off'),
  // Native player: fast start, then plays at 96 % until a reserve covers
  // the server's gaps (VideoPlayer.cushionTick).
  (-1, 'Gradual (starts fast, builds up)'),
  (1500, 'Small (1.5 seconds)'),
  (4000, '4 seconds'),
  (8000, '8 seconds'),
  (12000, '12 seconds'),
];

/// The choices on this device: Windows/macOS (mpv) has no Gradual, it plays
/// as Off there.
List<(int, String)> liveBufferChoices() => [
      for (final c in _liveBufferChoices)
        if (c.$1 >= 0 || !isDesktop) c
    ];

/// The full (untranslated) name of [ms], for Settings.
String liveBufferName(int ms) {
  final choices = liveBufferChoices();
  return choices.firstWhere((c) => c.$1 == ms, orElse: () => choices.first).$2;
}

/// A short translated name of [ms] for the player's options row.
String liveBufferShortName(int ms) => switch (ms) {
      < 0 => tr('Gradual'),
      0 => tr('Off'),
      _ => tr('{seconds} s', {
          'seconds': (ms % 1000 == 0
              ? '${ms ~/ 1000}'
              : (ms / 1000).toStringAsFixed(1))
        }),
    };

/// Asks for a live buffer, saves it and makes it every new player's
/// default. Returns the pick, or null when cancelled.
Future<int?> pickLiveBuffer(BuildContext context) async {
  final storage = context.read<StorageService>();
  final current = storage.getLiveBufferMs();
  final picked = await showDialog<int>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(tr('Live buffer')),
      children: [
        for (final (ms, label) in liveBufferChoices())
          TvDialogOption(
            autofocus: ms == current,
            onPressed: () => Navigator.of(dialogContext).pop(ms),
            child: Row(children: [
              Icon(ms == current ? Icons.check_circle : Icons.circle_outlined),
              const SizedBox(width: 12),
              Text(tr(label)),
            ]),
          ),
      ],
    ),
  );
  if (picked == null) return null;
  await storage.setLiveBufferMs(picked);
  await VodBuffering.setLiveBufferDefault(picked);
  return picked;
}
