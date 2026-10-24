// VesperTV patch: "Native video surface (beta)" (Settings > Interface > Background video,
// AppPreferences.nativeVideoSurface, MethodChannel "vespertv/native_surface"). With it on,
// MainActivity starts Flutter transparent and the main player draws into ONE plain SurfaceView
// that sits behind the Flutter view in the activity's content, the way a native player
// (TiviMate) does — no Flutter platform view (hybrid composition) around the video. Dart's
// NativeVideoHole clears its rect to transparent and reports it here; the SurfaceView follows.
// Why: through the platform view, AMD's Fire TV Cube decoded 4K HDR10 to 1080p SDR (washed
// out, LOG-CFN2FE) and Sam's NVIDIA Shield showed green flicker under the guide; Compatibility
// video (texture) stopped the flicker but lost HDR. Every step logs under tag
// "VesperNativeSurface" so a Send log shows what the box did.
package io.flutter.plugins.videoplayer;

import android.app.Activity;
import android.os.Build;
import android.util.Log;
import android.util.LongSparseArray;
import android.view.Display;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.VideoSize;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DecoderReuseEvaluation;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.analytics.AnalyticsListener;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@OptIn(markerClass = UnstableApi.class)
public final class NativeVideoSurface implements MethodChannel.MethodCallHandler {
  private static final String TAG = "VesperNativeSurface";

  private final MethodChannel methods;
  private final LongSparseArray<VideoPlayer> players;
  @Nullable private Activity activity;
  @Nullable private SurfaceView view;
  private long attachedId = -1;
  @Nullable private ExoPlayer attachedPlayer;
  private boolean shown = false;
  private int left, top, width = 1, height = 1;

  // Last known facts, returned by "diagnostics" so Dart puts them in the session log too
  // (logcat rolls over; the session log doesn't).
  private String surfaceState = "none";
  private String decoder = "-";
  private String inputFormat = "-";
  private String videoSize = "-";
  private String firstFrame = "-";
  private int droppedFrames = 0;
  private String lastError = "-";

  NativeVideoSurface(@NonNull BinaryMessenger messenger, @NonNull LongSparseArray<VideoPlayer> players) {
    this.players = players;
    methods = new MethodChannel(messenger, "vespertv/native_surface");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
    detach();
    removeView();
  }

  void setActivity(@Nullable Activity activity) {
    if (this.activity == activity) return;
    removeView();
    this.activity = activity;
  }

  /** The plugin is disposing this player: let go of it first. */
  void onPlayerDisposed(long id) {
    if (id == attachedId) {
      Log.i(TAG, "player " + id + " disposed while attached");
      detach();
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      switch (call.method) {
        case "attach":
          {
            Number id = call.argument("playerId");
            result.success(attach(id == null ? -1 : id.longValue()));
            return;
          }
        case "detach":
          {
            Number id = call.argument("playerId");
            if (id != null && id.longValue() == attachedId) detach();
            result.success(null);
            return;
          }
        case "setRect":
          {
            setRect(
                intArg(call, "left"), intArg(call, "top"),
                intArg(call, "width"), intArg(call, "height"));
            result.success(null);
            return;
          }
        case "hide":
          hide();
          result.success(null);
          return;
        case "status":
          {
            Map<String, Object> s = new HashMap<>();
            s.put("surfaceAdded", view != null);
            s.put("attached", attachedId);
            s.put("shown", shown);
            s.put("surface", surfaceState);
            s.put("windowTransparent", windowTransparent());
            result.success(s);
            return;
          }
        case "diagnostics":
          result.success(diagnostics());
          return;
        default:
          result.notImplemented();
      }
    } catch (Exception e) {
      Log.w(TAG, call.method + " failed", e);
      result.error("native_surface", String.valueOf(e), null);
    }
  }

  private static int intArg(MethodCall call, String key) {
    Number n = call.argument(key);
    return n == null ? 0 : n.intValue();
  }

