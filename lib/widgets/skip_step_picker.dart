import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../utils/skip_step.dart';
import 'glass_menu.dart';
import 'tv_dialog_option.dart';

/// The player's options row > Skip (owner, 2026-11-25: "the -/+ skips
/// options ... add the setting in the menu option bar"): the same choice as
/// Settings > Playback > Player > Skip buttons, without leaving the player.
/// Saved for this device at once; the skip buttons and the remote's
/// Rewind / Fast-forward take it on their next press.
Future<void> showSkipStepPicker(BuildContext context) async {
  final storage = context.read<StorageService>();
  final current = SkipStep.seconds;
  final picked = await showGlassMenu<int>(
    context: context,
    builder: (context) => GlassMenuDialog(
      maxWidth: 280,
      title: Text(tr('Skip buttons')),
      children: [
        for (final sec in SkipStep.choices)
          TvDialogOption(
            autofocus: sec == current,
            onPressed: () => Navigator.of(context).pop(sec),
            child: Row(children: [
              Expanded(child: Text(tr('{seconds} s', {'seconds': '$sec'}))),
              if (sec == current)
                const Icon(Icons.check, size: 18, color: Colors.white),
            ]),
          ),
      ],
    ),
  );
  if (picked == null || picked == current) return;
  SkipStep.seconds = picked;
  await storage.setSkipSeconds(picked);
}
