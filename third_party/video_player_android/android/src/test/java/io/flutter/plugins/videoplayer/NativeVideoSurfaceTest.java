package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;
import android.app.Activity;
import android.util.LongSparseArray;
import androidx.media3.common.Format;
import androidx.media3.common.VideoSize;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import android.view.SurfaceHolder;
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.analytics.AnalyticsListener;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {28, 30})
public class NativeVideoSurfaceTest {
  private NativeVideoSurface surface;
  private LongSparseArray<VideoPlayer> players;
  private ExoPlayer exo;

  @Before
  public void setUp() {
    players = new LongSparseArray<>();
    surface = new NativeVideoSurface(mock(BinaryMessenger.class), players);
    surface.setActivity(Robolectric.buildActivity(Activity.class).setup().get());
    exo = mock(ExoPlayer.class);
    VideoPlayer player = mock(VideoPlayer.class);
    when(player.getExoPlayer()).thenReturn(exo);
    player.nativeVideoDecoderName = "OMX.amlogic.hevc.decoder.awesome";
    players.put(1L, player);
    when(exo.getVideoFormat()).thenReturn(new Format.Builder()
        .setWidth(3840).setHeight(2160).setSampleMimeType("video/hevc").build());
    when(exo.getVideoSize()).thenReturn(new VideoSize(3840, 2160));
  }
  @After
  public void tearDown() { surface.dispose(); }
  private Object invoke(String name, Object arguments) {
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    surface.onMethodCall(new MethodCall(name, arguments), result);
    ArgumentCaptor<Object> capture = ArgumentCaptor.forClass(Object.class);
    verify(result).success(capture.capture());
    return capture.getValue();
  }
  @Test
  public void lateAttachSeedsDecoderAndFormatWithoutWaitingForNewEvents() {
    invoke("attach", Map.of("playerId", 1L));
    Map<?, ?> data = (Map<?, ?>) invoke("diagnostics", null);
    assertEquals("OMX.amlogic.hevc.decoder.awesome", data.get("decoder"));
    assertTrue(data.get("format").toString().contains("3840x2160"));
    assertEquals("3840x2160", data.get("videoSize"));
  }
  @Test
  public void subsequentDecoderAndFormatEventsStillUpdateDiagnostics() {
    invoke("attach", Map.of("playerId", 1L));
    ArgumentCaptor<AnalyticsListener> capture = ArgumentCaptor.forClass(AnalyticsListener.class);
    verify(exo).addAnalyticsListener(capture.capture());
    AnalyticsListener listener = capture.getValue();
    AnalyticsListener.EventTime time = mock(AnalyticsListener.EventTime.class);
    listener.onVideoDecoderInitialized(time, "new.decoder", 0, 0);
    listener.onVideoInputFormatChanged(time,
        new Format.Builder().setWidth(1920).setHeight(1080).build(), null);
    Map<?, ?> data = (Map<?, ?>) invoke("diagnostics", null);
    assertEquals("new.decoder", data.get("decoder"));
    assertTrue(data.get("format").toString().contains("1920x1080"));
  }
  @Test
  public void switchingPlayersDoesNotReusePreviousDecoderOrFormat() {
    invoke("attach", Map.of("playerId", 1L));
    VideoPlayer other = mock(VideoPlayer.class);
    when(other.getExoPlayer()).thenReturn(mock(ExoPlayer.class));
    players.put(2L, other);
    invoke("attach", Map.of("playerId", 2L));
    Map<?, ?> data = (Map<?, ?>) invoke("diagnostics", null);
    assertEquals("-", data.get("decoder"));
    assertEquals("-", data.get("format"));
    assertEquals("-", data.get("videoSize"));
  }

  @Test
  public void betaOffDoesNotCreateSurfaceDuringPreparation() {
    assertNull(surface.holderForPreparation());
    assertEquals(false, ((Map<?, ?>) invoke("status", null)).get("surfaceAdded"));
  }

  @Test
  public void preparedPlayerIsNotReboundAtRegistrationOrDartAttach() {
    invoke("configure", Map.of("enabled", true));
    SurfaceHolder holder = surface.holderForPreparation();
    assertNotNull(holder);
    assertTrue(((Map<?, ?>) invoke("diagnostics", null)).get("prepare").toString()
        .contains("prepared ON the native surface"));
    VideoPlayerOptions options = new VideoPlayerOptions();
    options.nativeSurfaceHolder = holder;
    VideoPlayer player = new PlatformViewVideoPlayer(mock(VideoPlayerCallbacks.class),
        MediaItem.fromUri("https://example.com/live"), options, () -> exo);
    players.put(2L, player);
    surface.onPlayerCreated(player, 2L);
    invoke("attach", Map.of("playerId", 2L));
    verify(exo, times(1)).setVideoSurfaceHolder(holder);
    // Preparing a retry must not steal a still-playing owner's output.
    assertNull(surface.holderForPreparation());
    assertTrue(((Map<?, ?>) invoke("diagnostics", null)).get("prepare").toString()
        .contains("prepared WITHOUT the native surface (player 2 still owns it)"));
    surface.onPlayerDisposed(2L);
    player.dispose();
    assertSame(holder, surface.holderForPreparation());
    verify(exo, never()).clearVideoSurfaceHolder(any());
  }

