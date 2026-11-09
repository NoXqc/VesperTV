package io.flutter.plugins.videoplayer;

import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.DataReader;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.ParsableBitArray;
import androidx.media3.common.util.ParsableByteArray;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.extractor.Ac3Util;
import androidx.media3.extractor.Extractor;
import androidx.media3.extractor.ExtractorInput;
import androidx.media3.extractor.ExtractorOutput;
import androidx.media3.extractor.ExtractorsFactory;
import androidx.media3.extractor.PositionHolder;
import androidx.media3.extractor.SeekMap;
import androidx.media3.extractor.SniffFailure;
import androidx.media3.extractor.TrackOutput;
import androidx.media3.extractor.mkv.MatroskaExtractor;
import androidx.media3.extractor.text.SubtitleParser;
import java.io.ByteArrayOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * VesperTV: Dolby Atmos in MKV files (Media Hub). MatroskaExtractor names every E-AC-3 track
 * plain "audio/eac3"; only the TS reader (IPTV) and MP4's dec3 box detect Atmos (E-AC-3 JOC).
 * This reads the first frame of an MKV E-AC-3 track with the parser the TS reader uses (Ac3Util)
 * and, when it carries JOC, gives the track the codecs string "ec+3" (what HLS manifests say for
 * Atmos). The MIME type stays "audio/eac3", so decoding and passthrough don't change; the Data
 * pool and the ATMOS badge read the codecs (Discord, 2026-11-08: the TV said Dolby Atmos, the
 * Data pool said E-AC-3 5.1).
 *
 * <p>TrueHD the same way (owner, 2026-11-09: a TrueHD Atmos 7.1 remux showed "7.1"): Atmos is the
 * 16-channel presentation, flagged in the major sync header that starts a TrueHD stream's first
 * frame. The track gets the codecs string {@link #TRUEHD_ATMOS_CODECS}; the MIME type stays
 * "audio/true-hd" (nothing in media3 reads codecs for it).
 *
 * <p>The track's format waits for its first frame, as the TS reader's does (preparing waits for
 * every track's format; the first audio frame is in the file's first cluster). A track whose
 * frame doesn't come gets its format unchanged once other tracks wrote {@link #GIVE_UP_SAMPLES}.
 */
@OptIn(markerClass = UnstableApi.class)
final class MatroskaAtmos {
  static final String ATMOS_CODECS = "ec+3";
  static final String TRUEHD_ATMOS_CODECS = "truehd-atmos";
  static final int GIVE_UP_SAMPLES = 500;
  /** Ac3Reader's header size: the whole bsi up to addbsi fits. */
  private static final int HEADER_BYTES = 128;
  private static final int MAX_HELD_BYTES = 1 << 20;

  private MatroskaAtmos() {}

  static ExtractorsFactory wrap(@NonNull ExtractorsFactory factory) {
    return new Factory(factory);
  }

  /** True when [frame] starts with an E-AC-3 syncframe whose bsi flags JOC (Dolby Atmos). */
  static boolean isJoc(@NonNull byte[] frame) {
    if (frame.length < 6 || frame[0] != 0x0B || frame[1] != 0x77) return false;
    try {
      ParsableBitArray bits = new ParsableBitArray(Arrays.copyOf(frame, HEADER_BYTES));
      return MimeTypes.AUDIO_E_AC3_JOC.equals(Ac3Util.parseAc3SyncframeInfo(bits).mimeType);
    } catch (RuntimeException e) {
      return false;
    }
  }

  /**
   * True when [frame] starts with a TrueHD access unit whose major sync announces the 16-channel
   * presentation (Dolby Atmos): the top bit of substream_info, as MediaInfo reads it. Layout from
   * the unit's start: 2 bytes length, 2 timing, format_sync F8726FBA (bytes 4-7), format_info,
   * signature B752 (12-13), flags, reserved, peak rate, substreams (byte 20, high nibble),
   * substream_info (byte 21).
   */
  static boolean isTrueHdAtmos(@NonNull byte[] frame) {
    if (frame.length < 22) return false;
    if ((frame[4] & 0xFF) != 0xF8
        || (frame[5] & 0xFF) != 0x72
        || (frame[6] & 0xFF) != 0x6F
        || (frame[7] & 0xFF) != 0xBA) return false;
    if ((frame[12] & 0xFF) != 0xB7 || (frame[13] & 0xFF) != 0x52) return false;
    int substreams = (frame[20] & 0xFF) >> 4;
    return substreams >= 4 && (frame[21] & 0x80) != 0;
  }

  private static boolean isTrueHd(Format format) {
    return MimeTypes.AUDIO_TRUEHD.equals(format.sampleMimeType) && format.codecs == null;
  }

  private static boolean mayBeAtmos(Format format) {
    return (MimeTypes.AUDIO_E_AC3.equals(format.sampleMimeType)
            && (format.codecs == null || format.codecs.startsWith("ec-3")))
        || isTrueHd(format);
  }

  /** The held format's frame check: E-AC-3 JOC or TrueHD's 16-channel presentation. */
  static boolean isAtmosFrame(@NonNull Format format, @NonNull byte[] frame) {
    return MimeTypes.AUDIO_TRUEHD.equals(format.sampleMimeType)
        ? isTrueHdAtmos(frame)
        : isJoc(frame);
  }

  private static final class Factory implements ExtractorsFactory {
    private final ExtractorsFactory delegate;

    Factory(ExtractorsFactory delegate) {
      this.delegate = delegate;
    }

    @NonNull
    @Override
    public Extractor[] createExtractors() {
      return wrapMatroska(delegate.createExtractors());
    }

    @NonNull
    @Override
    public Extractor[] createExtractors(
        @NonNull Uri uri, @NonNull Map<String, List<String>> responseHeaders) {
      return wrapMatroska(delegate.createExtractors(uri, responseHeaders));
    }

    // DefaultMediaSourceFactory sets subtitles up through these; they must reach the real
    // factory or embedded MKV subtitles stop being parsed.
    @NonNull
    @Override
    public ExtractorsFactory experimentalSetTextTrackTranscodingEnabled(boolean enabled) {
      delegate.experimentalSetTextTrackTranscodingEnabled(enabled);
      return this;
    }

    @NonNull
    @Override
    public ExtractorsFactory setSubtitleParserFactory(@NonNull SubtitleParser.Factory factory) {
      delegate.setSubtitleParserFactory(factory);
      return this;
    }

    @NonNull
    @Override
    public ExtractorsFactory experimentalSetCodecsToParseWithinGopSampleDependencies(int codecs) {
      delegate.experimentalSetCodecsToParseWithinGopSampleDependencies(codecs);
      return this;
    }

    private static Extractor[] wrapMatroska(Extractor[] extractors) {
      for (int i = 0; i < extractors.length; i++) {
        if (extractors[i].getUnderlyingImplementation() instanceof MatroskaExtractor) {
          extractors[i] = new WrappedExtractor(extractors[i]);
        }
      }
      return extractors;
    }
  }

  private static final class WrappedExtractor implements Extractor {
    private final Extractor delegate;
    @Nullable private Output output;

    WrappedExtractor(Extractor delegate) {
      this.delegate = delegate;
    }

    @Override
    public boolean sniff(@NonNull ExtractorInput input) throws IOException {
      return delegate.sniff(input);
    }

    @NonNull
    @Override
    public List<SniffFailure> getSniffFailureDetails() {
      return delegate.getSniffFailureDetails();
    }

    @Override
    public void init(@NonNull ExtractorOutput out) {
      output = new Output(out);
      delegate.init(output);
    }

    @Override
    public int read(@NonNull ExtractorInput input, @NonNull PositionHolder seekPosition)
        throws IOException {
      return delegate.read(input, seekPosition);
    }

    @Override
    public void seek(long position, long timeUs) {
      // The sample queues drop a half-written sample on seek; so do we.
      if (output != null) output.dropPartialSamples();
      delegate.seek(position, timeUs);
    }

    @Override
    public void release() {
      delegate.release();
    }

    @NonNull
    @Override
    public Extractor getUnderlyingImplementation() {
      return delegate.getUnderlyingImplementation();
    }
  }

  /** Visible for tests: wraps the player's output for one MKV file. */
  static final class Output implements ExtractorOutput {
    private final ExtractorOutput delegate;
    private final List<Track> tracks = new ArrayList<>();
    private int samplesWhileHeld;

    Output(ExtractorOutput delegate) {
      this.delegate = delegate;
    }

    @NonNull
    @Override
    public TrackOutput track(int id, int type) {
      Track track = new Track(this, delegate.track(id, type));
      tracks.add(track);
      return track;
    }

    @Override
    public void endTracks() {
      delegate.endTracks();
    }

    @Override
    public void seekMap(@NonNull SeekMap seekMap) {
      delegate.seekMap(seekMap);
    }

    void dropPartialSamples() {
      for (Track track : tracks) track.dropHeldData();
    }

    void sampleWritten() {
      boolean held = false;
      for (Track track : tracks) held |= track.heldFormat != null;
      if (!held) {
        samplesWhileHeld = 0;
        return;
      }
      if (++samplesWhileHeld < GIVE_UP_SAMPLES) return;
      for (Track track : tracks) if (track.heldFormat != null) track.release(false);
    }
  }

  private static final class Track implements TrackOutput {
    private final Output owner;
    private final TrackOutput delegate;
    /** An E-AC-3 format waiting for its first frame. */
    @Nullable Format heldFormat;
    private final List<byte[]> heldData = new ArrayList<>();
    private final List<Integer> heldParts = new ArrayList<>();
    private int heldBytes;
    private boolean decided;
    private boolean atmos;

    Track(Output owner, TrackOutput delegate) {
      this.owner = owner;
      this.delegate = delegate;
    }

    @Override
    public void durationUs(long durationUs) {
      delegate.durationUs(durationUs);
    }

    @Override
    public void format(@NonNull Format format) {
      if (decided) {
        delegate.format(atmos ? withAtmos(format) : format);
      } else if (mayBeAtmos(format)) {
        heldFormat = format;
      } else {
        if (heldFormat != null) release(false);
        delegate.format(format);
      }
    }

    @Override
    public int sampleData(
        @NonNull DataReader input, int length, boolean allowEndOfInput, int sampleDataPart)
        throws IOException {
      if (heldFormat == null) {
        return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart);
      }
      byte[] bytes = new byte[Math.min(length, 64 * 1024)];
      int read = input.read(bytes, 0, bytes.length);
      if (read == C.RESULT_END_OF_INPUT) {
        if (allowEndOfInput) return C.RESULT_END_OF_INPUT;
        throw new EOFException();
      }
      hold(Arrays.copyOf(bytes, read), sampleDataPart);
      return read;
    }

    @Override
    public void sampleData(@NonNull ParsableByteArray data, int length, int sampleDataPart) {
      if (heldFormat == null) {
        delegate.sampleData(data, length, sampleDataPart);
        return;
      }
      byte[] bytes = new byte[length];
      data.readBytes(bytes, 0, length);
      hold(bytes, sampleDataPart);
    }

    @Override
    public void sampleMetadata(
        long timeUs, int flags, int size, int offset, @Nullable CryptoData cryptoData) {
      Format held = heldFormat;
      if (held != null) {
        release(cryptoData == null && isAtmosFrame(held, firstSample(size, offset)));
      }
      delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData);
      owner.sampleWritten();
    }

    private void hold(byte[] bytes, int part) {
      heldData.add(bytes);
      heldParts.add(part);
      heldBytes += bytes.length;
      if (heldBytes > MAX_HELD_BYTES) release(false);
    }

    void dropHeldData() {
      heldData.clear();
      heldParts.clear();
      heldBytes = 0;
    }

    /** The sample's main bytes: they end [offset] bytes before the newest held byte. */
    private byte[] firstSample(int size, int offset) {
      ByteArrayOutputStream main = new ByteArrayOutputStream();
      for (int i = 0; i < heldData.size(); i++) {
        byte[] bytes = heldData.get(i);
        if (heldParts.get(i) == SAMPLE_DATA_PART_MAIN) main.write(bytes, 0, bytes.length);
      }
      byte[] all = main.toByteArray();
      int end = Math.max(0, all.length - offset);
      int start = Math.max(0, end - size);
      return Arrays.copyOfRange(all, start, end);
    }

    void release(boolean joc) {
      Format format = heldFormat;
      heldFormat = null;
      decided = true;
      atmos = joc;
      if (format != null) delegate.format(joc ? withAtmos(format) : format);
      for (int i = 0; i < heldData.size(); i++) {
        byte[] bytes = heldData.get(i);
        delegate.sampleData(new ParsableByteArray(bytes), bytes.length, heldParts.get(i));
      }
      dropHeldData();
    }

    private static Format withAtmos(Format format) {
      if (!mayBeAtmos(format)) return format;
      return format
          .buildUpon()
          .setCodecs(isTrueHd(format) ? TRUEHD_ATMOS_CODECS : ATMOS_CODECS)
          .build();
    }
  }
}
