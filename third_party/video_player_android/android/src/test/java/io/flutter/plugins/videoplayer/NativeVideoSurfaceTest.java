package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;
import android.app.Activity;
import android.util.LongSparseArray;
import androidx.media3.common.Format;
import androidx.media3.common.VideoSize;
import androidx.media3.common.MediaItem;
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
}
