// VesperTV patch: Multiview's frame saver (see ThinningVideoRenderer).
package io.flutter.plugins.videoplayer;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Switch + counter shared by Dart (StatsBridge `setFrameThinning`, main thread) and one player's
 * {@link ThinningVideoRenderer} (playback thread).
 */
public final class FrameThinning {
  private volatile boolean on;
  private final AtomicLong thinned = new AtomicLong();

  public void setOn(boolean value) {
    on = value;
  }

  public boolean isOn() {
    return on;
  }

  /** Frames skipped before decoding since the player was created. */
  public long thinned() {
    return thinned.get();
  }

  void countThinned() {
    thinned.incrementAndGet();
  }
}
