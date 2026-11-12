// VesperTV patch: the main player's decoded sound for automatic live subtitles (owner,
// 2026-11-12; Dart side lib/services/auto_subtitles.dart). A TeeAudioProcessor in the
// platform-view player's audio sink (PlatformViewVideoPlayer) copies its PCM here. Only while
// Flutter listens on EventChannel "vespertv/audio_tap" is it mixed to mono, resampled to 16 kHz
// and sent in ~100 ms chunks of 16-bit little-endian samples; otherwise the tee costs one check
// per buffer. Passthrough audio (Dolby / DTS to the receiver) is never decoded and gives nothing.
// Texture players (Multiview tiles) have no tap.

package io.flutter.plugins.videoplayer;

import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.audio.TeeAudioProcessor;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

@OptIn(markerClass = UnstableApi.class)
public final class AudioTap implements EventChannel.StreamHandler {
  /** Output sample rate (what speech models take). */
  static final int RATE = 16000;

  /** Samples per chunk sent to Flutter (100 ms). */
  static final int CHUNK = RATE / 10;

  @Nullable private static volatile EventChannel.EventSink sink;
  private static final Handler main = new Handler(Looper.getMainLooper());

  private final EventChannel events;

  AudioTap(@NonNull BinaryMessenger messenger) {
    events = new EventChannel(messenger, "vespertv/audio_tap");
    events.setStreamHandler(this);
  }

  void dispose() {
    events.setStreamHandler(null);
    sink = null;
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    sink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    sink = null;
  }

  static boolean listening() {
    return sink != null;
  }

  /** A new tee for one player's audio sink (processors keep per-player state). */
  public static AudioProcessor processor() {
    return new TeeAudioProcessor(new Downmix());
  }

  /** Mono 16 kHz from any PCM layout: channels averaged, then box-filter resampling. */
  static final class Downmix implements TeeAudioProcessor.AudioBufferSink {
    private int rate;
    private int channels;
    private int encoding = C.ENCODING_INVALID;
    private double step;
    private double acc;
    private int count;
    private double next;
    private double inPos;
    private short[] out = new short[CHUNK];
    private int outLen;

    @Override
    public void flush(int sampleRateHz, int channelCount, int encoding) {
      rate = sampleRateHz;
      channels = channelCount;
      this.encoding = encoding;
      step = rate > 0 ? rate / (double) RATE : 0;
      acc = 0;
      count = 0;
      inPos = 0;
      next = step;
      outLen = 0;
    }

    @Override
    public void handleBuffer(@NonNull ByteBuffer buffer) {
      if (sink == null || step <= 0 || channels <= 0) return;
      boolean isFloat = encoding == C.ENCODING_PCM_FLOAT;
      if (!isFloat && encoding != C.ENCODING_PCM_16BIT) return;
      ByteBuffer b = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN);
      int frameBytes = channels * (isFloat ? 4 : 2);
      while (b.remaining() >= frameBytes) {
        double mono = 0;
        for (int c = 0; c < channels; c++) {
          mono += isFloat ? b.getFloat() : b.getShort() / 32768.0;
        }
        acc += mono / channels;
        count++;
        inPos += 1;
        if (inPos >= next) {
          next += step;
          double v = Math.max(-1.0, Math.min(1.0, acc / count));
          acc = 0;
          count = 0;
          out[outLen++] = (short) Math.round(v * 32767);
          if (outLen == CHUNK) send();
        }
      }
    }

    private void send() {
      byte[] bytes = new byte[outLen * 2];
      for (int i = 0; i < outLen; i++) {
        bytes[2 * i] = (byte) (out[i] & 0xff);
        bytes[2 * i + 1] = (byte) ((out[i] >> 8) & 0xff);
      }
      outLen = 0;
      main.post(
          () -> {
            EventChannel.EventSink s = sink;
            if (s != null) s.success(bytes);
          });
    }
  }
}