  @Test
  public void disposingOwnerSkipsPlaceholderButExplicitDetachStillClears() {
    invoke("attach", Map.of("playerId", 1L));
    surface.onPlayerDisposed(1L);
    verify(exo, never()).clearVideoSurfaceHolder(any());
    invoke("attach", Map.of("playerId", 1L));
    invoke("detach", Map.of("playerId", 1L));
    verify(exo).clearVideoSurfaceHolder(any());
    // An explicitly detached, retained player must bind again on return.
    invoke("attach", Map.of("playerId", 1L));
    verify(exo, times(2)).setVideoSurfaceHolder(any());
  }

  private VideoPlayer nativePlayer() {
    invoke("configure", Map.of("enabled", true));
    VideoPlayerOptions options = new VideoPlayerOptions();
    options.nativeSurfaceHolder = surface.holderForPreparation();
    VideoPlayer player = new PlatformViewVideoPlayer(mock(VideoPlayerCallbacks.class),
        MediaItem.fromUri("https://example.com/old"), options, () -> exo);
    players.put(3L, player);
    surface.onPlayerCreated(player, 3L);
    return player;
  }
  private void zap(MethodChannel.Result result, String path) {
    surface.onMethodCall(new MethodCall("replaceLive", Map.of("playerId", 3L,
        "url", "https://example.com/" + path, "hls", true)), result);
  }
  private Player.Listener swapListener() {
    ArgumentCaptor<Player.Listener> capture = ArgumentCaptor.forClass(Player.Listener.class);
    verify(exo, atLeastOnce()).addListener(capture.capture());
    return capture.getValue();
  }
  @Test
  public void liveZapUsesSamePlayerAndOutputAndWaitsForReady() {
    VideoPlayer player = nativePlayer();
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    zap(result, "next.m3u8");
    verify(result, never()).success(any());
    verify(exo).setMediaSource(any());
    verify(exo, times(2)).prepare();
    verify(exo, times(1)).setVideoSurfaceHolder(any());
    verify(exo, never()).clearVideoSurfaceHolder(any());
    verify(exo, never()).release();
    swapListener().onPlaybackStateChanged(Player.STATE_READY);
    verify(result).success(Map.of("accepted", true, "width", 3840, "height", 2160));
    surface.onPlayerDisposed(3L);
    player.dispose();
  }
  @Test
  public void supersededZapCannotCompleteOrFailNewRequest() {
    VideoPlayer player = nativePlayer();
    MethodChannel.Result first = mock(MethodChannel.Result.class);
    zap(first, "first");
    Player.Listener stale = swapListener();
    MethodChannel.Result second = mock(MethodChannel.Result.class);
    zap(second, "second");
    verify(first).error("NativeLiveZap", "superseded", null);
    stale.onPlaybackStateChanged(Player.STATE_READY);
    verify(second, never()).success(any());
    swapListener().onPlaybackStateChanged(Player.STATE_READY);
    verify(second).success(any());
    surface.onPlayerDisposed(3L);
    player.dispose();
  }
  @Test
  public void disposeDuringZapCompletesWaitingRequestAndCancelsTimeout() {
    VideoPlayer player = nativePlayer();
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    zap(result, "next");
    surface.onPlayerDisposed(3L);
    verify(result).error("NativeLiveZap", "disposed", null);
    org.robolectric.shadows.ShadowLooper.idleMainLooper(20, java.util.concurrent.TimeUnit.SECONDS);
    verify(result, times(1)).error(anyString(), anyString(), isNull());
    player.dispose();
  }
  @Test
  public void unownedOrDisabledZapIsRejectedWithoutChangingOutput() {
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    zap(result, "next");
    verify(result).success(Map.of("accepted", false));
    verify(exo, never()).setMediaSource(any());
  }

  @Test
  public void explicitNewPlaybackHandsOffSurfaceBeforePreparation() {
    VideoPlayer player = nativePlayer();
    invoke("prepareNewPlayer", null);
    verify(exo).pause();
    verify(exo).clearVideoSurfaceHolder(any());
    assertNotNull(surface.holderForPreparation());
    assertTrue(((Map<?, ?>) invoke("diagnostics", null)).get("prepare").toString()
        .contains("prepared ON the native surface"));
    player.dispose();
  }

