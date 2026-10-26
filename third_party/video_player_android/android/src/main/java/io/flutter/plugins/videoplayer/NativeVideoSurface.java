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
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.view.Surface;
import android.widget.ProgressBar;
import android.content.res.ColorStateList;
import android.os.Looper;
import android.util.Log;
import android.util.LongSparseArray;
import android.view.Display;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.ViewGroup;
import android.view.View;
import android.widget.ImageView;
import android.graphics.Color;
import android.graphics.Bitmap;
import android.view.PixelCopy;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
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
  // Formuler only: the second SurfaceView of a ping-pong pair. Its 4K/HDR video sits on a
  // hardware plane that PixelCopy/screencap read back as solid (0,150,0) green (checked on the
  // box 2026-10-24, ESPN 4K playing), so the outgoing picture can't be captured. Instead a live
  // zap moves the decoder to the spare surface, offscreen, and leaves the old surface on screen
  // holding its last real frame; the two swap once the new channel's first frame is drawn.
  @Nullable private SurfaceView spare;
  private boolean frozen; // spare is on screen showing the outgoing frame
  private final Runnable revealTask = () -> hideZapCover();
  @Nullable private ImageView zapCover;
  @Nullable private FrameLayout zapLayer;
  @Nullable private ProgressBar zapSpinner;
  private final ZapFrameCache frameCache = new ZapFrameCache();
  @Nullable private HandlerThread captureThread;
  @Nullable private Handler captureWorker;
  private boolean captureInFlight;
  private boolean disposed;
  private boolean frameReady;
  private int warmFailures;
  private long frameEpoch;
  private String warmCapture = "not captured";
  private final Runnable warmCaptureTask = () -> captureWarmFrame();
  @Nullable private Bitmap lastPicture;
  private final Runnable coverTimeout = () -> hideZapCover();
  private long attachedId = -1;
  @Nullable private ExoPlayer attachedPlayer;
  private boolean shown = false;
  private boolean enabled = false;
  private final Handler swapHandler = new Handler(Looper.getMainLooper());
  @Nullable private PendingSwap pendingSwap;
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
  private String lastPrepare = "-";
  private String lastCapture = "-";

  NativeVideoSurface(@NonNull BinaryMessenger messenger, @NonNull LongSparseArray<VideoPlayer> players) {
    this.players = players;
    methods = new MethodChannel(messenger, "vespertv/native_surface");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    disposed = true;
    cancelWarmCapture(true);
    if (captureThread != null) captureThread.quitSafely();
    cancelSwap("disposed");
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
      cancelSwap("disposed");
      Log.i(TAG, "player " + id + " disposed while attached");
      // release() follows immediately. Clearing the holder first needlessly
      // switches the decoder to a placeholder surface just before teardown.
      detach(false);
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      switch (call.method) {
        case "prepareNewPlayer":
          // Explicit replacement only; background retry candidates keep the
          // existing owner until adopted. No new decoder starts surface-less.
          if (enabled && attachedPlayer != null) {
            attachedPlayer.pause();
            detach();
          }
          result.success(null);
          return;
        case "replaceLive":
          replaceLive(call, result);
          return;
        case "configure":
          enabled = Boolean.TRUE.equals(call.argument("enabled"));
          if (enabled) ensureView();
          result.success(null);
          return;
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

  /** Only a new main player with no existing owner may claim the native output. */
  @Nullable SurfaceHolder holderForPreparation() {
    // Backup retries can prepare a candidate while the current player is still
    // running. Preserve that player's output until the candidate is adopted.
    if (!enabled) return null;
    if (attachedPlayer != null) {
      lastPrepare = "new player prepared WITHOUT the native surface (player " + attachedId + " still owns it)";
      Log.i(TAG, lastPrepare);
      return null;
    }
    if (!ensureView()) {
      lastPrepare = "new player prepared WITHOUT the native surface (no view)";
      Log.i(TAG, lastPrepare);
      return null;
    }
    // Why this matters (AMD's Fire TV Cube, LOG-Y74UW3): a decoder configured on a placeholder
    // surface and moved to the SurfaceView later stayed in 1080p SDR output on Amlogic.
    lastPrepare = "new player prepared ON the native surface (surface " + surfaceState + ")";
    Log.i(TAG, lastPrepare);
    return view.getHolder();
  }

  private void replaceLive(MethodCall call, MethodChannel.Result result) {
    Number id = call.argument("playerId");
    String url = call.argument("url");
    VideoPlayer player = id == null ? null : players.get(id.longValue());
    if (!enabled || activity == null || player == null || id.longValue() != attachedId
        || player.getExoPlayer() != attachedPlayer || !player.canReplaceNativeStream()
        || url == null || !(url.startsWith("http://") || url.startsWith("https://"))) {
      result.success(java.util.Collections.singletonMap("accepted", false));
      return;
    }
    Bitmap interruptedPicture = lastPicture;
    // Not cancelSwap: that would drop the cover/frozen frame just before this zap reuses it.
    if (pendingSwap != null) pendingSwap.supersede();
    if (interruptedPicture != null
        && io.flutter.plugins.videoplayer.platformview.FormulerVideoRenderer.isTargetDevice()) {
      retainCapturedPicture(interruptedPicture);
    }
    VideoAsset asset = VideoAsset.fromRemoteUrl(url,
        Boolean.TRUE.equals(call.argument("hls")) ? VideoAsset.StreamingFormat.HTTP_LIVE
            : VideoAsset.StreamingFormat.UNKNOWN, new HashMap<>(), null);
    PendingSwap swap = new PendingSwap(player.getExoPlayer(), result);
    pendingSwap = swap;
    swap.exo.addListener(swap);
    swapHandler.postDelayed(swap.timeout, 15000);
    firstFrame = lastError = "-";
    droppedFrames = 0;
    Log.i(TAG, "reusing player " + attachedId + " for live zap (surface " + surfaceState + ")");
    if (freezeOnSpare(player, asset, swap)) return;
    captureBeforeSwap(swap, () -> {
      if (pendingSwap != swap || activity == null) return;
      showZapCover();
      try {
        player.replaceNativeStream(activity, asset);
      } catch (RuntimeException e) {
        swap.fail("source replacement failed");
      }
    });
  }

  /**
   * Formuler: leave the outgoing channel's last frame on screen (no pixel copy) and start the
   * new stream on the offscreen spare surface. A zap during a zap keeps the same frozen frame.
   */
  private boolean freezeOnSpare(VideoPlayer player, VideoAsset asset, PendingSwap swap) {
    if (spare == null || !shown || activity == null) return false;
    if (!frozen) {
      Surface next = spare.getHolder().getSurface();
      if (next == null || !next.isValid()) return false;
      SurfaceView outgoing = view;
      view = spare;
      spare = outgoing;
      frozen = true;
    }
    swapHandler.removeCallbacks(revealTask);
    lastCapture = "outgoing frame kept on screen + spinner";
    Log.i(TAG, lastCapture);
    try {
      // Source first, output second: the old decoder stops while still on the frozen surface,
      // so no outgoing-channel frame can reach (and "first frame"-reveal) the new one.
      player.replaceNativeStream(activity, asset);
      if (player.nativeSurfaceHolder != view.getHolder()) {
        swap.exo.setVideoSurfaceHolder(view.getHolder());
        player.nativeSurfaceHolder = view.getHolder();
      }
    } catch (RuntimeException e) {
      swap.fail("source replacement failed");
      return true;
    }
    layout();
    showZapCover();
    return true;
  }

  /** One temporary, bounded frame; never saved to disk or included in logs. */
  private void captureBeforeSwap(PendingSwap swap, Runnable replace) {
    if (io.flutter.plugins.videoplayer.platformview.FormulerVideoRenderer.isTargetDevice()) {
      // The zap itself never waits for a copy. A recent snapshot was prepared
      // while this channel was stable; in-flight copies are invalidated here.
      Bitmap frozen = frameCache.take(SystemClock.uptimeMillis());
      Bitmap previous = lastPicture;
      cancelWarmCapture(true);
      hideZapCover();
      if (frozen == null) frozen = previous; // rapid zaps keep the last valid outgoing picture
      if (frozen != null) {
        retainCapturedPicture(frozen);
        lastCapture = "cached frame + spinner";
      } else {
        lastCapture = "no usable cached frame; logo + spinner";
      }
      Log.i(TAG, lastCapture);
      replace.run();
      return;
    }
    if (Build.VERSION.SDK_INT < 26 || view == null || !shown
        || view.getHolder().getSurface() == null || !view.getHolder().getSurface().isValid()) {
      replace.run();
      return;
    }
    final Bitmap picture;
    try {
      float scale = Math.min(1f, 1280f / Math.max(width, height));
      picture = Bitmap.createBitmap(Math.max(1, Math.round(width * scale)),
          Math.max(1, Math.round(height * scale)), Bitmap.Config.ARGB_8888);
    } catch (OutOfMemoryError | IllegalArgumentException error) {
      replace.run();
      return;
    }
    final boolean[] started = {false};
    Runnable start = () -> {
      if (started[0]) return;
      started[0] = true;
      replace.run();
    };
    // A slow/unsupported copy must not delay the zap or leave audio waiting.
    swapHandler.postDelayed(start, 80);
    try {
      PixelCopy.request(view, picture, status -> {
        swapHandler.removeCallbacks(start);
        if (!started[0] && pendingSwap == swap && status == PixelCopy.SUCCESS) {
          retainCapturedPicture(picture);
        } else {
          picture.recycle();
        }
        start.run();
      }, swapHandler);
    } catch (RuntimeException error) {
      swapHandler.removeCallbacks(start);
      picture.recycle();
      start.run();
    }
  }

  private void cancelWarmCapture(boolean forgetFrame) {
    frameEpoch++;
    swapHandler.removeCallbacks(warmCaptureTask);
    if (forgetFrame) {
      frameReady = false;
      warmFailures = 0;
      warmCapture = "awaiting stable frame";
      frameCache.clear();
    }
  }

  private void scheduleWarmCapture(long delay) {
    swapHandler.removeCallbacks(warmCaptureTask);
    if (!disposed && enabled && shown && frameReady && warmFailures < 3 && attachedPlayer != null
        && spare == null
        && io.flutter.plugins.videoplayer.platformview.FormulerVideoRenderer.isTargetDevice()) {
      swapHandler.postDelayed(warmCaptureTask, delay);
    }
  }

  private void captureWarmFrame() {
    if (disposed || !frameReady || !shown || view == null || attachedPlayer == null) return;
    if (captureInFlight) { scheduleWarmCapture(1500); return; }
    final Surface target = view.getHolder().getSurface();
    if (target == null || !target.isValid()) { scheduleWarmCapture(1500); return; }
    if (captureWorker == null) {
      captureThread = new HandlerThread("VesperZapCapture");
      captureThread.start();
      captureWorker = new Handler(captureThread.getLooper());
    }
    final Handler worker = captureWorker;
    final long epoch = frameEpoch;
    final long capturedAt = SystemClock.uptimeMillis();
    final float scale = Math.min(1f, 720f / Math.max(width, height));
    final int bitmapWidth = Math.max(1, Math.round(width * scale));
    final int bitmapHeight = Math.max(1, Math.round(height * scale));
    captureInFlight = true;
    worker.post(() -> {
      final Bitmap picture;
      try {
        picture = Bitmap.createBitmap(bitmapWidth, bitmapHeight, Bitmap.Config.ARGB_8888);
      } catch (OutOfMemoryError | IllegalArgumentException error) {
        swapHandler.post(() -> finishWarmCapture(epoch, capturedAt, null, false));
        return;
      }
      try {
        PixelCopy.request(target, picture, status -> {
          boolean usable = status == PixelCopy.SUCCESS && ZapFrameCache.usable(picture);
          swapHandler.post(() -> finishWarmCapture(epoch, capturedAt, picture, usable));
        }, worker);
      } catch (RuntimeException error) {
        swapHandler.post(() -> finishWarmCapture(epoch, capturedAt, picture, false));
      }
    });
  }

  // Main-thread publication: stale captures never become another channel's cover.
  void finishWarmCapture(long epoch, long capturedAt, @Nullable Bitmap picture, boolean usable) {
    captureInFlight = false;
    if (disposed || epoch != frameEpoch || !frameReady || !shown) {
      if (picture != null) picture.recycle();
      return;
    }
    String previousStatus = warmCapture;
    if (picture != null && usable && SystemClock.uptimeMillis() - capturedAt <= 2500) {
      frameCache.put(picture, capturedAt);
      warmFailures = 0;
      warmCapture = "usable frame cached";
    } else {
      if (picture != null) picture.recycle();
      warmFailures++;
      warmCapture = warmFailures >= 3 ? "capture unavailable; retries stopped for this channel"
          : "blank/green/failed copy rejected";
    }
    if (!warmCapture.equals(previousStatus)) Log.i(TAG, "warm capture: " + warmCapture);
    scheduleWarmCapture(1500);
  }

  void retainCapturedPicture(Bitmap picture) {
    hideZapCover();
    lastPicture = picture;
    if (zapCover != null) zapCover.setImageBitmap(picture);
    lastCapture = "last frame retained";
    Log.i(TAG, "last video frame retained for decoder swap");
  }

  private void cancelSwap(String reason) {
    if (pendingSwap != null) pendingSwap.fail(reason);
  }

  private final class PendingSwap implements Player.Listener {
    final ExoPlayer exo;
    final MethodChannel.Result result;
    final Runnable timeout = () -> fail("live zap timed out");
    PendingSwap(ExoPlayer exo, MethodChannel.Result result) {
      this.exo = exo;
      this.result = result;
    }
    private boolean finish() {
      if (pendingSwap != this) return false;
      pendingSwap = null;
      swapHandler.removeCallbacks(timeout);
      exo.removeListener(this);
      return true;
    }
    void supersede() {
      if (finish()) result.error("NativeLiveZap", "superseded", null);
    }
    void fail(String reason) {
      if (finish()) { hideZapCover(); result.error("NativeLiveZap", reason, null); }
    }
    @Override public void onPlayerError(@NonNull PlaybackException error) {
      fail("live source error " + error.getErrorCodeName());
    }
    @Override public void onPlaybackStateChanged(int state) {
      if (state != Player.STATE_READY || !finish()) return;
      VideoSize size = exo.getVideoSize();
      Map<String, Object> response = new HashMap<>();
      response.put("accepted", true);
      response.put("width", size.width);
      response.put("height", size.height);
      result.success(response);
    }
  }

  void onPlayerCreated(VideoPlayer player, long id) {
    if (view != null && player.nativeSurfaceHolder == view.getHolder()) attach(id);
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
    view = newSurface("A");
    // Index 0 = behind the Flutter view. Default z-order: the surface punches through the
    // (transparent) window, under Flutter's own drawing.
    content.addView(view, 0, params(shown));
    if (io.flutter.plugins.videoplayer.platformview.FormulerVideoRenderer.isTargetDevice()) {
      spare = newSurface("B");
      content.addView(spare, 0, params(false));
    }
    Log.i(TAG, "video surface added behind Flutter (content children " + content.getChildCount()
        + (spare != null ? ", spare for zaps" : "") + ")");
    zapCover = new ImageView(activity);
    zapCover.setImageDrawable(activity.getApplicationInfo().loadIcon(activity.getPackageManager()));
    zapCover.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
    zapCover.setBackgroundColor(Color.rgb(12, 12, 16));
    zapLayer = new FrameLayout(activity);
    zapLayer.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
    zapLayer.addView(zapCover, new FrameLayout.LayoutParams(-1, -1));
    zapSpinner = new ProgressBar(activity, null, android.R.attr.progressBarStyleSmall);
    zapSpinner.setIndeterminate(true);
    zapSpinner.setIndeterminateTintList(ColorStateList.valueOf(Color.WHITE));
    int spinnerSize = Math.round(32 * activity.getResources().getDisplayMetrics().density);
    zapLayer.addView(zapSpinner, new FrameLayout.LayoutParams(spinnerSize, spinnerSize, Gravity.CENTER));
    zapLayer.setVisibility(View.GONE);
    // After both surfaces: a SurfaceView clears its rect in the window when drawn, which
    // would erase a spinner drawn before it.
    int above = Math.max(content.indexOfChild(view), spare == null ? -1 : content.indexOfChild(spare));
    content.addView(zapLayer, above + 1, params(shown));
    logDisplay();
    return true;
  }

  private SurfaceView newSurface(String label) {
    SurfaceView surface = new SurfaceView(activity);
    surface.getHolder().addCallback(
        new SurfaceHolder.Callback() {
          // Only the surface the player draws into reports into the diagnostics.
          private boolean current(SurfaceHolder holder) {
            return view != null && holder == view.getHolder();
          }

          @Override
          public void surfaceCreated(@NonNull SurfaceHolder holder) {
            if (current(holder)) surfaceState = "created";
            Log.i(TAG, "surface " + label + " created");
          }

          @Override
          public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int w, int h) {
            String state = w + "x" + h + " fmt " + format;
            if (current(holder)) surfaceState = state;
            Log.i(TAG, "surface " + label + " changed " + state);
          }

          @Override
          public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
            if (current(holder)) {
              cancelWarmCapture(true);
              surfaceState = "destroyed";
            }
            Log.i(TAG, "surface " + label + " destroyed");
          }
        });
    return surface;
  }

  private void layout() {
    if (view != null) view.setLayoutParams(params(shown && !frozen));
    if (spare != null) spare.setLayoutParams(params(shown && frozen));
    if (zapLayer != null) zapLayer.setLayoutParams(params(shown));
  }

  private void showZapCover() {
    if (zapCover == null || !shown) return;
    zapLayer.setLayoutParams(params(shown));
    // Frozen: the real outgoing frame is on screen below, so only the spinner shows.
    zapCover.setVisibility(frozen ? View.INVISIBLE : View.VISIBLE);
    int spinnerSize = Math.max(1, Math.min(Math.round(32 * activity.getResources().getDisplayMetrics().density),
        Math.min(width, height) / 8));
    zapSpinner.setLayoutParams(new FrameLayout.LayoutParams(spinnerSize, spinnerSize, Gravity.CENTER));
    int pad = lastPicture == null ? Math.max(1, Math.min(width, height) / 3) : 0;
    zapCover.setScaleType(lastPicture == null ? ImageView.ScaleType.CENTER_INSIDE : ImageView.ScaleType.FIT_XY);
    zapCover.setPadding(pad, pad, pad, pad);
    zapLayer.setVisibility(View.VISIBLE);
    swapHandler.removeCallbacks(coverTimeout);
    swapHandler.postDelayed(coverTimeout, 15000);
  }

  private void hideZapCover() {
    swapHandler.removeCallbacks(coverTimeout);
    swapHandler.removeCallbacks(revealTask);
    if (frozen) {
      frozen = false;
      layout(); // the new channel's surface on screen, the frozen one off
    }
    if (zapCover != null) {
      if (zapLayer != null) zapLayer.setVisibility(View.GONE);
      if (activity != null) {
        zapCover.setImageDrawable(activity.getApplicationInfo().loadIcon(activity.getPackageManager()));
      }
    }
    if (lastPicture != null) {
      // A RenderThread display list can still reference the previous drawable
      // for this frame. Let the VM release it after that list retires.
      lastPicture = null;
    }
  }

  private void removeView() {
    cancelWarmCapture(true);
    hideZapCover();
    if (zapLayer != null) {
      ViewGroup coverParent = (ViewGroup) zapLayer.getParent();
      if (coverParent != null) coverParent.removeView(zapLayer);
      zapCover = null;
      zapSpinner = null;
      zapLayer = null;
    }
    if (spare != null) {
      ViewGroup spareParent = (ViewGroup) spare.getParent();
      if (spareParent != null) spareParent.removeView(spare);
      spare = null;
    }
    if (view == null) return;
    ViewGroup parent = (ViewGroup) view.getParent();
    if (parent != null) parent.removeView(view);
    view = null;
    shown = false;
    surfaceState = "none";
  }

  /** Off-screen (right of the display) instead of GONE: GONE destroys the surface. */
  private FrameLayout.LayoutParams params(boolean onScreen) {
    int w = Math.max(width, 1);
    int h = Math.max(height, 1);
    FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(w, h, Gravity.TOP | Gravity.START);
    if (onScreen) {
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
      decoder = player.nativeVideoDecoderName == null ? "-" : player.nativeVideoDecoderName;
      Format currentFormat = exo.getVideoFormat();
      if (currentFormat != null) inputFormat = describe(currentFormat);
      VideoSize currentSize = exo.getVideoSize();
      if (currentSize != null && currentSize.width > 0 && currentSize.height > 0) {
        videoSize = currentSize.width + "x" + currentSize.height;
      }
      exo.addAnalyticsListener(analytics);
      if (player.nativeSurfaceHolder != view.getHolder()) {
        exo.setVideoSurfaceHolder(view.getHolder());
        player.nativeSurfaceHolder = view.getHolder();
      }
      // Match PlatformVideoView's API-28 paused-output workaround.
      if (Build.VERSION.SDK_INT == 28 && !exo.getPlayWhenReady()) {
        long position = exo.getCurrentPosition();
        exo.seekTo(position == 0 ? 1 : position);
      }
      Log.i(TAG, "attached player " + id + " (surface " + surfaceState + ")");
    }
    out.put("ok", true);
    return out;
  }

  private void detach() {
    detach(true);
  }

  private void detach(boolean clearOutput) {
    cancelWarmCapture(true);
    cancelSwap("detached");
    hideZapCover();
    if (attachedPlayer != null) {
      try {
        attachedPlayer.removeAnalyticsListener(analytics);
        if (clearOutput && view != null) {
          attachedPlayer.clearVideoSurfaceHolder(view.getHolder());
          VideoPlayer previous = players.get(attachedId);
          if (previous != null) previous.nativeSurfaceHolder = null;
        }
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
    layout();
    if (!wasShown) scheduleWarmCapture(250);
    // Positions change every frame during animations: log only show/size changes.
    if (!wasShown || sizeChanged) {
      Log.i(TAG, "rect " + w + "x" + h + " at " + l + "," + t);
    }
  }

  private void hide() {
    cancelWarmCapture(false);
    hideZapCover();
    if (view == null || !shown) return;
    shown = false;
    layout();
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
    out.put("prepare", lastPrepare);
    out.put("zapCapture", lastCapture);
    out.put("warmCapture", warmCapture);
    out.put("zapCover", zapLayer != null && zapLayer.getVisibility() == View.VISIBLE);
    out.put("display", displayInfo());
    out.put("windowTransparent", windowTransparent());
    if (attachedPlayer != null) {
      out.put("tunneling", attachedPlayer.isTunnelingEnabled());
      Format f = attachedPlayer.getVideoFormat();
      if (f != null) out.put("playingFormat", describe(f));
      VideoPlayer registered = players.get(attachedId);
      if (registered != null) StatsBridge.addHdrStats(out, f, registered.frameRateProbe);
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
          if (decoderReuseEvaluation != null) {
            Log.i(TAG, "decoder reuse result=" + decoderReuseEvaluation.result
                + " reasons=" + decoderReuseEvaluation.discardReasons);
          }
        }

        @Override
        public void onVideoSizeChanged(@NonNull EventTime eventTime, @NonNull VideoSize size) {
          videoSize = size.width + "x" + size.height;
          Log.i(TAG, "video size " + videoSize + " (surface " + surfaceState + ")");
        }

        @Override
        public void onRenderedFirstFrame(
            @NonNull EventTime eventTime, @NonNull Object output, long renderTimeMs) {
          if (frozen && view != null && output == view.getHolder().getSurface()) {
            // Reported when the frame is released to the surface, a vsync or two before it
            // is latched: keep the frozen frame up a moment longer so the swap never shows
            // the spare's stale content.
            swapHandler.removeCallbacks(revealTask);
            swapHandler.postDelayed(revealTask, 120);
          } else if (!frozen) {
            hideZapCover();
          }
          frameReady = true;
          scheduleWarmCapture(250);
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
          cancelWarmCapture(true);
          hideZapCover();
          lastError = error.getErrorCodeName() + ": " + error.getMessage();
          Log.w(TAG, "player error " + lastError);
        }
      };
}
