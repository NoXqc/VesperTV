// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.C;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.Timeline;
import androidx.media3.common.Tracks;
import androidx.media3.exoplayer.ExoPlayer;

public abstract class ExoPlayerEventListener implements Player.Listener {
  static final long DURATION_UNSET_INITIALIZATION_TIMEOUT_MS = 2000;
  // A live IPTV relay occasionally hands ExoPlayer a corrupted/reordered
  // segment, which media3 (as of ~1.9) now surfaces as a fatal
  // PlaybackException (an audio AudioSink$UnexpectedDiscontinuityException,
  // or a video MediaCodecRenderer IndexOutOfBoundsException from garbled
  // buffer offsets — confirmed on real hardware, both happening ~20-40s
  // into playback regardless of channel, bitrate, or device) instead of
  // recovering silently like older versions did. Nothing upstream of this
  // listener ever retried on a fatal error, so every one of these
  // permanently froze the affected player until a manual reload. The
  // ERROR_CODE_BEHIND_LIVE_WINDOW case below already re-prepares the same
  // ExoPlayer instance in place (no Surface/texture is touched, so there's
  // no reload-style flash) — this generalizes that same recovery to any
  // fatal error, capped so a genuinely broken stream (bad URL, auth
  // failure) still gives up and surfaces to Dart instead of retry-looping
  // forever.
  private static final long ERROR_RETRY_WINDOW_MS = 10_000;
  private static final int MAX_ERRORS_IN_WINDOW = 3;
  private long errorWindowStartMs = 0;
  private int errorsInWindow = 0;
  private boolean isInitialized = false;
  private boolean isWaitingForValidDuration = false;
  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private final Runnable initializationFallback =
      () -> {
        if (!isInitialized && isWaitingForValidDuration) {
          isWaitingForValidDuration = false;
          isInitialized = true;
          sendInitialized();
        }
      };
  private final Runnable recover;
  protected final ExoPlayer exoPlayer;
  protected final VideoPlayerCallbacks events;

  /** Delay before an in-place error recovery; 0 = immediately. */
  protected long errorRetryDelayMs() {
    return 0;
  }

  /**
   * Whether a live stream reaching STATE_ENDED (the server closed a progressive stream) should be
   * reconnected in place instead of reported as ended.
   */
  protected boolean reconnectWhenLiveEnds() {
    return false;
  }

  /**
   * Whether a playing stream whose video output stops (no new frames for ~4 s while the clock
   * keeps moving) should be reconnected in place. Seen on a Fire Stick's hardware decoder in
   * Multiview: the picture froze, audio played on, and ~2 min later the undecoded video filled the
   * load budget, audio starved and the player flipped BUFFERING/READY forever. media3's own
   * stuck-player check never fires for this because the (audio) clock is still advancing.
   */
  protected boolean recoverFrozenVideo() {
    return false;
  }

  /** Counts a failure in the retry window; true if another in-place recovery is allowed. */
  private boolean allowRetry() {
    long now = SystemClock.elapsedRealtime();
    if (now - errorWindowStartMs > ERROR_RETRY_WINDOW_MS) {
      errorWindowStartMs = now;
      errorsInWindow = 0;
    }
    errorsInWindow++;
    return errorsInWindow <= MAX_ERRORS_IN_WINDOW;
  }

  private void scheduleRecovery() {
    mainHandler.removeCallbacks(recover);
    long delay = errorRetryDelayMs();
    if (delay <= 0) {
      recover.run();
    } else {
      mainHandler.postDelayed(recover, delay);
    }
  }

  protected enum RotationDegrees {
    ROTATE_0(0),
    ROTATE_90(90),
    ROTATE_180(180),
    ROTATE_270(270);

    private final int degrees;

    RotationDegrees(int degrees) {
      this.degrees = degrees;
    }

    public static RotationDegrees fromDegrees(int degrees) {
      for (RotationDegrees rotationDegrees : RotationDegrees.values()) {
        if (rotationDegrees.degrees == degrees) {
          return rotationDegrees;
        }
      }
      throw new IllegalArgumentException("Invalid rotation degrees specified: " + degrees);
    }

    public int getDegrees() {
      return this.degrees;
    }
  }

