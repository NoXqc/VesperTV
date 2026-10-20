import 'package:flutter/material.dart';

import '../services/real_4k_channels.dart';

/// Small gold "4K" pill for a live channel that has really played at 4K on
/// this device ([Real4kChannels]); nothing otherwise.
class Real4kTag extends StatelessWidget {
  const Real4kTag({super.key, required this.channelId, this.compact = false});

  final String channelId;

  /// Smaller, no side margin: a corner badge over a row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: Real4kChannels.ids,
      builder: (context, ids, _) {
        if (!ids.contains(channelId)) return const SizedBox.shrink();
        return Container(
          margin: compact ? null : const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 5, vertical: compact ? 0 : 1),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber, width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '4K',
            style: TextStyle(
                color: Colors.amber,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.bold,
                height: 1.1),
          ),
        );
      },
    );
  }
}
