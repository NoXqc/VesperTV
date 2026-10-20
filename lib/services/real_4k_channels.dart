import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Live channels this device has seen decode at real 4K — the gold "4K"
/// tag on the live list and the Timeline guide, shown before a channel
/// plays (owner request, 2026-10-20: IMPlayer has one). Never guessed from
/// the name (see `video_quality.dart`): a channel earns the tag the first
/// time it plays at 2160p, and loses it when it plays lower, so a "4K"
/// channel that's really 1080p never gets it.
class Real4kChannels {
  Real4kChannels._();

  /// Channel ids (`Channel.id`). Widgets listen to repaint their tag.
  static final ValueNotifier<Set<String>> ids = ValueNotifier(const {});

  static StorageService? _storage;

  static void init(StorageService storage) {
    _storage = storage;
    ids.value = storage.getReal4kChannels();
  }

  static bool contains(String channelId) => ids.value.contains(channelId);

  /// What a live channel really decoded at ([width] x [height], 0 when
  /// unknown). Too small to be a real picture yet (a stream still
  /// starting) = ignored.
  static void record(String channelId, int width, int height) {
    if (height < 360 && width < 640) return;
    final real4k = height >= 2160 || width >= 3800;
    final current = ids.value;
    if (real4k == current.contains(channelId)) return;
    final next = {...current};
    real4k ? next.add(channelId) : next.remove(channelId);
    ids.value = next;
    _storage?.setReal4kChannels(next);
  }
}
