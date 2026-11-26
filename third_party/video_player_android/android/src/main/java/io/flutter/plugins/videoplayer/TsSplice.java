// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
package io.flutter.plugins.videoplayer;

import android.net.Uri;
import android.util.Log;
import android.util.SparseIntArray;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.C;
import androidx.media3.common.DataReader;
import androidx.media3.common.Format;
import androidx.media3.common.util.ParsableByteArray;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.common.util.Util;
import androidx.media3.extractor.DiscardingTrackOutput;
import androidx.media3.extractor.Extractor;
import androidx.media3.extractor.ExtractorInput;
import androidx.media3.extractor.ExtractorOutput;
import androidx.media3.extractor.ExtractorsFactory;
import androidx.media3.extractor.PositionHolder;
import androidx.media3.extractor.SeekMap;
import androidx.media3.extractor.SniffFailure;
import androidx.media3.extractor.TrackOutput;
import androidx.media3.extractor.text.SubtitleParser;
import androidx.media3.extractor.ts.TsExtractor;
import java.io.EOFException;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Supplier;

/**
 * VesperTV: live MPEG-TS whose source changes under the open connection. A Tuliprox failover
 * group switches sources while the player reads on (a pick in Sources, an automatic switch, a
 * source reopened after an error); a provider can restart its encoder. Tuliprox starts the next
 * source at a new PAT/PMT and a keyframe and flags the first packet per PID as a discontinuity,
 * but keeps the source's PIDs and timestamps (backend/mpegts/src/splice/aligner.rs, 3.3.207).
 * media3's TsExtractor (single program, the mode for a progressive stream) ignores that flag,
 * reads the PAT/PMT once and keeps one time base, so:
 *
 * <ul>
 *   <li>Timestamps that jump back moved the audio clock with them, while the decoded frames
 *       waited for their old times: the picture stood still with the sound on for as long as the
 *       jump (owner's Homatics, 2026-11-24: 14-19 s back, three times, reloaded by hand).
 *   <li>A source with other PIDs was not read at all, nor one with another codec (HEVC -> H.264:
 *       picture, then sound stopped; owner, 2026-11-24, Sky Sports News HD hevc -> HD).
 * </ul>
 *
 * <p>For a live stream (no length) this keeps sample times continuous ({@link Timeline}: a jump
 * continues right after the newest sample, one offset for every track so picture and sound stay
 * together) and follows a new program ({@link ProgramFollower}): the same stream types on other
 * PIDs get the first program's PIDs; other stream types (another codec) get a new TS reader from
 * the new program's PAT on, writing to the same tracks ({@link Rejoin}; the renderer changes its
 * decoder on the new format). Files (a length) pass through untouched. Log tag {@value #TAG};
 * counts in {@link StreamStats#tsSplices} / {@link StreamStats#tsJumps}.
 */
@OptIn(markerClass = UnstableApi.class)
final class TsSplice {
  static final String TAG = "TsSplice";
  private static final int TS_PACKET_SIZE = 188;
  private static final byte SYNC = 0x47;

  private TsSplice() {}

  static ExtractorsFactory wrap(@NonNull ExtractorsFactory factory, @Nullable StreamStats stats) {
    return new Factory(factory, stats);
  }

  private static final class Factory implements ExtractorsFactory {
    private final ExtractorsFactory delegate;
    @Nullable private final StreamStats stats;

    Factory(ExtractorsFactory delegate, @Nullable StreamStats stats) {
      this.delegate = delegate;
      this.stats = stats;
    }

    @NonNull
    @Override
    public Extractor[] createExtractors() {
      return wrapTs(delegate.createExtractors());
    }

    @NonNull
    @Override
    public Extractor[] createExtractors(
        @NonNull Uri uri, @NonNull Map<String, List<String>> responseHeaders) {
      return wrapTs(delegate.createExtractors(uri, responseHeaders));
    }

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

    private Extractor[] wrapTs(Extractor[] extractors) {
      for (int i = 0; i < extractors.length; i++) {
        if (extractors[i].getUnderlyingImplementation() instanceof TsExtractor) {
          extractors[i] = new SplicingExtractor(extractors[i], stats, () -> freshTs(delegate));
        }
      }
      return extractors;
    }

