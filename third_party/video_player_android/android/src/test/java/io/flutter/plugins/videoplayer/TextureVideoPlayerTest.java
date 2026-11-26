// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// Changed by VesperTV contributors (2026): those changes are under the GNU GPL v3
// (see LICENSE-VESPERTV.md); Flutter's original code here stays under the BSD LICENSE.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import android.view.Surface;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.Player;
import androidx.media3.common.Tracks;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugins.videoplayer.texture.TextureVideoPlayer;
import io.flutter.view.TextureRegistry;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.MockedConstruction;
import org.mockito.junit.MockitoJUnit;
import org.mockito.junit.MockitoRule;
import org.robolectric.RobolectricTestRunner;

/**
 * Unit tests for {@link TextureVideoPlayer}.
 *
 * <p>This test suite <em>narrowly verifies</em> that {@link TextureVideoPlayer} interfaces with the
 * {@link ExoPlayer} interface <em>exactly</em> as it did when the test suite was created. That is,
 * if the behavior changes, this test will need to change. However, this suite should catch bugs
 * related to <em>"this is a safe refactor with no behavior changes"</em>.
 */
@RunWith(RobolectricTestRunner.class)
public final class TextureVideoPlayerTest {
  private static final String FAKE_ASSET_URL = "https://flutter.dev/movie.mp4";
  private FakeVideoAsset fakeVideoAsset;

  @Mock private VideoPlayerCallbacks mockEvents;
  @Mock private TextureRegistry.SurfaceProducer mockProducer;
  @Mock private ExoPlayer mockExoPlayer;
  @Captor private ArgumentCaptor<AudioAttributes> attributesCaptor;
  @Captor private ArgumentCaptor<TextureRegistry.SurfaceProducer.Callback> callbackCaptor;
  @Captor private ArgumentCaptor<Player.Listener> listenerCaptor;

  @Rule public MockitoRule initRule = MockitoJUnit.rule();

  @Before
  public void setUp() {
    fakeVideoAsset = new FakeVideoAsset(FAKE_ASSET_URL);
    when(mockProducer.getSurface()).thenReturn(mock(Surface.class));
    when(mockProducer.handlesCropAndRotation()).thenReturn(true);
    // A real ExoPlayer never returns null tracks; the mock would, and the
    // listener reads them when the video format is still unknown.
    lenient().when(mockExoPlayer.getCurrentTracks()).thenReturn(Tracks.EMPTY);
  }

  private VideoPlayer createVideoPlayer() {
    return createVideoPlayer(new VideoPlayerOptions());
  }

  private TextureVideoPlayer createVideoPlayer(VideoPlayerOptions options) {
    return new TextureVideoPlayer(
        mockEvents, mockProducer, fakeVideoAsset.getMediaItem(), options, () -> mockExoPlayer);
  }

  @Test
  public void loadsAndPreparesProvidedMediaEnablesAudioFocusByDefault() {
    VideoPlayer videoPlayer = createVideoPlayer();

    verify(mockExoPlayer).setMediaItem(fakeVideoAsset.getMediaItem());
    verify(mockExoPlayer).prepare();
    verify(mockProducer).getSurface();
    verify(mockExoPlayer).setVideoSurface(any());

    verify(mockExoPlayer).setAudioAttributes(attributesCaptor.capture(), eq(true));
    assertEquals(C.AUDIO_CONTENT_TYPE_MOVIE, attributesCaptor.getValue().contentType);

    videoPlayer.dispose();
  }

