import 'package:flutter/material.dart';

import '../services/real_4k_channels.dart';
import 'gold_tag.dart';

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
        return GoldTag(
          label: '4K',
          compact: compact,
          margin: compact ? null : const EdgeInsets.symmetric(horizontal: 4),
        );
      },
    );
  }
}
