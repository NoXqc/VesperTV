// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockConstruction;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.content.Context;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Timeline;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.LoadControl;
import androidx.media3.exoplayer.analytics.PlayerId;
import androidx.media3.exoplayer.source.MediaSource.MediaPeriodId;
import androidx.media3.exoplayer.source.SinglePeriodTimeline;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.ExoTrackSelection;
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.ArgumentCaptor;
import org.mockito.MockedConstruction;
import org.mockito.junit.MockitoJUnit;
import org.mockito.junit.MockitoRule;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public final class PlatformViewVideoPlayerTest {
  private static final String FAKE_ASSET_URL = "https://flutter.dev/movie.mp4";
  private FakeVideoAsset fakeVideoAsset;

  @Mock private VideoPlayerCallbacks mockEvents;
  @Mock private ExoPlayer mockExoPlayer;

  @Rule public MockitoRule initRule = MockitoJUnit.rule();

  @Before
  public void setUp() {
    fakeVideoAsset = new FakeVideoAsset(FAKE_ASSET_URL);
  }

  @OptIn(markerClass = UnstableApi.class)
  @Test
  public void create_withBackBufferDuration_setsLoadControl() {
    Context mockContext = mock(Context.class);
    VideoPlayerOptions options = new VideoPlayerOptions();
    options.backBufferDurationMs = 20000L;

    try (MockedConstruction<ExoPlayer.Builder> mockedBuilder =
        mockConstruction(
            ExoPlayer.Builder.class,
            (mock, context) -> {
              when(mock.setLoadControl(any())).thenReturn(mock);
              when(mock.setTrackSelector(any())).thenReturn(mock);
              when(mock.setMediaSourceFactory(any())).thenReturn(mock);
              when(mock.build()).thenReturn(mockExoPlayer);
            })) {

      PlatformViewVideoPlayer player =
          PlatformViewVideoPlayer.create(mockContext, mockEvents, fakeVideoAsset, options);

      assertEquals(1, mockedBuilder.constructed().size());
      ExoPlayer.Builder builderMock = mockedBuilder.constructed().get(0);
      ArgumentCaptor<LoadControl> captured = ArgumentCaptor.forClass(LoadControl.class);
      verify(builderMock).setLoadControl(captured.capture());
      LoadControl control = captured.getValue();
      PlayerId id = new PlayerId("factory-test");
      Timeline timeline = new SinglePeriodTimeline(
          3_600_000_000L, true, false, false, null, MediaItem.fromUri(FAKE_ASSET_URL));
      LoadControl.Parameters parameters = new LoadControl.Parameters(
          id, timeline, new MediaPeriodId(timeline.getUidOfPeriod(0)), 0, 500_000, 1,
          true, false, C.TIME_UNSET, C.TIME_UNSET);
      control.onPrepared(id);
      control.onTracksSelected(parameters, TrackGroupArray.EMPTY, new ExoTrackSelection[0]);
      assertEquals(20_000_000L, control.getBackBufferDurationUs(id));
      assertEquals(true, control.shouldStartPlayback(parameters));
      // Toggle the player, not the captured policy: proves factory wiring is per player.
      ((VideoPlayer) player).setOnDemandBuffering(true);
      assertEquals(false, control.shouldStartPlayback(parameters));
      ((VideoPlayer) player).setOnDemandBuffering(false);
      assertEquals(true, control.shouldStartPlayback(parameters));
      control.onReleased(id);
      player.dispose();
    }
  }
}
