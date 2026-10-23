// VesperTV patch: opt-in "green flicker fix" (MethodChannel "vespertv/video", Settings >
// Interface > Background video). On, the main player's SurfaceView is a media overlay
// (setZOrderMediaOverlay, as already done on Android 7 and older): the partial workaround
// reported on google/ExoPlayer#7998 for NVIDIA Shield green frames while see-through UI sits on
// the video. Unlike Compatibility video it keeps the direct surface, so HDR still reaches the TV
// (Shield user, 2026-10-23). Read when a player view is created: applies from the next channel.
// Also "setTunneling" (test switch): tunneled playback for the main player, video straight to
// the hardware video plane. AMD's Fire TV Cube (Amlogic) decoded 4K HDR channels to a 1080p
// SDR copy through our surface (log LOG-CFN2FE: "Resolution change ... to 1920x1080",
// videoResolution.FHD), so HDR10 never reached the TV; the tunnel is the usual 4K HDR route.
package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class VideoLayering implements MethodChannel.MethodCallHandler {
  private static volatile boolean mediaOverlay = false;
  private static volatile boolean tunneling = false;

  public static boolean isMediaOverlay() {
    return mediaOverlay;
  }

  public static boolean isTunneling() {
    return tunneling;
  }

  private final MethodChannel methods;

  VideoLayering(@NonNull BinaryMessenger messenger) {
    methods = new MethodChannel(messenger, "vespertv/video");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if ("setMediaOverlay".equals(call.method)) {
      mediaOverlay = Boolean.TRUE.equals(call.argument("enabled"));
      result.success(null);
    } else if ("setTunneling".equals(call.method)) {
      tunneling = Boolean.TRUE.equals(call.argument("enabled"));
      result.success(null);
    } else {
      result.notImplemented();
    }
  }
}
