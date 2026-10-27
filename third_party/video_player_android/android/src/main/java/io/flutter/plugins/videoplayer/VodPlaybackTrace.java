package io.flutter.plugins.videoplayer;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.analytics.AnalyticsListener;
import java.util.concurrent.atomic.AtomicInteger;

/** Bounded, credential-free evidence for post-seek stalls; never changes playback. */
@UnstableApi
final class VodPlaybackTrace implements AnalyticsListener {
  private static final AtomicInteger NEXT_ID = new AtomicInteger();
  private static final long WINDOW_MS = 5 * 60_000L;
  private final int id = NEXT_ID.incrementAndGet();
  private final ExoPlayer player;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private boolean enabled;
  private boolean disposed;
  private long untilMs;
  private int events;
  private final Runnable tick = new Runnable() {
    @Override public void run() {
      if (!active()) return;
      write("sample");
      handler.postDelayed(this, 10_000);
    }
  };

  VodPlaybackTrace(ExoPlayer player) {
    this.player = player;
  }

  void setEnabled(boolean on) {
    enabled = on;
    handler.removeCallbacks(tick);
    if (on) start("configure");
  }

  void seekRequested(long targetMs) {
    if (enabled) start("seek targetMs=" + targetMs);
  }

  private void start(String event) {
    if (disposed) return;
    untilMs = SystemClock.elapsedRealtime() + WINDOW_MS;
    events = 0;
    handler.removeCallbacks(tick);
    write(event);
    handler.postDelayed(tick, 10_000);
  }

  private boolean active() {
    return enabled && !disposed && SystemClock.elapsedRealtime() < untilMs;
  }

  private void event(String event) {
    if (active() && events++ < 120) write(event);
  }

  private void write(String event) {
    Log.i("VesperPlayback", "id=" + id + " event=" + event
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

  void dispose() {
    disposed = true;
    handler.removeCallbacks(tick);
  }
}
