// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
package io.flutter.plugins.videoplayer;

import androidx.media3.common.C;
import androidx.media3.common.Timeline;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.exoplayer.LoadControl;
import androidx.media3.exoplayer.analytics.PlayerId;
import androidx.media3.exoplayer.source.MediaSource.MediaPeriodId;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.ExoTrackSelection;
import androidx.media3.exoplayer.upstream.Allocator;

/** Extra VOD reserve over the main player's existing 500ms live policy. */
@UnstableApi
public final class OnDemandLoadControl implements LoadControl {
  private final DefaultLoadControl delegate;
  private volatile boolean onDemand;

  /**
   * Live buffer (VesperTV Settings > Playback > Live buffer): live playback
   * starts, and restarts after a stall, only once this much is buffered,
   * so short server dropouts play out of the cushion. 0 = the existing
   * 500 ms start.
   */
  private volatile long liveReserveUs = -1;

  /**
   * The app's setting, applied from the very first start of every new main
   * player (the per-player value only arrives after it is ready, too late
   * to build a cushion). -1 per player = use this.
   */
  private static volatile long defaultLiveReserveUs;

  public static void setDefaultLiveReserveMs(long ms) {
    defaultLiveReserveUs = Math.max(0, ms) * 1000L;
  }

  /**
   * Movies / episodes: a bigger byte cap than the delegate's on a box with memory to spare
   * (BufferBudget.onDemandBytes; 0 = the delegate's). Media3's default (~140 MB) is 11 s of a
   * 100 Mbit/s 4K remux; the 90 s time target is never reached at that bitrate, so bytes decide
   * (owner, 2026-11-17: remux buffering). Only applies under [minBufferUs].
   */
  private final long onDemandBytes;
  private final long minBufferUs;

  public OnDemandLoadControl(DefaultLoadControl delegate) {
    this(delegate, 0, 0);
  }

  public OnDemandLoadControl(DefaultLoadControl delegate, long onDemandBytes, long minBufferUs) {
    this.delegate = delegate;
    this.onDemandBytes = onDemandBytes;
    this.minBufferUs = minBufferUs;
  }

  /** Send log: the movie byte cap in use, 0 when the delegate's applies. */
  public long onDemandBytesInUse() {
    return onDemand ? onDemandBytes : 0;
  }

  /** Dart supplies Channel.isLive classification; never guess from URL or duration. */
  public void setOnDemand(boolean on) {
    onDemand = on;
  }

  public void setLiveReserveMs(long ms) {
    liveReserveUs = Math.max(0, ms) * 1000L;
  }

  @Override
  public boolean shouldStartPlayback(Parameters p) {
    long reserveUs = onDemand
        ? (p.rebuffering ? 10_000_000L : 5_000_000L)
        : (liveReserveUs >= 0 ? liveReserveUs : defaultLiveReserveUs);
    if (reserveUs <= 0 || p.bufferedDurationUs / p.playbackSpeed >= reserveUs) {
      return delegate.shouldStartPlayback(p);
    }
    // Zero time asks the existing non-zero-threshold delegate whether its
    // byte budget permits starting anyway. Preserve that escape hatch: a
    // high-bitrate file must not deadlock at the unchanged small-device cap.
    return delegate.shouldStartPlayback(new Parameters(
        p.playerId, p.timeline, p.mediaPeriodId, p.playbackPositionUs,
        0, p.playbackSpeed, p.playWhenReady, p.rebuffering,
        C.TIME_UNSET, p.lastRebufferRealtimeMs));
  }

  @Override public void onPrepared(PlayerId id) { delegate.onPrepared(id); }
  @Override public void onTracksSelected(Parameters p, TrackGroupArray groups,
      ExoTrackSelection[] selections) { delegate.onTracksSelected(p, groups, selections); }
  @Override public void onStopped(PlayerId id) { delegate.onStopped(id); }
  @Override public void onReleased(PlayerId id) { delegate.onReleased(id); }
  @Override public Allocator getAllocator(PlayerId id) { return delegate.getAllocator(id); }
  @Override public long getBackBufferDurationUs(PlayerId id) {
    return delegate.getBackBufferDurationUs(id);
  }
  @Override public boolean retainBackBufferFromKeyframe(PlayerId id) {
    return delegate.retainBackBufferFromKeyframe(id);
  }
  @Override public boolean shouldContinueLoading(Parameters p) {
    boolean go = delegate.shouldContinueLoading(p);
    if (go || !onDemand || onDemandBytes <= 0 || p.bufferedDurationUs >= minBufferUs) return go;
    // Under the time target, so the delegate stopped on its byte cap: a movie keeps loading
    // up to its own, bigger one.
    return delegate.getAllocator(p.playerId).getTotalBytesAllocated() < onDemandBytes;
  }
  @Override public boolean shouldContinuePreloading(PlayerId id, Timeline timeline,
      MediaPeriodId period, long bufferedUs) {
    return delegate.shouldContinuePreloading(id, timeline, period, bufferedUs);
  }
}