  @Test
  public void onSurfaceProducerCleanupAndAvailableRemovesAndRestoresSurface() {
    VideoPlayer videoPlayer = createVideoPlayer();

    verify(mockProducer).setCallback(callbackCaptor.capture());
    verify(mockExoPlayer).setVideoSurface(notNull());
    verify(mockExoPlayer, never()).release();

    when(mockExoPlayer.getCurrentPosition()).thenReturn(10L);
    when(mockExoPlayer.getRepeatMode()).thenReturn(Player.REPEAT_MODE_ALL);
    when(mockExoPlayer.getVolume()).thenReturn(0.5f);
    when(mockExoPlayer.getPlaybackParameters()).thenReturn(new PlaybackParameters(2.5f));

    TextureRegistry.SurfaceProducer.Callback producerLifecycle = callbackCaptor.getValue();
    producerLifecycle.onSurfaceCleanup();

    verify(mockExoPlayer).setVideoSurface(null);

    reset(mockExoPlayer);
    producerLifecycle.onSurfaceAvailable();

    verify(mockExoPlayer).setVideoSurface(notNull());

    videoPlayer.dispose();
  }

  @Test
  public void onSurfaceProducerCleanupDoesNotStopOrPauseVideo() {
    VideoPlayer videoPlayer = createVideoPlayer();

    verify(mockProducer).setCallback(callbackCaptor.capture());
    TextureRegistry.SurfaceProducer.Callback producerLifecycle = callbackCaptor.getValue();
    producerLifecycle.onSurfaceCleanup();

    verify(mockExoPlayer, never()).stop();
    verify(mockExoPlayer, never()).pause();
    verify(mockExoPlayer, never()).setPlayWhenReady(anyBoolean());

    videoPlayer.dispose();
  }

  @Test
  public void onInitializedCalledWhenVideoPlayerInitiallyCreated() {
    VideoPlayer videoPlayer = createVideoPlayer();

    // Pretend we have a video, and capture the registered event listener.
    when(mockExoPlayer.getVideoSize()).thenReturn(new VideoSize(300, 200));
    // VideoPlayer also registers its live queue and stall counter: the
    // event listener is the first one.
    verify(mockExoPlayer, atLeastOnce()).addListener(listenerCaptor.capture());
    Player.Listener listener = listenerCaptor.getAllValues().get(0);

    // Trigger an event that would trigger onInitialized.
    listener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockEvents).onInitialized(anyInt(), anyInt(), anyLong(), anyInt());

