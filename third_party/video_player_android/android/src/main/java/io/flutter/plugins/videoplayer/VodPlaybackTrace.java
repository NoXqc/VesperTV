package io.flutter.plugins.videoplayer;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.analytics.AnalyticsListener;
import androidx.media3.exoplayer.source.LoadEventInfo;
import androidx.media3.exoplayer.source.MediaLoadData;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Bounded, credential-free evidence for post-seek stalls; never changes playback. Movies /
 * episodes (5 min after configure or a seek) and catch-up (30 min: a programme is long and the
 * user may leave the app and come back; Catchup buffering report LOG-QFRUAZ, 2026-11-04).
 */
@UnstableApi
final class VodPlaybackTrace implements AnalyticsListener {
  private static final AtomicInteger NEXT_ID = new AtomicInteger();
  private static final long WINDOW_MS = 5 * 60_000L;
  private static final long CATCHUP_WINDOW_MS = 30 * 60_000L;
  private final int id = NEXT_ID.incrementAndGet();
  private final ExoPlayer player;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private boolean enabled;
  private boolean catchup;
  private boolean disposed;
  private long untilMs;
  private int events;
  private final Runnable tick = new Runnable() {
    @Override public void run() {
      if (!active()) return;
      write("sample");
      handler.postDelayed(this, catchup ? 30_000 : 10_000);
    }
  };

  VodPlaybackTrace(ExoPlayer player) {
    this.player = player;
  }

  void setEnabled(boolean on) {
    if (!on && catchup) return; // VOD's "off" must not end a catch-up trace
    enabled = on;
    handler.removeCallbacks(tick);
    if (on) start("configure");
  }

  /** Catch-up (finite) playback: same evidence, longer window. */
  void setCatchup(boolean on) {
    catchup = on;
    enabled = on;
    handler.removeCallbacks(tick);
    if (on) start("configure");
  }

  void seekRequested(long targetMs) {
    if (enabled) start("seek targetMs=" + targetMs);
  }

  private void start(String event) {
    if (disposed) return;
    untilMs = SystemClock.elapsedRealtime() + (catchup ? CATCHUP_WINDOW_MS : WINDOW_MS);
    events = 0;
    handler.removeCallbacks(tick);
    write(event);
    handler.postDelayed(tick, 10_000);
  }

  private boolean active() {
    return enabled && !disposed && SystemClock.elapsedRealtime() < untilMs;
  }

  private void event(String event) {
    if (active() && events++ < (catchup ? 240 : 120)) write(event);
  }

  private void write(String event) {
    Log.i("VesperPlayback", "id=" + id + (catchup ? " kind=catchup" : "") + " event=" + event
        + " state=" + player.getPlaybackState()
        + " ready=" + player.getPlayWhenReady() + " playing=" + player.isPlaying()
        + " loading=" + player.isLoading() + " posMs=" + player.getCurrentPosition()
        + " aheadMs=" + player.getTotalBufferedDuration());
  }

  @Override public void onPlaybackStateChanged(EventTime time, int state) { event("state"); }
  @Override public void onPlayWhenReadyChanged(EventTime time, boolean ready, int reason) {
    event("playWhenReady reason=" + reason);
  }
  @Override public void onAudioUnderrun(EventTime time, int bytes, long bufferMs, long elapsedMs) {
    event("audioUnderrun outputBytes=" + bytes + " outputMs=" + bufferMs
        + " sinceFeedMs=" + elapsedMs);
  }
  @Override public void onPositionDiscontinuity(EventTime time, Player.PositionInfo oldPosition,
      Player.PositionInfo newPosition, int reason) {
    event("position reason=" + reason);
  }

  // No URLs: only the error's type/code and how long the request had run.
  @Override public void onLoadError(EventTime time, LoadEventInfo info, MediaLoadData data,
      IOException error, boolean wasCanceled) {
    Throwable root = error;
    while (root.getCause() != null && root.getCause() != root) root = root.getCause();
    event("loadError " + error.getClass().getSimpleName() + "/" + root.getClass().getSimpleName()
        + " afterMs=" + info.loadDurationMs + " bytes=" + info.bytesLoaded
        + (wasCanceled ? " canceled" : ""));
  }

  @Override public void onPlayerError(EventTime time, PlaybackException error) {
    event("playerError " + error.getErrorCodeName());
  }

  void dispose() {
    disposed = true;
    handler.removeCallbacks(tick);
  }
}