    /** A new TS reader set up like the first (captions, flags). */
    private static Extractor freshTs(ExtractorsFactory factory) {
      for (Extractor e : factory.createExtractors()) {
        if (e.getUnderlyingImplementation() instanceof TsExtractor) return e;
      }
      return new TsExtractor();
    }
  }

  /** The TS reader, fed through {@link FilterInput} and writing through {@link Timeline}. */
  static final class SplicingExtractor implements Extractor {
    private static final int UNDECIDED = 0;
    private static final int LIVE = 1;
    private static final int FILE = 2;

    private Extractor delegate;
    @Nullable private final StreamStats stats;
    private final Supplier<Extractor> freshReader;
    final ProgramFollower programs;
    private final FilterInput filtered;
    @Nullable Timeline timeline;
    private int mode = UNDECIDED;
    /** Readers started for a program with other stream types. */
    int newReaders;

    SplicingExtractor(@NonNull Extractor delegate, @Nullable StreamStats stats) {
      this(delegate, stats, TsExtractor::new);
    }

    SplicingExtractor(
        @NonNull Extractor delegate,
        @Nullable StreamStats stats,
        @NonNull Supplier<Extractor> freshReader) {
      this.delegate = delegate;
      this.stats = stats;
      this.freshReader = freshReader;
      programs = new ProgramFollower(stats);
      filtered = new FilterInput(programs);
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
    public void init(@NonNull ExtractorOutput output) {
      Timeline t = new Timeline(output, stats);
      timeline = t;
      t.programs = programs;
      programs.listener = t;
      delegate.init(t);
    }

    @Override
    public int read(@NonNull ExtractorInput input, @NonNull PositionHolder seekPosition)
        throws IOException {
      if (mode == UNDECIDED) {
        mode = input.getLength() == C.LENGTH_UNSET ? LIVE : FILE;
        if (timeline != null) timeline.active = mode == LIVE;
      }
      if (mode == FILE) return delegate.read(input, seekPosition);
      filtered.source = input;
      int result = delegate.read(filtered, seekPosition);
      if (result == RESULT_END_OF_INPUT && filtered.atSplit()) {
        // The old reader has everything before the new program: a new one from its PAT on.
        filtered.passSplit();
        newReader();
        return RESULT_CONTINUE;
      }
      return result;
    }

    private void newReader() {
      Timeline t = timeline;
      if (t == null) return;
      Extractor next = freshReader.get();
      next.init(new Rejoin(t));
      delegate.release();
      delegate = next;
      newReaders++;
      Log.i(TAG, "a new reader for the new program's stream types");
    }

    @Override
    public void seek(long position, long timeUs) {
      // A restarted load (a new connection from its start): the bytes and the time base start
      // over; the program mapping stays (the TS reader keeps its tracks).
      filtered.reset();
      programs.restart();
      if (timeline != null) timeline.reset();
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

  /**
   * The source's bytes as whole TS packets, each passed through {@link ProgramFollower} (which
   * may change its PID) before the TS reader sees it. Live only: no length, no peeking.
   */
  static final class FilterInput implements ExtractorInput {
    private static final int CHUNK = 32 * 1024;

    @Nullable ExtractorInput source;
    private final ProgramFollower programs;
    private final byte[] buf = new byte[CHUNK + 4 * TS_PACKET_SIZE];
    /** buf[start, ready): checked bytes for the reader; buf[ready, end): not yet whole. */
    private int start;

    private int ready;
    private int end;
    private boolean ended;
    /** Where a new reader takes over (a program with other stream types begins), in buf. */
    private final ArrayDeque<Integer> splits = new ArrayDeque<>();

    FilterInput(ProgramFollower programs) {
      this.programs = programs;
    }

    void reset() {
      start = 0;
      ready = 0;
      end = 0;
      ended = false;
      splits.clear();
    }

    /** The reader has every byte before a new program that needs a new reader. */
    boolean atSplit() {
      Integer at = splits.peekFirst();
      return at != null && at == start;
    }

    void passSplit() {
      splits.pollFirst();
    }

    /** Readable now: up to the next split point (the old reader ends there). */
    private int limit() {
      Integer at = splits.peekFirst();
      return at == null ? ready : Math.min(ready, at);
    }

    @Override
    public int read(@NonNull byte[] target, int offset, int length) throws IOException {
      if (length == 0) return 0;
      while (start == limit()) {
        if (atSplit()) return C.RESULT_END_OF_INPUT;
        if (!fill()) return C.RESULT_END_OF_INPUT;
      }
      int n = Math.min(length, limit() - start);
      System.arraycopy(buf, start, target, offset, n);
      start += n;
      return n;
    }

    /** More bytes from the source, whole packets checked; false once nothing is left. */
    private boolean fill() throws IOException {
      if (start > 0) {
        System.arraycopy(buf, start, buf, 0, end - start);
        ready -= start;
        end -= start;
        if (!splits.isEmpty()) {
          ArrayDeque<Integer> moved = new ArrayDeque<>();
          for (int at : splits) moved.add(at - start);
          splits.clear();
          splits.addAll(moved);
        }
        start = 0;
      }
      if (ended) {
        // The source ended: its unfinished last packet goes as it is.
        if (ready < end) {
          ready = end;
          return true;
        }
        return false;
      }
      ExtractorInput in = source;
      if (in == null) return false;
      // Room kept for a PAT put in front of a new program (check).
      int read = in.read(buf, end, buf.length - end - 2 * TS_PACKET_SIZE);
      if (read == C.RESULT_END_OF_INPUT) {
        ended = true;
        return fill();
      }
      end += read;
      check();
      return true;
    }

    private void check() {
      int p = ready;
      while (end - p >= TS_PACKET_SIZE) {
        if (buf[p] != SYNC) {
          // Out of step (a reconnect cut a packet): the bytes up to the next sync go as they
          // are, the TS reader skips them itself.
          int q = nextSync(p + 1);
          if (q < 0) {
            p = Math.max(p, end - (TS_PACKET_SIZE - 1));
            break;
          }
          p = q;
          continue;
        }
        if (programs.process(buf, p) == ProgramFollower.SPLIT) {
          // A program with other stream types begins with this PMT: a new reader takes over
          // here, given the program's PAT first (it came a few packets earlier, to the old one).
          byte[] pat = programs.lastPat();
          if (pat != null && end + TS_PACKET_SIZE <= buf.length) {
            System.arraycopy(buf, p, buf, p + TS_PACKET_SIZE, end - p);
            System.arraycopy(pat, 0, buf, p, TS_PACKET_SIZE);
            end += TS_PACKET_SIZE;
            splits.add(p);
            p += TS_PACKET_SIZE;
          } else {
            splits.add(p);
          }
        }
        p += TS_PACKET_SIZE;
      }
      ready = p;
    }

    private int nextSync(int from) {
      for (int i = from; i < end; i++) {
        if (buf[i] == SYNC && (i + TS_PACKET_SIZE >= end || buf[i + TS_PACKET_SIZE] == SYNC)) {
          return i;
        }
      }
      return -1;
    }

    @Override
    public boolean readFully(byte[] target, int offset, int length, boolean allowEndOfInput)
        throws IOException {
      int done = 0;
      while (done < length) {
        int n = read(target, offset + done, length - done);
        if (n == C.RESULT_END_OF_INPUT) {
          if (done == 0 && allowEndOfInput) return false;
          throw new EOFException();
        }
        done += n;
      }
      return true;
    }

    @Override
    public void readFully(byte[] target, int offset, int length) throws IOException {
      readFully(target, offset, length, false);
    }

    @Override
    public int skip(int length) throws IOException {
      return read(new byte[Math.min(length, CHUNK)], 0, Math.min(length, CHUNK));
    }

    @Override
    public boolean skipFully(int length, boolean allowEndOfInput) throws IOException {
      byte[] scratch = new byte[Math.min(Math.max(length, 1), CHUNK)];
      int done = 0;
      while (done < length) {
        int n = read(scratch, 0, Math.min(scratch.length, length - done));
        if (n == C.RESULT_END_OF_INPUT) {
          if (done == 0 && allowEndOfInput) return false;
          throw new EOFException();
        }
        done += n;
      }
      return true;
    }

    @Override
    public void skipFully(int length) throws IOException {
      skipFully(length, false);
    }

    @Override
    public int peek(byte[] target, int offset, int length) {
      throw new UnsupportedOperationException("TsSplice: no peeking in a live stream");
    }

    @Override
    public boolean peekFully(byte[] target, int offset, int length, boolean allowEndOfInput) {
      throw new UnsupportedOperationException("TsSplice: no peeking in a live stream");
    }

    @Override
    public void peekFully(byte[] target, int offset, int length) {
      throw new UnsupportedOperationException("TsSplice: no peeking in a live stream");
    }

    @Override
    public boolean advancePeekPosition(int length, boolean allowEndOfInput) {
      throw new UnsupportedOperationException("TsSplice: no peeking in a live stream");
    }

    @Override
    public void advancePeekPosition(int length) {
      throw new UnsupportedOperationException("TsSplice: no peeking in a live stream");
    }

    @Override
    public void resetPeekPosition() {}

    @Override
    public long getPeekPosition() {
      return getPosition();
    }

    @Override
    public long getPosition() {
      ExtractorInput in = source;
      return in == null ? 0 : in.getPosition() - (end - start);
    }

    @Override
    public long getLength() {
      return C.LENGTH_UNSET;
    }

    @Override
    public <E extends Throwable> void setRetryPosition(long position, E e) throws E {
      ExtractorInput in = source;
      if (in == null) throw e;
      in.setRetryPosition(position, e);
    }
  }

  /**
   * Follows the PAT and PMT of the stream. The TS reader knows the first program's elementary
   * streams only; when a later PMT lists others (a new source with other PIDs), their packets get
   * the first program's PIDs (same stream type, in order) and anything else is dropped. Every
   * change of program (also a new version with the same streams: a Tuliprox switch) is told to
   * the {@link Listener}.
   */
  static final class ProgramFollower {
    static final int NULL_PID = 0x1FFF;
    /** {@link #process}: carry on / a new reader starts at this packet. */
    static final int PASS = 0;

    static final int SPLIT = 1;
    /** Packets of a new program dropped while its PMT is awaited, at most. */
    private static final int MAX_AWAITED = 2000;

    interface Listener {
      void onProgramChange();
    }

    @Nullable Listener listener;
    @Nullable private final StreamStats stats;
    private int pmtPid = -1;
    private int patVersion = -1;
    private int pmtVersion = -1;
    /** What the TS reader knows: the first PMT's streams. */
    @Nullable private List<Es> first;
    /** On air now. */
    @Nullable private List<Es> current;
    /** On-air PID -> PID the TS reader knows ({@link #NULL_PID}: dropped). */
    private final SparseIntArray remap = new SparseIntArray();

    private boolean awaitingPmt;
    private int awaited;
    /** Several programs, or tables over several packets: left alone. */
    private boolean ignored;
    /** The newest valid PAT packet, for a new reader. */
    @Nullable private byte[] lastPat;

    int changes;

    ProgramFollower(@Nullable StreamStats stats) {
      this.stats = stats;
    }

    /** A new connection from its start: tables are read again, the mapping stays. */
    void restart() {
      pmtPid = -1;
      patVersion = -1;
      pmtVersion = -1;
      awaitingPmt = false;
      awaited = 0;
    }

    @Nullable
    byte[] lastPat() {
      return lastPat;
    }

    /**
     * One whole TS packet at d[p], its PID changed in place when needed. {@link #SPLIT}: it is the
     * PMT of a program whose stream types the reader doesn't have; a new reader starts here.
     */
    int process(byte[] d, int p) {
      if (ignored) return PASS;
      int b1 = d[p + 1] & 0xFF;
      if ((b1 & 0x80) != 0) return PASS; // transport_error_indicator
      int pid = ((b1 & 0x1F) << 8) | (d[p + 2] & 0xFF);
      boolean unitStart = (b1 & 0x40) != 0;
      int control = (d[p + 3] >> 4) & 0x3;
      int payload = p + 4;
      if ((control & 0x2) != 0) payload += 1 + (d[p + 4] & 0xFF);
      boolean hasPayload = (control & 0x1) != 0 && payload < p + TS_PACKET_SIZE;
      if (pid == 0) {
        if (unitStart && hasPayload && onPat(d, payload, p + TS_PACKET_SIZE)) {
          lastPat = java.util.Arrays.copyOfRange(d, p, p + TS_PACKET_SIZE);
        }
        return PASS;
      }
      if (pid == pmtPid) {
        return unitStart && hasPayload ? onPmt(d, payload, p + TS_PACKET_SIZE) : PASS;
      }
      if (pid == NULL_PID) return PASS;
      if (awaitingPmt) {
        if (++awaited > MAX_AWAITED) {
          awaitingPmt = false;
        } else if (knows(pid)) {
          // A new program's packet before its PMT: whose stream it is isn't known yet.
          setPid(d, p, NULL_PID);
          return PASS;
        }
      }
      int to = remap.get(pid, -1);
      if (to >= 0 && to != pid) setPid(d, p, to);
      return PASS;
    }

    private boolean knows(int pid) {
      if (remap.indexOfKey(pid) >= 0) return true;
      List<Es> f = first;
      if (f == null) return false;
      for (Es es : f) if (es.pid == pid) return true;
      return false;
    }

    private static void setPid(byte[] d, int p, int pid) {
      d[p + 1] = (byte) ((d[p + 1] & 0xE0) | ((pid >> 8) & 0x1F));
      d[p + 2] = (byte) (pid & 0xFF);
    }

    /** A section starting in this packet, checked; its start or -1. */
    private static int section(byte[] d, int payload, int limit, int tableId, int minLength) {
      int s = payload + 1 + (d[payload] & 0xFF);
      if (s + 3 > limit || (d[s] & 0xFF) != tableId) return -1;
      int length = ((d[s + 1] & 0x0F) << 8) | (d[s + 2] & 0xFF);
      int sectionEnd = s + 3 + length;
      if (length < minLength || sectionEnd > limit) return -1; // over several packets
      if (Util.crc32(d, s, sectionEnd, 0xFFFFFFFF) != 0) return -1; // damaged
      if ((d[s + 5] & 0x01) == 0) return -1; // not yet in force
      return s;
    }

    /** True when it was a valid PAT of one program. */
    private boolean onPat(byte[] d, int payload, int limit) {
      int s = section(d, payload, limit, 0x00, 9);
      if (s < 0) return false;
      int sectionEnd = s + 3 + (((d[s + 1] & 0x0F) << 8) | (d[s + 2] & 0xFF));
      int version = (d[s + 5] >> 1) & 0x1F;
      int programs = 0;
      int newPmtPid = -1;
      for (int i = s + 8; i + 4 <= sectionEnd - 4; i += 4) {
        int number = ((d[i] & 0xFF) << 8) | (d[i + 1] & 0xFF);
        if (number == 0) continue; // network PID
        programs++;
        if (newPmtPid < 0) newPmtPid = ((d[i + 2] & 0x1F) << 8) | (d[i + 3] & 0xFF);
      }
      if (programs != 1) {
        if (programs > 1) {
          ignored = true;
          Log.i(TAG, programs + " programs in the stream: left as they are");
        }
        return false;
      }
      boolean changed = patVersion >= 0 && (version != patVersion || newPmtPid != pmtPid);
      patVersion = version;
      pmtPid = newPmtPid;
      if (changed && first != null) {
        awaitingPmt = true;
        awaited = 0;
        pmtVersion = -1;
      }
      return true;
    }

    private int onPmt(byte[] d, int payload, int limit) {
      int s = section(d, payload, limit, 0x02, 13);
      if (s < 0) return PASS;
      int sectionEnd = s + 3 + (((d[s + 1] & 0x0F) << 8) | (d[s + 2] & 0xFF));
      int version = (d[s + 5] >> 1) & 0x1F;
      int infoLength = ((d[s + 10] & 0x0F) << 8) | (d[s + 11] & 0xFF);
      List<Es> streams = new ArrayList<>();
      int i = s + 12 + infoLength;
      while (i + 5 <= sectionEnd - 4) {
        int type = d[i] & 0xFF;
        int pid = ((d[i + 1] & 0x1F) << 8) | (d[i + 2] & 0xFF);
        int esInfoLength = ((d[i + 3] & 0x0F) << 8) | (d[i + 4] & 0xFF);
        int from = i + 5;
        int to = Math.min(from + esInfoLength, sectionEnd - 4);
        streams.add(new Es(pid, resolvedType(type, d, from, to)));
        i = from + esInfoLength;
      }
      if (first == null) {
        first = streams;
        current = streams;
        pmtVersion = version;
        return PASS;
      }
      boolean newVersion = pmtVersion >= 0 && version != pmtVersion;
      boolean wasAwaiting = awaitingPmt;
      pmtVersion = version;
      awaitingPmt = false;
      boolean sameStreams = streams.equals(current);
      if (sameStreams && !newVersion && !wasAwaiting) return PASS;
      current = streams;
      int result = PASS;
      String mapping;
      if (sameStreams) {
        mapping = "same streams";
      } else {
        mapping = remapOnto(streams);
        if (mapping == null) {
          // Another codec: the reader can't take it on its PIDs. A new reader from here on,
          // which knows this program as its first.
          remap.clear();
          first = streams;
          mapping = "other stream types: a new reader";
          result = SPLIT;
        }
      }
      changes++;
      if (stats != null) stats.tsSplices.incrementAndGet();
      Log.i(TAG, "new program (version " + version + "): " + mapping);
      Listener l = listener;
      if (l != null) l.onProgramChange();
      return result;
    }

    /**
     * Maps [streams] onto the first program's PIDs; what it did, for the log. Null when a stream
     * of the first program has no stream of its type here (a new reader is needed).
     */
    @Nullable
    private String remapOnto(List<Es> streams) {
      List<Es> f = first;
      remap.clear();
      if (f == null) return "";
      boolean[] used = new boolean[streams.size()];
      StringBuilder log = new StringBuilder();
      for (Es want : f) {
        int found = -1;
        for (int j = 0; j < streams.size(); j++) {
          if (!used[j] && streams.get(j).type == want.type) {
            found = j;
            break;
          }
        }
        if (log.length() > 0) log.append(", ");
        if (found < 0) {
          remap.clear();
          return null;
        }
        used[found] = true;
        int pid = streams.get(found).pid;
        remap.put(pid, want.pid);
        log.append(String.format(Locale.ROOT, "0x%x->0x%x", pid, want.pid));
      }
      for (int j = 0; j < streams.size(); j++) {
        if (!used[j]) remap.put(streams.get(j).pid, NULL_PID);
      }
      return log.toString();
    }

    /**
     * The stream type, made specific for a private stream (0x05/0x06) by its first telling
     * descriptor (AC-3, E-AC-3, DTS, DVB subtitles, teletext, an extension or a registration),
     * so that streams are only matched with their own kind.
     */
    private static int resolvedType(int type, byte[] d, int from, int to) {
      if (type != 0x05 && type != 0x06) return type;
      int k = from;
      while (k + 2 <= to) {
        int tag = d[k] & 0xFF;
        int length = d[k + 1] & 0xFF;
        if (tag == 0x05 && length >= 4 && k + 6 <= to) {
          return ((d[k + 2] & 0xFF) << 24)
              | ((d[k + 3] & 0xFF) << 16)
              | ((d[k + 4] & 0xFF) << 8)
              | (d[k + 5] & 0xFF);
        }
        if (tag == 0x6A || tag == 0x7A || tag == 0x7B || tag == 0x59 || tag == 0x56) {
          return 0x100 | tag;
        }
        if (tag == 0x7F && length >= 1 && k + 3 <= to) return 0x7F00 | (d[k + 2] & 0xFF);
        k += 2 + length;
      }
      return type;
    }

    @VisibleForTesting
    int remappedPid(int pid) {
      return remap.get(pid, pid);
    }

    /** The program on air, for the log: "PMT 0x1000 v3: 0x100 type 0x1b, 0x101 type 0xf". */
    String describe() {
      List<Es> c = current;
      if (c == null) return "none yet";
      StringBuilder b =
          new StringBuilder(String.format(Locale.ROOT, "PMT 0x%x v%d:", pmtPid, pmtVersion));
      for (Es es : c) {
        b.append(String.format(Locale.ROOT, " 0x%x type 0x%x", es.pid, es.type));
        int to = remap.get(es.pid, es.pid);
        if (to != es.pid) b.append(String.format(Locale.ROOT, "->0x%x", to));
      }
      return b.toString();
    }
  }

  /**
   * A new reader's tracks: the n-th track of a type is the n-th track of that type the first
   * reader made (the player can't take new tracks); others are dropped. Tracks and the seek map
   * were already announced.
   */
  private static final class Rejoin implements ExtractorOutput {
    private final Timeline timeline;
    private final SparseIntArray perType = new SparseIntArray();

    Rejoin(Timeline timeline) {
      this.timeline = timeline;
    }

    @NonNull
    @Override
    public TrackOutput track(int id, int type) {
      int n = perType.get(type, 0);
      perType.put(type, n + 1);
      TrackOutput existing = timeline.existing(type, n);
      return existing != null ? existing : new DiscardingTrackOutput();
    }

    @Override
    public void endTracks() {}

    @Override
    public void seekMap(@NonNull SeekMap seekMap) {}
  }

  /** An elementary stream of a PMT. */
  private static final class Es {
    final int pid;
    final int type;

    Es(int pid, int type) {
      this.pid = pid;
      this.type = type;
    }

    @Override
    public boolean equals(@Nullable Object o) {
      return o instanceof Es && ((Es) o).pid == pid && ((Es) o).type == type;
    }

    @Override
    public int hashCode() {
      return pid * 31 + type;
    }
  }

  /**
   * Sample times made continuous. Each audio / video sample is checked against its track's last
   * one (backwards) and the newest sample of any track (forwards): a jump moves the shared offset
   * so the sample continues right after the newest one. Text and metadata follow the offset.
   * After a program change ({@link ProgramFollower.Listener}) smaller jumps count, for a while. A
   * track that hasn't caught up with a new offset keeps its old one for samples that still
   * continue it (written before the switch, finished after it).
   */
  static final class Timeline implements ExtractorOutput, ProgramFollower.Listener {
    /** Audio / video samples checked with the smaller limits after a program change. */
    private static final int SPLICE_WINDOW_SAMPLES = 2000;

    private final ExtractorOutput delegate;
    @Nullable private final StreamStats stats;
    /** Live only (set on the first read); a file's times are left alone. */
    boolean active;

    private final List<Track> tracks = new ArrayList<>();
    /** For the log when a track goes silent. */
    @Nullable ProgramFollower programs;

    private long offsetUs;
    private long newestUs = C.TIME_UNSET;
    private int spliceWindow;
    int jumps;

    Timeline(ExtractorOutput delegate, @Nullable StreamStats stats) {
      this.delegate = delegate;
      this.stats = stats;
    }

    @NonNull
    @Override
    public TrackOutput track(int id, int type) {
      Track track = new Track(this, delegate.track(id, type), type);
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

    @Override
    public void onProgramChange() {
      spliceWindow = SPLICE_WINDOW_SAMPLES;
    }

    /** The n-th track of [type] the first reader made, or null. */
    @Nullable
    TrackOutput existing(int type, int n) {
      for (Track t : tracks) {
        if (t.type == type && n-- == 0) return t;
      }
      return null;
    }

    void reset() {
      offsetUs = 0;
      newestUs = C.TIME_UNSET;
      spliceWindow = 0;
      for (Track t : tracks) t.reset();
    }

    long map(Track t, long rawUs) {
      if (!active || rawUs == C.TIME_UNSET) return rawUs;
      if (!t.audioOrVideo) return rawUs + offsetUs;
      boolean afterSplice = spliceWindow > 0;
      if (afterSplice) spliceWindow--;
      long out = rawUs + offsetUs;
      if (t.lastUs != C.TIME_UNSET) {
        if (t.offsetUs != offsetUs) {
          long old = rawUs + t.offsetUs;
          if (!t.jumps(old, newestUs, afterSplice) && t.jumps(out, newestUs, afterSplice)) {
            return t.wrote(old, this);
          }
          t.offsetUs = offsetUs;
        }
        if (t.jumps(out, newestUs, afterSplice)) {
          long target = newestUs + t.stepUs;
          long shift = target - out;
          offsetUs += shift;
          t.offsetUs = offsetUs;
          jumps++;
          spliceWindow = 0;
          if (stats != null) stats.tsJumps.incrementAndGet();
          Log.i(
              TAG,
              String.format(
                  Locale.ROOT,
                  "timestamps jumped %+.1f s on %s, continued",
                  (out - t.lastUs) / 1e6,
                  t.audio ? "audio" : "video"));
          out = target;
        }
      } else {
        t.offsetUs = offsetUs;
      }
      return t.wrote(out, this);
    }

    void wroteAv(Track by, long outUs) {
      if (newestUs == C.TIME_UNSET || outUs > newestUs) newestUs = outUs;
      // One track silent while the other goes on: the player fills its memory with the other
      // and waits for good (owner, 2026-11-24, ESPN News). Said once per silence.
      for (Track u : tracks) {
        if (u == by || !u.audioOrVideo || u.silentSaid || u.lastUs == C.TIME_UNSET) continue;
        if (newestUs - u.lastUs > 10_000_000) {
          u.silentSaid = true;
          ProgramFollower p = programs;
          Log.i(
              TAG,
              String.format(
                  Locale.ROOT,
                  "no %s for %.0f s while %s goes on (%s)",
                  u.audio ? "audio" : "video",
                  (newestUs - u.lastUs) / 1e6,
                  by.audio ? "audio" : "video",
                  p == null ? "?" : p.describe()));
        }
      }
    }
  }

  private static final class Track implements TrackOutput {
    private final Timeline owner;
    private final TrackOutput delegate;
    final int type;
    final boolean audioOrVideo;
    final boolean audio;
    long lastUs = C.TIME_UNSET;
    long offsetUs;
    /** About one sample: how far after the newest sample a jumped one continues. */
    long stepUs;
    /** Its silence was logged (cleared by its next sample). */
    boolean silentSaid;

    Track(Timeline owner, TrackOutput delegate, int type) {
      this.owner = owner;
      this.delegate = delegate;
      this.type = type;
      audio = type == C.TRACK_TYPE_AUDIO;
      audioOrVideo = audio || type == C.TRACK_TYPE_VIDEO;
      stepUs = audio ? 21_000 : 40_000;
    }

    void reset() {
      lastUs = C.TIME_UNSET;
      offsetUs = 0;
    }

    /**
     * Whether [out] leaves this track's timeline: back from its last sample (audio 1 s, video 1.5
     * s: decode order goes back a few frames; after a program change 0.25 / 0.6 s) or ahead of the
     * newest sample of any track (5 s; after a program change 1.5 s). Ahead is measured against
     * every track so that one track's gap (sound missing for a while) isn't a jump.
     */
    boolean jumps(long out, long newestUs, boolean afterSplice) {
      long back = audio ? (afterSplice ? 250_000 : 1_000_000) : (afterSplice ? 600_000 : 1_500_000);
      long ahead = afterSplice ? 1_500_000 : 5_000_000;
      return out < lastUs - back || (newestUs != C.TIME_UNSET && out > newestUs + ahead);
    }

    long wrote(long out, Timeline timeline) {
      if (lastUs != C.TIME_UNSET && out > lastUs) {
        long delta = out - lastUs;
        if (delta >= 5_000 && delta <= 100_000) stepUs = delta;
      }
      lastUs = out;
      silentSaid = false;
      timeline.wroteAv(this, out);
      return out;
    }

    @Override
    public void durationUs(long durationUs) {
      delegate.durationUs(durationUs);
    }

    @Override
    public void format(@NonNull Format format) {
      delegate.format(format);
    }

    @Override
    public int sampleData(
        @NonNull DataReader input, int length, boolean allowEndOfInput, int sampleDataPart)
        throws IOException {
      return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart);
    }

    @Override
    public void sampleData(@NonNull ParsableByteArray data, int length, int sampleDataPart) {
      delegate.sampleData(data, length, sampleDataPart);
    }

    @Override
    public void sampleMetadata(
        long timeUs, int flags, int size, int offset, @Nullable CryptoData cryptoData) {
      delegate.sampleMetadata(owner.map(this, timeUs), flags, size, offset, cryptoData);
    }
  }
}