    videoPlayer.dispose();
  }

  @Test
  public void onSurfaceAvailableDoesNotSendInitializeEventAgain() {
    // The VideoPlayer contract assumes that the event "initialized" is sent exactly once
    // (duplicate events cause an error to be thrown at the shared Dart layer). This test verifies
    // that the onInitialized event is sent exactly once per player.
    //
    // Regression test for https://github.com/flutter/flutter/issues/154602.
    VideoPlayer videoPlayer = createVideoPlayer();
    when(mockExoPlayer.getVideoSize()).thenReturn(new VideoSize(300, 200));

    // Capture the lifecycle events so we can simulate onSurfaceAvailable/Cleanup.
    verify(mockProducer).setCallback(callbackCaptor.capture());
    TextureRegistry.SurfaceProducer.Callback producerLifecycle = callbackCaptor.getValue();

    // VideoPlayer also registers its live queue and stall counter: the
    // event listener is the first one.
    verify(mockExoPlayer, atLeastOnce()).addListener(listenerCaptor.capture());
    Player.Listener listener = listenerCaptor.getAllValues().get(0);

    // Trigger ready state, which should trigger initialization.
    listener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockEvents).onInitialized(anyInt(), anyInt(), anyLong(), anyInt());

    // Trigger cleanup/available.
    producerLifecycle.onSurfaceCleanup();
    producerLifecycle.onSurfaceAvailable();

    // It should still only have been called the one time.
    verify(mockEvents).onInitialized(anyInt(), anyInt(), anyLong(), anyInt());

    videoPlayer.dispose();
  }

  @Test
  public void onSurfaceAvailableWithoutCleanupDoesNotRecreate() {
    // Initially create the video player, which creates the initial surface.
    VideoPlayer videoPlayer = createVideoPlayer();
    verify(mockProducer).getSurface();
    verify(mockProducer).handlesCropAndRotation();

    // Capture the lifecycle events so we can simulate onSurfaceAvailable/Cleanup.
    verify(mockProducer).setCallback(callbackCaptor.capture());
    TextureRegistry.SurfaceProducer.Callback producerLifecycle = callbackCaptor.getValue();

    // Calling onSurfaceAvailable does not do anything, since the surface was never cleaned up.
    producerLifecycle.onSurfaceAvailable();
    verifyNoMoreInteractions(mockProducer);

    videoPlayer.dispose();
  }

  @Test
  public void disposeReleasesExoPlayerBeforeTexture() {
    VideoPlayer videoPlayer = createVideoPlayer();

    videoPlayer.dispose();

    // Regression test for https://github.com/flutter/flutter/issues/156158.
    // The player must be destroyed before the surface it is writing to.
    InOrder inOrder = inOrder(mockExoPlayer, mockProducer);
    inOrder.verify(mockExoPlayer).release();
    inOrder.verify(mockProducer).release();
  }

  @Test
  public void create_withBackBufferDuration_setsLoadControl() {
    android.content.Context mockContext = mock(android.content.Context.class);
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

      TextureVideoPlayer player =
          TextureVideoPlayer.create(mockContext, mockEvents, mockProducer, fakeVideoAsset, options);

      assertEquals(1, mockedBuilder.constructed().size());
      ExoPlayer.Builder builderMock = mockedBuilder.constructed().get(0);
      verify(builderMock).setLoadControl(any());
      player.dispose();
    }
  }

    @Test
    @org.robolectric.annotation.Config(sdk = 25)
    public void compatibilityPassthroughRequiresBothSettingAndPermission() throws Exception {
      for (boolean requested : new boolean[] {false, true}) {
        for (boolean allowed : new boolean[] {false, true}) {
          android.content.Context appContext = mock(android.content.Context.class);
          VideoPlayerOptions options = new VideoPlayerOptions();
          options.allowEncodedAudio = allowed;
          try (org.mockito.MockedStatic<AudioPassthrough> setting = mockStatic(AudioPassthrough.class);
              MockedConstruction<ExoPlayer.Builder> builders = mockConstruction(
                  ExoPlayer.Builder.class, (builder, construction) -> {
                    when(builder.setTrackSelector(any())).thenReturn(builder);
                    when(builder.setMediaSourceFactory(any())).thenReturn(builder);
                    when(builder.build()).thenReturn(mockExoPlayer);
                  });
              MockedConstruction<androidx.media3.exoplayer.audio.DefaultAudioSink.Builder> sinks =
                  mockConstruction(androidx.media3.exoplayer.audio.DefaultAudioSink.Builder.class,
                      (sink, construction) -> {
                        assertEquals(requested && allowed ? java.util.List.of(appContext)
                            : java.util.List.of(), construction.arguments());
                        when(sink.setEnableFloatOutput(anyBoolean())).thenReturn(sink);
                        when(sink.setEnableAudioOutputPlaybackParameters(anyBoolean())).thenReturn(sink);
                        when(sink.build()).thenReturn(
                            mock(androidx.media3.exoplayer.audio.DefaultAudioSink.class));
                      })) {
            setting.when(AudioPassthrough::isEnabled).thenReturn(requested);
            TextureVideoPlayer player = TextureVideoPlayer.create(
                appContext, mockEvents, mockProducer, fakeVideoAsset, options);
            ArgumentCaptor<androidx.media3.exoplayer.RenderersFactory> factory =
                ArgumentCaptor.forClass(androidx.media3.exoplayer.RenderersFactory.class);
            verify(builders.constructed().get(0)).setRenderersFactory(factory.capture());
            java.lang.reflect.Method buildSink = factory.getValue().getClass().getDeclaredMethod(
                "buildAudioSink", android.content.Context.class, boolean.class, boolean.class);
            buildSink.setAccessible(true);
            buildSink.invoke(factory.getValue(), appContext, false, false);
            assertEquals(1, sinks.constructed().size());
            assertEquals(requested && allowed, options.effectivePassthrough);
            assertEquals(requested && allowed, player.isAudioPassthroughEnabled());
            player.dispose();
          }
      }
    }
  }
}