  public ExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @NonNull VideoPlayerCallbacks events) {
    this.exoPlayer = exoPlayer;
    this.events = events;
    this.recover =
        () -> {
          exoPlayer.seekToDefaultPosition();
          exoPlayer.prepare();
        };
    if (recoverFrozenVideo()) {
      mainHandler.postDelayed(frozenVideoCheck, FROZEN_CHECK_INTERVAL_MS);
    }
  }

  // Frozen-video watchdog (see recoverFrozenVideo): rendered video frames and position, sampled
  // every 2 s; frozen = no new frame across two samples (~4 s) while the position moved >= 3 s.
  private static final long FROZEN_CHECK_INTERVAL_MS = 2000;
  private long[] olderSample;
  private long[] lastSample;
  private final Runnable frozenVideoCheck =
      new Runnable() {
        @Override
        public void run() {
          androidx.media3.exoplayer.DecoderCounters counters = exoPlayer.getVideoDecoderCounters();
          long frames = -1;
          if (counters != null) {
            counters.ensureUpdated();
            frames = counters.renderedOutputBufferCount;
          }
          long[] now = {frames, exoPlayer.getCurrentPosition()};
          if (olderSample != null
              && exoPlayer.isPlaying()
              && frames >= 0
              && now[0] == olderSample[0]
              && now[1] - olderSample[1] >= 3000
              && allowRetry()) {
            // stop() closes the connection first, so the retry delay keeps the provider's
            // connection count honest (see TextureExoPlayerEventListener.errorRetryDelayMs).
            exoPlayer.stop();
            scheduleRecovery();
            olderSample = null;
            lastSample = null;
          } else {
            olderSample = lastSample;
            lastSample = now;
          }
          mainHandler.postDelayed(this, FROZEN_CHECK_INTERVAL_MS);
        }
      };

  protected abstract void sendInitialized();

  /** Cancels pending initialization callbacks when the player is disposed. */
  public void dispose() {
    isWaitingForValidDuration = false;
    mainHandler.removeCallbacks(initializationFallback);
    mainHandler.removeCallbacks(recover);
    mainHandler.removeCallbacks(frozenVideoCheck);
  }

  private boolean hasValidDuration() {
    return exoPlayer.getDuration() != C.TIME_UNSET;
  }

  private boolean shouldWaitForValidDuration() {
    return !exoPlayer.isCurrentMediaItemLive() && !exoPlayer.isCurrentMediaItemDynamic();
  }

  private void maybeSendInitialized() {
    if (isInitialized) {
      return;
    }

    if (!hasValidDuration() && shouldWaitForValidDuration()) {
      if (!isWaitingForValidDuration) {
        isWaitingForValidDuration = true;
        mainHandler.postDelayed(initializationFallback, DURATION_UNSET_INITIALIZATION_TIMEOUT_MS);
      }
      return;
    }

    isWaitingForValidDuration = false;
    isInitialized = true;
    mainHandler.removeCallbacks(initializationFallback);
    sendInitialized();
  }

  @Override
  public void onPlaybackStateChanged(final int playbackState) {
    PlatformPlaybackState platformState = PlatformPlaybackState.UNKNOWN;
    switch (playbackState) {
      case Player.STATE_BUFFERING:
        platformState = PlatformPlaybackState.BUFFERING;
        break;
      case Player.STATE_READY:
        platformState = PlatformPlaybackState.READY;
        maybeSendInitialized();
        break;
      case Player.STATE_ENDED:
        if (reconnectWhenLiveEnds()
            && (exoPlayer.isCurrentMediaItemLive() || exoPlayer.getDuration() == C.TIME_UNSET)
            && allowRetry()) {
          // Reported to Dart as buffering, not ENDED — ENDED would mark the
          // controller completed/paused on the Dart side.
          platformState = PlatformPlaybackState.BUFFERING;
          scheduleRecovery();
        } else {
          platformState = PlatformPlaybackState.ENDED;
        }
        break;
      case Player.STATE_IDLE:
        platformState = PlatformPlaybackState.IDLE;
        break;
    }
    events.onPlaybackStateChanged(platformState);
  }

  @Override
  public void onTimelineChanged(@NonNull Timeline timeline, int reason) {
    if (isWaitingForValidDuration && exoPlayer.getPlaybackState() == Player.STATE_READY) {
      maybeSendInitialized();
    }
  }

  @Override
  public void onPlayerError(@NonNull final PlaybackException error) {
    if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
      // See
      // https://exoplayer.dev/live-streaming.html#behindlivewindowexception-and-error_code_behind_live_window
      exoPlayer.seekToDefaultPosition();
      exoPlayer.prepare();
      return;
    }

    if (allowRetry()) {
      // In-place recovery: re-preparing the same ExoPlayer instance resets
      // its internal renderers (including recreating the MediaCodec
      // decoders) without releasing the Surface/texture, so playback just
      // briefly blanks and resumes near the live edge instead of a full
      // widget-level reload. Delayed for Multiview — see
      // TextureExoPlayerEventListener.errorRetryDelayMs.
      scheduleRecovery();
    } else {
      events.onError("VideoError", "Video player had error " + error, null);
    }
  }

  @Override
  public void onIsPlayingChanged(boolean isPlaying) {
    events.onIsPlayingStateUpdate(isPlaying);
  }

  @Override
  public void onTracksChanged(@NonNull Tracks tracks) {
    // Find the currently selected audio track and notify
    String selectedAudioTrackId = findSelectedAudioTrackId(tracks);
    events.onAudioTrackChanged(selectedAudioTrackId);

    // Find the currently selected video track and notify
    String selectedVideoTrackId = findSelectedVideoTrackId(tracks);
    events.onVideoTrackChanged(selectedVideoTrackId);
  }

  /**
   * Finds the ID of the currently selected audio track.
   *
   * @param tracks The current tracks
   * @return The track ID in format "groupIndex_trackIndex", or null if no audio track is selected
   */
  @Nullable
  private String findSelectedAudioTrackId(@NonNull Tracks tracks) {
    // Keep this ID format in sync with android_video_player.dart::_parseAndroidTrackId.
    int groupIndex = 0;
    for (Tracks.Group group : tracks.getGroups()) {
      if (group.getType() == C.TRACK_TYPE_AUDIO && group.isSelected()) {
        // Find the selected track within this group
        for (int i = 0; i < group.length; i++) {
          if (group.isTrackSelected(i)) {
            return groupIndex + "_" + i;
          }
        }
      }
      groupIndex++;
    }
    return null;
  }

  /**
   * Finds the ID of the currently selected video track.
   *
   * @param tracks The current tracks
   * @return The track ID in format "groupIndex_trackIndex", or null if no video track is selected
   */
  @Nullable
  private String findSelectedVideoTrackId(@NonNull Tracks tracks) {
    // Keep this ID format in sync with android_video_player.dart::_parseAndroidTrackId.
    int groupIndex = 0;
    for (Tracks.Group group : tracks.getGroups()) {
      if (group.getType() == C.TRACK_TYPE_VIDEO && group.isSelected()) {
        // Find the selected track within this group
        for (int i = 0; i < group.length; i++) {
          if (group.isTrackSelected(i)) {
            return groupIndex + "_" + i;
          }
        }
      }
      groupIndex++;
    }
    return null;
  }
}
