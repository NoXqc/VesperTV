// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.os.Looper;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugins.videoplayer.texture.TextureExoPlayerEventListener;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnit;
import org.mockito.junit.MockitoRule;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;

/**
 * Unit tests for {@link TextureExoPlayerEventListener}.
 *
 * <p>This test suite <em>narrowly verifies</em> that the events emitted by the underlying {@link
 * androidx.media3.exoplayer.ExoPlayer} instance are translated to the callback interface we expect
 * ({@link VideoPlayerCallbacks} and/or interface with the player instance as expected).
 */
@RunWith(RobolectricTestRunner.class)
public class TextureExoPlayerEventListenerTest {
  @Mock private ExoPlayer mockExoPlayer;
  @Mock private VideoPlayerCallbacks mockCallbacks;

  @Rule public MockitoRule initRule = MockitoJUnit.rule();

  @Test
  public void
      onPlaybackStateChangedReadySendInitialized_whenSurfaceProducerHandlesCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    VideoSize size = new VideoSize(800, 400, 0);
    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 0);
  }

  @Test
  public void
      onPlaybackStateChangedReadySendInitializedWithRotationCorrectionAndWidthAndHeightSwap_whenSurfaceProducerDoesNotHandleCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, false);
    VideoSize size = new VideoSize(800, 400, 0);
    int rotationCorrection = 90;
    Format videoFormat = new Format.Builder().setRotationDegrees(rotationCorrection).build();

    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);
    when(mockExoPlayer.getVideoFormat()).thenReturn(videoFormat);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, rotationCorrection);
  }

  @Test
  public void
      onPlaybackStateChangedReadyInPortraitMode90DegreesDoesNotSwapWidthAndHeight_whenSurfaceProducerHandlesCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    VideoSize size = new VideoSize(800, 400, 0);

    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 0);
  }

  @Test
  public void
      onPlaybackStateChangedReadyInPortraitMode90DegreesSwapWidthAndHeight_whenSurfaceProducerDoesNotHandleCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, false);
    VideoSize size = new VideoSize(800, 400, 0);
    int rotationCorrection = 90;
    Format videoFormat = new Format.Builder().setRotationDegrees(rotationCorrection).build();

    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);
    when(mockExoPlayer.getVideoFormat()).thenReturn(videoFormat);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 90);
  }

  @Test
  public void
      onPlaybackStateChangedReadyInPortraitMode270DegreesDoesNotSwapWidthAndHeight_whenSurfaceProducerHandlesCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    VideoSize size = new VideoSize(800, 400, 0);
    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 0);
  }

  @Test
  public void
      onPlaybackStateChangedReadyInPortraitMode270DegreesDoesNotSwapWidthAndHeight_whenSurfaceProducerDoesNotHandleCropAndRotation() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, false);
    VideoSize size = new VideoSize(800, 400, 0);
    int rotationCorrection = 270;
    Format videoFormat = new Format.Builder().setRotationDegrees(rotationCorrection).build();

    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);
    when(mockExoPlayer.getVideoFormat()).thenReturn(videoFormat);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 270);
  }

  @Test
  public void onPlaybackStateChangedReadyScalesWidthByPixelAspectRatio_whenContentIsAnamorphic() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    // Anamorphic content: 1080x720 coded pixels with a 3:8 pixel aspect ratio displays as 405x720.
    VideoSize size = new VideoSize(1080, 720, 0.375f);
    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(405, 720, 10L, 0);
  }

  @Test
  public void onPlaybackStateChangedReadyDoesNotScaleWidth_whenPixelAspectRatioIsSquare() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    VideoSize size = new VideoSize(800, 400, 1f);
    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(800, 400, 10L, 0);
  }

  @Test
  public void
      onPlaybackStateChangedReadyScalesWidthByPixelAspectRatio_whenAnamorphicAndRotationCorrected() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, false);
    // ExoPlayer reports a pixel aspect ratio that already accounts for the applied rotation,
    // so the width is scaled the same way regardless of the rotation correction.
    VideoSize size = new VideoSize(1080, 720, 0.375f);
    int rotationCorrection = 90;
    Format videoFormat = new Format.Builder().setRotationDegrees(rotationCorrection).build();

    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);
    when(mockExoPlayer.getVideoFormat()).thenReturn(videoFormat);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(405, 720, 10L, rotationCorrection);
  }

  @Test
  public void onPlaybackStateChangedReadyReportsAtLeastOnePixel_whenPixelAspectRatioIsDegenerate() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    // A malformed ratio would otherwise round the width down to zero.
    VideoSize size = new VideoSize(800, 400, 0.0001f);
    when(mockExoPlayer.getVideoSize()).thenReturn(size);
    when(mockExoPlayer.getDuration()).thenReturn(10L);

    eventListener.onPlaybackStateChanged(Player.STATE_READY);
    verify(mockCallbacks).onInitialized(1, 400, 10L, 0);
  }

  // Catch-up (finite mode): a finished programme reports ENDED instead of the
  // live reconnect that would replay it forever on texture players.
  @Test
  public void finiteModeEndedIsReportedNotReconnected() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    eventListener.setFiniteMode(true);
    when(mockExoPlayer.getDuration()).thenReturn(C.TIME_UNSET);

    eventListener.onPlaybackStateChanged(Player.STATE_ENDED);

    verify(mockCallbacks).onPlaybackStateChanged(PlatformPlaybackState.ENDED);
    verify(mockExoPlayer, never()).prepare();
  }

  // A network error in a seekable catch-up programme resumes where it
  // failed, not at the start (seekToDefaultPosition).
  @Test
  public void finiteModeErrorResumesAtPosition() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    eventListener.setFiniteMode(true);
    when(mockExoPlayer.getCurrentPosition()).thenReturn(754_000L);
    when(mockExoPlayer.isCurrentMediaItemSeekable()).thenReturn(true);

    eventListener.onPlayerError(
        new PlaybackException("net", null, PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED));
    Shadows.shadowOf(Looper.getMainLooper()).idle();
    Shadows.shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(5));

    verify(mockExoPlayer).seekTo(754_000L);
    verify(mockExoPlayer, never()).seekToDefaultPosition();
    verify(mockExoPlayer).prepare();
  }

  // Not seekable (or out of retries): Dart gets the error and re-requests.
  @Test
  public void finiteModeUnseekableErrorGoesToDart() {
    TextureExoPlayerEventListener eventListener =
        new TextureExoPlayerEventListener(mockExoPlayer, mockCallbacks, true);
    eventListener.setFiniteMode(true);
    when(mockExoPlayer.isCurrentMediaItemSeekable()).thenReturn(false);

    eventListener.onPlayerError(
        new PlaybackException("net", null, PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED));
    Shadows.shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(5));

    verify(mockCallbacks).onError(eq("VideoError"), anyString(), isNull());
    verify(mockExoPlayer, never()).prepare();
  }
}
