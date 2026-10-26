import '../models/channel.dart';
import 'archive_ready_watch.dart';
import 'storage_service.dart';

/// Windows uses media_kit rather than PlaybackService's controller. Share the
/// existing progress keys so detail pages and Continue Watching see its saves.
class DesktopVodProgress {
  DesktopVodProgress(this.storage) : viewerId = storage.getActiveViewerId();

  final StorageService storage;
  final String viewerId;

  bool accepts(Channel channel) =>
      storage.getActiveViewerId() == viewerId &&
      !channel.isLive &&
      !channel.transientPlayback;

  bool isFraction(Channel channel) =>
      accepts(channel) && storage.isResumeFraction(channel.id);

  /// Null means a tracker fraction needs the actual file duration first.
  Duration? resumePosition(Channel channel, {Duration? duration}) {
    if (!accepts(channel) || storage.isFullyWatched(channel.id)) {
      return Duration.zero;
    }
    final saved = storage.getLastPosition(channel.id);
    if (saved <= 0) return Duration.zero;
    if (isFraction(channel)) {
      if (duration == null || duration <= Duration.zero) return null;
      return Duration(
          milliseconds: (saved /
                  StorageService.resumeFractionScale *
                  duration.inMilliseconds)
              .round()
              .clamp(0, duration.inMilliseconds));
    }
    return Duration(milliseconds: saved);
  }

  Future<void> save(
      Channel channel, Duration position, Duration duration) async {
    if (!accepts(channel) ||
        duration <= Duration.zero ||
        position.isNegative ||
        isFraction(channel) ||
        ArchiveReadyWatch.instance.isClip(channel.id, duration)) {
      return;
    }
    // Both keys are captured/written before yielding so a viewer change can't
    // put the second half of this sample into another viewer's profile.
    final writes = [
      storage.setLastPosition(channel.id,
          position.inMilliseconds.clamp(0, duration.inMilliseconds)),
      storage.setLastDuration(channel.id, duration.inMilliseconds),
    ];
    await Future.wait(writes);
  }
}
