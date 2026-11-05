// VesperTV patch: Audio delay / A/V sync (Settings > Playback > Audio and the player's
// Audio sync button, MethodChannel "vespertv/audio" setAudioDelay). The audio sink is the
// player's master clock: the video renderer shows each frame when the sink's position reaches
// it. Reporting the position shifted by the delay moves the picture against the sound, so a
// positive delay = sound later (picture earlier), negative = sound earlier. Works with
// passthrough too (the position still comes from the AudioTrack). Read on every position query,
// so a change applies at once while playing. Shield + soundbar user, sound ahead on some
// sports channels (2026-11-05).
package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.audio.AudioSink;
import androidx.media3.exoplayer.audio.ForwardingAudioSink;

@OptIn(markerClass = UnstableApi.class)
public final class AudioDelay extends ForwardingAudioSink {
  /** Limits of the setting, also enforced on the Dart side. */
  public static final int MAX_MS = 1000;

  private static volatile long delayUs = 0;

  public static void setDelayMs(int ms) {
    delayUs = Math.max(-MAX_MS, Math.min(MAX_MS, ms)) * 1000L;
  }

  public static AudioSink wrap(@NonNull AudioSink sink) {
    return new AudioDelay(sink);
  }

  private AudioDelay(AudioSink sink) {
    super(sink);
  }

  @Override
  public long getCurrentPositionUs(boolean sourceEnded) {
    final long position = super.getCurrentPositionUs(sourceEnded);
    if (position == CURRENT_POSITION_NOT_SET) return position;
    return Math.max(0, position + delayUs);
  }
}