  @Test
  @org.robolectric.annotation.LooperMode(org.robolectric.annotation.LooperMode.Mode.PAUSED)
  public void visibleZapCoverClearsAtFirstFrameAndOnFailure() {
    VideoPlayer player = nativePlayer();
    invoke("setRect", Map.of("left", 10, "top", 20, "width", 558, "height", 314));
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    zap(result, "next");
    org.robolectric.shadows.ShadowLooper.idleMainLooper(100, java.util.concurrent.TimeUnit.MILLISECONDS);
    Map<?, ?> covered = (Map<?, ?>) invoke("diagnostics", null);
    assertEquals(covered + " logs=" + org.robolectric.shadows.ShadowLog.getLogsForTag("VesperNativeSurface"), true, covered.get("zapCover"));
    ArgumentCaptor<AnalyticsListener> capture = ArgumentCaptor.forClass(AnalyticsListener.class);
    verify(exo, atLeastOnce()).addAnalyticsListener(capture.capture());
    capture.getValue().onRenderedFirstFrame(mock(AnalyticsListener.EventTime.class), new Object(), 0);
    assertEquals(false, ((Map<?, ?>) invoke("diagnostics", null)).get("zapCover"));
    surface.onPlayerDisposed(3L);
    player.dispose();
  }

  @Test
  public void formulerRejectsSolidGreenCaptureAndClearsPreviousPicture() {
    org.robolectric.shadows.ShadowBuild.setManufacturer("FORMULER");
    org.robolectric.shadows.ShadowBuild.setModel("Formuler Z11 Pro MAX");
    VideoPlayer player = nativePlayer();
    android.graphics.Bitmap good = android.graphics.Bitmap.createBitmap(90, 90,
        android.graphics.Bitmap.Config.ARGB_8888);
    good.eraseColor(android.graphics.Color.BLUE);
    surface.retainCapturedPicture(good);
    android.graphics.Bitmap green = android.graphics.Bitmap.createBitmap(90, 90,
        android.graphics.Bitmap.Config.ARGB_8888);
    green.eraseColor(android.graphics.Color.rgb(8, 240, 8));
    surface.retainCapturedPicture(green);
    assertTrue(green.isRecycled());
    assertEquals("solid-green rejected; logo fallback",
        ((Map<?, ?>) invoke("diagnostics", null)).get("zapCapture"));
    android.widget.ImageView cover = org.robolectric.util.ReflectionHelpers.getField(surface, "zapCover");
    assertFalse(cover.getDrawable() instanceof android.graphics.drawable.BitmapDrawable);
    assertNull(org.robolectric.util.ReflectionHelpers.getField(surface, "lastPicture"));
    player.dispose();
  }

  @Test
  public void otherDevicesKeepTheirCapturedFrame() {
    org.robolectric.shadows.ShadowBuild.setManufacturer("NVIDIA");
    org.robolectric.shadows.ShadowBuild.setModel("SHIELD Android TV");
    android.graphics.Bitmap green = android.graphics.Bitmap.createBitmap(90, 90,
        android.graphics.Bitmap.Config.ARGB_8888);
    green.eraseColor(android.graphics.Color.GREEN);
    surface.retainCapturedPicture(green);
    assertFalse(green.isRecycled());
    assertEquals("last frame retained", ((Map<?, ?>) invoke("diagnostics", null)).get("zapCapture"));
  }

  @Test
  public void texturedGreenSportsPictureIsNotRejected() {
    android.graphics.Bitmap field = android.graphics.Bitmap.createBitmap(90, 90,
        android.graphics.Bitmap.Config.ARGB_8888);
    for (int y = 0; y < 90; y++) {
      for (int x = 0; x < 90; x++) {
        field.setPixel(x, y, android.graphics.Color.rgb(8, 180 + x % 70, 8));
      }
    }
    assertFalse(NativeVideoSurface.isSolidGreenFrame(field));
    field.eraseColor(android.graphics.Color.BLACK);
    assertFalse(NativeVideoSurface.isSolidGreenFrame(field));
    field.eraseColor(android.graphics.Color.TRANSPARENT);
    assertFalse(NativeVideoSurface.isSolidGreenFrame(field));
    field.eraseColor(android.graphics.Color.GREEN);
    assertTrue(NativeVideoSurface.isSolidGreenFrame(field));
    // A small bitmap must also be safe to sample.
    android.graphics.Bitmap tiny = android.graphics.Bitmap.createBitmap(1, 1,
        android.graphics.Bitmap.Config.ARGB_8888);
    tiny.eraseColor(android.graphics.Color.GREEN);
    assertTrue(NativeVideoSurface.isSolidGreenFrame(tiny));
    tiny.recycle();
    field.recycle();
  }
}
