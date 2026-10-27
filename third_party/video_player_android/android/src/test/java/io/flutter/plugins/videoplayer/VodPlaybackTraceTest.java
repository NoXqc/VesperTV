package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import java.time.Duration;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowLog;
import android.os.Looper;
import static org.robolectric.Shadows.shadowOf;

@UnstableApi
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 30)
public final class VodPlaybackTraceTest {
  private ExoPlayer player;
  private VodPlaybackTrace trace;

  @Before public void setUp() {
    ShadowLog.clear();
    player = mock(ExoPlayer.class);
    when(player.getPlaybackState()).thenReturn(Player.STATE_BUFFERING);
    when(player.getPlayWhenReady()).thenReturn(true);
    when(player.getCurrentPosition()).thenReturn(300_000L);
    when(player.getTotalBufferedDuration()).thenReturn(500L);
    trace = new VodPlaybackTrace(player);
  }

  private int count() { return ShadowLog.getLogsForTag("VesperPlayback").size(); }

  @Test public void livePlaybackDoesNotStartTraceOrTimer() {
    trace.seekRequested(400_000);
    trace.onPlaybackStateChanged(null, Player.STATE_BUFFERING);
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6));
    assertEquals(0, count());
    trace.dispose();
  }

  @Test public void traceShowsIntentAndBufferWithoutMediaIdentifiers() {
    trace.setEnabled(true);
    trace.seekRequested(400_000);
    trace.onAudioUnderrun(null, 1000, 250, 750);
    String message = ShadowLog.getLogsForTag("VesperPlayback").get(count() - 1).msg;
    assertTrue(message.contains("audioUnderrun"));
    assertTrue(message.contains("ready=true"));
    assertTrue(message.contains("state=2"));
    assertTrue(message.contains("aheadMs=500"));
    verify(player, never()).getCurrentMediaItem();
    verify(player, never()).play();
    verify(player, never()).pause();
    trace.dispose();
  }

  @Test public void highFrequencyEventsAndTimerAreBoundedAndDisposeCancels() {
    trace.setEnabled(true);
    for (int i = 0; i < 500; i++) trace.onPlaybackStateChanged(null, Player.STATE_BUFFERING);
    assertEquals(121, count());
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6));
    assertTrue(count() <= 151);
    int stopped = count();
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6));
    assertEquals(stopped, count());
    trace.seekRequested(600_000);
    trace.dispose();
    stopped = count();
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6));
    assertEquals(stopped, count());
  }
}