  private boolean ensureView() {
    if (view != null) return true;
    if (activity == null) {
      Log.w(TAG, "no activity: cannot create the video surface");
      return false;
    }
    ViewGroup content = activity.findViewById(android.R.id.content);
    if (content == null) {
      Log.w(TAG, "no content view: cannot create the video surface");
      return false;
    }
    view = new SurfaceView(activity);
    view.getHolder().addCallback(
        new SurfaceHolder.Callback() {
          @Override
          public void surfaceCreated(@NonNull SurfaceHolder holder) {
            surfaceState = "created";
            Log.i(TAG, "surface created");
          }

          @Override
          public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int w, int h) {
            surfaceState = w + "x" + h + " fmt " + format;
            Log.i(TAG, "surface changed " + surfaceState);
          }

          @Override
          public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
            surfaceState = "destroyed";
            Log.i(TAG, "surface destroyed");
          }
        });
    // Index 0 = behind the Flutter view. Default z-order: the surface punches through the
    // (transparent) window, under Flutter's own drawing.
    content.addView(view, 0, params());
    Log.i(TAG, "video surface added behind Flutter (content children " + content.getChildCount() + ")");
    logDisplay();
    return true;
  }

  private void removeView() {
    if (view == null) return;
    ViewGroup parent = (ViewGroup) view.getParent();
    if (parent != null) parent.removeView(view);
    view = null;
    shown = false;
    surfaceState = "none";
  }

  /** Off-screen (right of the display) instead of GONE: GONE destroys the surface. */
  private FrameLayout.LayoutParams params() {
    int w = Math.max(width, 1);
    int h = Math.max(height, 1);
    FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(w, h, Gravity.TOP | Gravity.START);
    if (shown) {
      p.leftMargin = left;
      p.topMargin = top;
    } else {
      int screenW = activity == null ? 4000 : activity.getWindow().getDecorView().getWidth();
      p.leftMargin = Math.max(screenW, 1) + 16;
      p.topMargin = 0;
    }
    return p;
  }

  private Map<String, Object> attach(long id) {
    VideoPlayer player = players.get(id);
    Map<String, Object> out = new HashMap<>();
    if (player == null) {
      Log.w(TAG, "attach: no player " + id);
      out.put("ok", false);
      return out;
    }
    if (!ensureView()) {
      out.put("ok", false);
      return out;
    }
    ExoPlayer exo = player.getExoPlayer();
    if (exo != attachedPlayer) {
      detach();
      attachedId = id;
      attachedPlayer = exo;
      decoder = inputFormat = videoSize = firstFrame = lastError = "-";
      droppedFrames = 0;
      exo.addAnalyticsListener(analytics);
      exo.setVideoSurfaceHolder(view.getHolder());
      Log.i(TAG, "attached player " + id + " (surface " + surfaceState + ")");
    }
    out.put("ok", true);
    return out;
  }

  private void detach() {
    if (attachedPlayer != null) {
      try {
        attachedPlayer.removeAnalyticsListener(analytics);
        if (view != null) attachedPlayer.clearVideoSurfaceHolder(view.getHolder());
      } catch (Exception e) {
        Log.w(TAG, "detach: " + e);
      }
      Log.i(TAG, "detached player " + attachedId);
    }
    attachedPlayer = null;
    attachedId = -1;
  }

  private void setRect(int l, int t, int w, int h) {
    if (!ensureView()) return;
    boolean sizeChanged = w != width || h != height;
    boolean wasShown = shown;
    if (shown && l == left && t == top && !sizeChanged) return;
    left = l;
    top = t;
    width = w;
    height = h;
    shown = true;
    view.setLayoutParams(params());
    // Positions change every frame during animations: log only show/size changes.
    if (!wasShown || sizeChanged) {
      Log.i(TAG, "rect " + w + "x" + h + " at " + l + "," + t);
    }
  }

  private void hide() {
    if (view == null || !shown) return;
    shown = false;
    view.setLayoutParams(params());
    Log.i(TAG, "hidden (no video hole on screen)");
  }

  /** Whether MainActivity started Flutter transparent (the beta is really on). */
  private boolean windowTransparent() {
    if (activity == null) return false;
    android.graphics.drawable.Drawable bg = activity.getWindow().getDecorView().getBackground();
    return bg instanceof android.graphics.drawable.ColorDrawable
        && ((android.graphics.drawable.ColorDrawable) bg).getAlpha() == 0;
  }

  private String displayInfo() {
    if (activity == null) return "display: no activity";
    StringBuilder sb = new StringBuilder();
    Display d = activity.getWindowManager().getDefaultDisplay();
    if (Build.VERSION.SDK_INT >= 23) {
      Display.Mode m = d.getMode();
      sb.append("display mode ")
          .append(m.getPhysicalWidth()).append('x').append(m.getPhysicalHeight())
          .append(' ').append(String.format(java.util.Locale.US, "%.2f", m.getRefreshRate()))
          .append(" Hz");
    }
    if (Build.VERSION.SDK_INT >= 24) {
      Display.HdrCapabilities caps = d.getHdrCapabilities();
      List<String> types = new ArrayList<>();
      if (caps != null) {
        for (int t : caps.getSupportedHdrTypes()) types.add(hdrTypeName(t));
      }
      sb.append("; display HDR ").append(types.isEmpty() ? "none" : android.text.TextUtils.join("/", types));
    }
    if (Build.VERSION.SDK_INT >= 26) {
      sb.append("; window colorMode ").append(activity.getWindow().getColorMode());
      sb.append("; wide gamut ").append(d.isWideColorGamut());
    }
    if (Build.VERSION.SDK_INT >= 30) {
      sb.append("; min/max lum ").append(d.getHdrCapabilities() == null ? "-" :
          d.getHdrCapabilities().getDesiredMinLuminance() + "/" + d.getHdrCapabilities().getDesiredMaxLuminance());
    }
    sb.append("; window ")
        .append(activity.getWindow().getDecorView().getWidth()).append('x')
        .append(activity.getWindow().getDecorView().getHeight());
    return sb.toString();
  }

  private void logDisplay() {
    Log.i(TAG, displayInfo());
  }

  private static String hdrTypeName(int t) {
    switch (t) {
      case 1: return "DolbyVision";
      case 2: return "HDR10";
      case 3: return "HLG";
      case 4: return "HDR10+";
      default: return "type" + t;
    }
  }

  private static String colorName(@Nullable ColorInfo c) {
    if (c == null) return "color unknown";
    String transfer;
    switch (c.colorTransfer) {
      case 6: transfer = "PQ (HDR10)"; break;
      case 7: transfer = "HLG"; break;
      case 3: transfer = "SDR"; break;
      case 1: transfer = "linear"; break;
      case 2: transfer = "sRGB"; break;
      default: transfer = "transfer " + c.colorTransfer;
    }
    String space = c.colorSpace == 6 ? "BT.2020" : c.colorSpace == 1 ? "BT.709"
        : c.colorSpace == 2 ? "BT.601" : "space " + c.colorSpace;
    return transfer + ", " + space + ", range " + c.colorRange
        + (c.hdrStaticInfo != null ? ", HDR static info" : "");
  }

  private Map<String, Object> diagnostics() {
    Map<String, Object> out = new HashMap<>();
    out.put("player", attachedId);
    out.put("shown", shown);
    out.put("rect", width + "x" + height + " at " + left + "," + top);
    out.put("surface", surfaceState);
    out.put("decoder", decoder);
    out.put("format", inputFormat);
    out.put("videoSize", videoSize);
    out.put("firstFrame", firstFrame);
    out.put("dropped", droppedFrames);
    out.put("error", lastError);
    out.put("display", displayInfo());
    out.put("windowTransparent", windowTransparent());
    if (attachedPlayer != null) {
      out.put("tunneling", attachedPlayer.isTunnelingEnabled());
      Format f = attachedPlayer.getVideoFormat();
      if (f != null) out.put("playingFormat", describe(f));
    }
    return out;
  }

  private static String describe(Format f) {
    return f.width + "x" + f.height
        + " " + (f.frameRate > 0 ? String.format(java.util.Locale.US, "%.2f fps ", f.frameRate) : "")
        + f.sampleMimeType + " " + f.codecs + " " + colorName(f.colorInfo);
  }

  private final AnalyticsListener analytics =
      new AnalyticsListener() {
        @Override
        public void onVideoDecoderInitialized(
            @NonNull EventTime eventTime, @NonNull String decoderName,
            long initializedTimestampMs, long initializationDurationMs) {
          decoder = decoderName;
          Log.i(TAG, "decoder " + decoderName + " (" + initializationDurationMs + " ms)");
        }

        @Override
        public void onVideoInputFormatChanged(
            @NonNull EventTime eventTime, @NonNull Format format,
            @Nullable DecoderReuseEvaluation decoderReuseEvaluation) {
          inputFormat = describe(format);
          Log.i(TAG, "video format " + inputFormat);
        }

        @Override
        public void onVideoSizeChanged(@NonNull EventTime eventTime, @NonNull VideoSize size) {
          videoSize = size.width + "x" + size.height;
          Log.i(TAG, "video size " + videoSize + " (surface " + surfaceState + ")");
        }

        @Override
        public void onRenderedFirstFrame(
            @NonNull EventTime eventTime, @NonNull Object output, long renderTimeMs) {
          firstFrame = "rendered to " + output.getClass().getSimpleName();
          Log.i(TAG, "first frame " + firstFrame + " (surface " + surfaceState + ")");
        }

        @Override
        public void onDroppedVideoFrames(
            @NonNull EventTime eventTime, int dropped, long elapsedMs) {
          droppedFrames += dropped;
          Log.i(TAG, "dropped " + dropped + " frames in " + elapsedMs + " ms (total " + droppedFrames + ")");
        }

        @Override
        public void onPlayerError(@NonNull EventTime eventTime, @NonNull PlaybackException error) {
          lastError = error.getErrorCodeName() + ": " + error.getMessage();
          Log.w(TAG, "player error " + lastError);
        }
      };
}
