// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.content.Context;
import android.app.Activity;
import android.util.LongSparseArray;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.platform.PlatformViewRegistry;
import io.flutter.plugins.videoplayer.platformview.PlatformVideoViewFactory;
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer;
import io.flutter.plugins.videoplayer.texture.TextureVideoPlayer;
import io.flutter.view.TextureRegistry;
import java.lang.reflect.Field;
import java.util.HashMap;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.MockitoAnnotations;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Robolectric;
import org.robolectric.annotation.Config;
import org.mockito.ArgumentCaptor;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {28, 30})
public class VideoPlayerPluginTest {
  @Mock private TextureRegistry mockTextureRegistry;
  @Mock private TextureRegistry.SurfaceProducer mockSurfaceProducer;
  @Mock private PlatformViewRegistry mockPlatformViewRegistry;
  private VideoPlayerPlugin plugin;
  private PlatformViewVideoPlayer mockedMain;
  private TextureVideoPlayer mockedTile;

  @Before
  public void setUp() {
    MockitoAnnotations.openMocks(this);
    mockedMain = mockPlayer(PlatformViewVideoPlayer.class);
    mockedTile = mockPlayer(TextureVideoPlayer.class);
    when(mockTextureRegistry.createSurfaceProducer()).thenReturn(mockSurfaceProducer);

    FlutterPlugin.FlutterPluginBinding binding = mock(FlutterPlugin.FlutterPluginBinding.class);
    when(binding.getApplicationContext()).thenReturn(mock(Context.class));
    when(binding.getTextureRegistry()).thenReturn(mockTextureRegistry);
    when(binding.getBinaryMessenger())
        .thenReturn(mock(io.flutter.plugin.common.BinaryMessenger.class));
    when(binding.getPlatformViewRegistry()).thenReturn(mockPlatformViewRegistry);

    plugin = new VideoPlayerPlugin();
    plugin.onAttachedToEngine(binding);
  }

  @SuppressWarnings("unchecked")
  private LongSparseArray<VideoPlayer> getVideoPlayers() throws Exception {
    final Field field = VideoPlayerPlugin.class.getDeclaredField("videoPlayers");
    field.setAccessible(true);
    return (LongSparseArray<VideoPlayer>) field.get(plugin);
  }

  // The plugin also registers subtitle listeners on the underlying player.
  private <T extends VideoPlayer> T mockPlayer(Class<T> type) {
    T player = mock(type);
    when(player.getExoPlayer()).thenReturn(mock(androidx.media3.exoplayer.ExoPlayer.class));
    return player;
  }

  // This is only a placeholder test and doesn't actually initialize the plugin.
  @Test
  public void initPluginDoesNotThrow() {
    final VideoPlayerPlugin plugin = new VideoPlayerPlugin();
  }

  @Test
  public void registersPlatformVideoViewFactory() {
    verify(mockPlatformViewRegistry)
        .registerViewFactory(
            eq("plugins.flutter.dev/video_player_android"), any(PlatformVideoViewFactory.class));
  }

  @Test
  public void createsPlatformViewVideoPlayer() throws Exception {
    try (MockedStatic<PlatformViewVideoPlayer> mockedPlatformViewVideoPlayerStatic =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mockedPlatformViewVideoPlayerStatic
          .when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any()))
          .thenReturn(mockedMain);

      final CreationOptions options =
          new CreationOptions(
              "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
              null,
              new HashMap<>(),
              null,
              null);

      final long playerId = plugin.createForPlatformView(options);

      final LongSparseArray<VideoPlayer> videoPlayers = getVideoPlayers();
      assertTrue(videoPlayers.get(playerId) instanceof PlatformViewVideoPlayer);
    }
  }

  @Test
  public void enabledNativeOutputIsPassedOnlyToMainPlayer() throws Exception {
    Field field = VideoPlayerPlugin.class.getDeclaredField("nativeVideoSurface");
    field.setAccessible(true);
    NativeVideoSurface nativeOutput = (NativeVideoSurface) field.get(plugin);
    nativeOutput.setActivity(Robolectric.buildActivity(Activity.class).setup().get());
    nativeOutput.onMethodCall(new MethodCall("configure", java.util.Map.of("enabled", true)),
        mock(MethodChannel.Result.class));
    CreationOptions options = new CreationOptions("https://example.com/live", null,
        new HashMap<>(), null, null);
    try (MockedStatic<PlatformViewVideoPlayer> main = mockStatic(PlatformViewVideoPlayer.class);
        MockedStatic<TextureVideoPlayer> tiles = mockStatic(TextureVideoPlayer.class)) {
      main.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any()))
          .thenReturn(mockedMain);
      tiles.when(() -> TextureVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(mockedTile);
      plugin.createForPlatformView(options);
      ArgumentCaptor<VideoPlayerOptions> mainOptions = ArgumentCaptor.forClass(VideoPlayerOptions.class);
      main.verify(() -> PlatformViewVideoPlayer.create(any(), any(), any(), mainOptions.capture()));
      assertNotNull(mainOptions.getValue().nativeSurfaceHolder);
      plugin.createForTextureView(options);
      ArgumentCaptor<VideoPlayerOptions> tileOptions = ArgumentCaptor.forClass(VideoPlayerOptions.class);
      tiles.verify(() -> TextureVideoPlayer.create(any(), any(), any(), any(), tileOptions.capture()));
      assertNull(tileOptions.getValue().nativeSurfaceHolder);
    } finally {
      nativeOutput.dispose();
    }
  }

  @Test
  public void createsTextureVideoPlayer() throws Exception {
    try (MockedStatic<TextureVideoPlayer> mockedTextureVideoPlayerStatic =
        mockStatic(TextureVideoPlayer.class)) {
      mockedTextureVideoPlayerStatic
          .when(() -> TextureVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(mockedTile);

      final CreationOptions options =
          new CreationOptions(
              "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
              null,
              new HashMap<>(),
              null,
              null);

      final TexturePlayerIds ids = plugin.createForTextureView(options);

      final LongSparseArray<VideoPlayer> videoPlayers = getVideoPlayers();
      assertTrue(videoPlayers.get(ids.getPlayerId()) instanceof TextureVideoPlayer);
    }
  }
}
