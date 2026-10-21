// VesperTV patch: the Data pool's measured numbers (MethodChannel "vespertv/stats"). Dart samples
// getStats twice and turns the differences into a real bitrate (StreamStats' bytes) and a real
// frame rate (the video decoder's rendered/dropped counters) — live MPEG-TS declares neither.
package io.flutter.plugins.videoplayer;

import android.os.SystemClock;
import android.util.LongSparseArray;
import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.annotation.Nullable;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DecoderCounters;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

@OptIn(markerClass = UnstableApi.class)
final class StatsBridge implements MethodChannel.MethodCallHandler {
  private final LongSparseArray<VideoPlayer> players;
  private final MethodChannel methods;

  StatsBridge(@NonNull BinaryMessenger messenger, @NonNull LongSparseArray<VideoPlayer> players) {
    this.players = players;
    methods = new MethodChannel(messenger, "vespertv/stats");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (!"getStats".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Number idArg = call.argument("playerId");
    VideoPlayer player = idArg == null ? null : players.get(idArg.longValue());
    if (player == null) {
      result.error("no_player", "No player " + idArg, null);
      return;
    }
    Map<String, Object> m = new HashMap<>();
    m.put("nowMs", SystemClock.elapsedRealtime());
    @Nullable StreamStats stats = player.streamStats;
    if (stats != null) m.put("bytes", stats.bytes.get());
    @Nullable DecoderCounters video = player.getExoPlayer().getVideoDecoderCounters();
    if (video != null) {
      video.ensureUpdated();
      m.put("rendered", video.renderedOutputBufferCount);
      m.put("dropped", video.droppedBufferCount);
    }
    result.success(m);
  }
}
