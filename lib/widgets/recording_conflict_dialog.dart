import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/recording_service.dart';
import 'mode_button.dart';

/// Before tuning another channel of a playlist whose only connection a
/// recording holds: true = stop the recording and play.
Future<bool> showRecordingConflictDialog(
    BuildContext context, RecordingEntry rec) async {
  final stop = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF15151A),
      title: Text(tr('Recording in progress')),
      content: SizedBox(
        width: 460,
        child: Text(tr(
            '{title} is recording on {channel}. Your playlist allows one connection, so playing another of its channels stops the recording.',
            {'title': rec.title, 'channel': rec.channelName})),
      ),
      // ModeButton: clear D-pad focus (see CheckUpdatesScreen).
      actions: [
        ModeButton(
          label: tr('Cancel'),
          selected: false,
          onTap: () => Navigator.of(context).pop(false),
        ),
        ModeButton(
          icon: Icons.stop_circle_outlined,
          label: tr('Stop recording'),
          selected: false,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return stop ?? false;
}
