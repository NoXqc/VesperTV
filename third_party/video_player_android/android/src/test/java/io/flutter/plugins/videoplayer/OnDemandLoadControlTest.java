package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;

import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Timeline;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.exoplayer.LoadControl.Parameters;
import androidx.media3.exoplayer.analytics.PlayerId;
import androidx.media3.exoplayer.source.MediaSource.MediaPeriodId;
import androidx.media3.exoplayer.source.SinglePeriodTimeline;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.ExoTrackSelection;
import androidx.media3.exoplayer.upstream.Allocation;
import androidx.media3.exoplayer.upstream.PlayerIdAwareAllocator;
import java.util.ArrayList;
import java.util.List;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@UnstableApi
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 30)
public final class OnDemandLoadControlTest {
  private final PlayerId id = new PlayerId("test");
  private final Timeline timeline = new SinglePeriodTimeline(
      3_600_000_000L, true, false, false, null,
      MediaItem.fromUri("https://example.test/movie.mkv"));
  private final List<Allocation> allocations = new ArrayList<>();
  private OnDemandLoadControl control;
  private PlayerIdAwareAllocator allocator;

  @Before public void setUp() {
    control = new OnDemandLoadControl(new DefaultLoadControl.Builder()
        .setBufferDurationsMs(90_000, 120_000, 500, 500)
        .setTargetBufferBytes(2 * C.DEFAULT_BUFFER_SEGMENT_SIZE).build());
    control.onPrepared(id);
    control.onTracksSelected(parameters(0, false, 1), TrackGroupArray.EMPTY,
        new ExoTrackSelection[0]);
    allocator = (PlayerIdAwareAllocator) control.getAllocator(id);
    allocator.setPlayerId(id);
  }

  @After public void tearDown() {
    for (Allocation allocation : allocations) allocator.release(allocation);
    control.onStopped(id);
    control.onReleased(id);
  }

  private Parameters parameters(long bufferUs, boolean rebuffering, float speed) {
    return new Parameters(id, timeline, new MediaPeriodId(timeline.getUidOfPeriod(0)),
        300_000_000L, bufferUs, speed, true, rebuffering, C.TIME_UNSET, C.TIME_UNSET);
  }

  @Test public void finiteDurationDoesNotOptLivePlaybackIntoVodPolicy() {
    assertFalse(control.shouldStartPlayback(parameters(499_999, false, 1)));
    assertTrue(control.shouldStartPlayback(parameters(500_000, false, 1)));
    assertTrue(control.shouldStartPlayback(parameters(500_000, true, 1)));
  }

  @Test public void postSeekWaitsForFiveSecondsInsteadOfRepeatedHalfSecondRestarts() {
    control.setOnDemand(true);
    assertFalse(control.shouldStartPlayback(parameters(500_000, false, 1)));
    assertFalse(control.shouldStartPlayback(parameters(4_999_999, false, 1)));
    assertTrue(control.shouldStartPlayback(parameters(5_000_000, false, 1)));
  }

  @Test public void depletionRequiresTenSecondsBeforeRestarting() {
    control.setOnDemand(true);
    assertFalse(control.shouldStartPlayback(parameters(5_000_000, true, 1)));
    assertFalse(control.shouldStartPlayback(parameters(9_999_999, true, 1)));
    assertTrue(control.shouldStartPlayback(parameters(10_000_000, true, 1)));
  }

  @Test public void explicitVodReserveCannotBeBypassedByAStaleLiveOffset() {
    control.setOnDemand(true);
    Parameters p = parameters(500_000, false, 1);
    assertFalse(control.shouldStartPlayback(new Parameters(
        p.playerId, p.timeline, p.mediaPeriodId, p.playbackPositionUs,
        p.bufferedDurationUs, p.playbackSpeed, p.playWhenReady, p.rebuffering,
        0, p.lastRebufferRealtimeMs)));
  }

  @Test public void reserveUsesPlaybackTimeAtFasterSpeeds() {
    control.setOnDemand(true);
    assertFalse(control.shouldStartPlayback(parameters(5_000_000, false, 2)));
    assertTrue(control.shouldStartPlayback(parameters(10_000_000, false, 2)));
  }

  @Test public void unchangedByteCapCanStartHighBitrateFilesWithoutDeadlock() {
    control.setOnDemand(true);
    allocations.add(allocator.allocate());
    allocations.add(allocator.allocate());
    assertFalse(control.shouldContinueLoading(parameters(500_000, false, 1)));
    assertTrue(control.shouldStartPlayback(parameters(500_000, false, 1)));
    assertTrue(control.shouldStartPlayback(parameters(500_000, true, 1)));
  }

  @Test public void clearingVodModeRestoresTheLiveThreshold() {
    control.setOnDemand(true);
    assertFalse(control.shouldStartPlayback(parameters(500_000, false, 1)));
    control.setOnDemand(false);
    assertTrue(control.shouldStartPlayback(parameters(500_000, false, 1)));
  }
}
