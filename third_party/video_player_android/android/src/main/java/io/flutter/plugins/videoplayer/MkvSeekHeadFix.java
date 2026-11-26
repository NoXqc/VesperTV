// VesperTV patch: MKVs whose seek index (Cues) is only named by a second SeekHead.
package io.flutter.plugins.videoplayer;

import android.net.Uri;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * Some MKVs (written by ffmpeg / Lavf 60 when its index entries didn't fit at the front) start
 * with a SeekHead whose only entry points to a second SeekHead at the end of the file, and only
 * that one names the Cues (the seek index). media3's MatroskaExtractor reads the first SeekHead
 * only, never finds the Cues and plays the whole file as unseekable: every skip went back to the
 * start (cillfog, Marshals, LOG-JKB6RY, 2026-11-26; VLC, browsers and the provider's app follow
 * the chain).
 *
 * <p>On an open at byte 0 of a file (length known) this reads the first bytes; when they show
 * that layout, one small range request reads the second SeekHead, and the first SeekHead's entry
 * is rewritten in place to name the Cues (same field widths: nothing else moves). Everything
 * else (other files, live streams, any parsing doubt) passes through untouched.
 */
@OptIn(markerClass = UnstableApi.class)
final class MkvSeekHeadFix implements DataSource {
  private static final String TAG = "VesperMkv";
  /** Bytes read ahead at the start of a file to look at its first SeekHead. */
  static final int HEAD_BYTES = 4096;
  /** Bytes read at the second SeekHead (a few entries). */
  static final int TAIL_BYTES = 4096;

  private static final int ID_EBML = 0x1A45DFA3;
  private static final int ID_SEGMENT = 0x18538067;
  private static final int ID_SEEK_HEAD = 0x114D9B74;
  private static final int ID_SEEK = 0x4DBB;
  private static final int ID_SEEK_ID = 0x53AB;
  private static final int ID_SEEK_POSITION = 0x53AC;
  private static final int ID_CUES = 0x1C53BB6B;

  private final DataSource upstream;
  private final DataSource.Factory sideFactory;

  /** The first bytes of the file (patched or not), served before the upstream's rest. */
  @Nullable private byte[] head;
  private int headLength;
  private int headRead;

  MkvSeekHeadFix(@NonNull DataSource upstream, @NonNull DataSource.Factory sideFactory) {
    this.upstream = upstream;
    this.sideFactory = sideFactory;
  }

  @Override
  public void addTransferListener(@NonNull TransferListener transferListener) {
    upstream.addTransferListener(transferListener);
  }

  @Override
  public long open(@NonNull DataSpec dataSpec) throws IOException {
    head = null;
    headLength = headRead = 0;
    long length = upstream.open(dataSpec);
    // Files only (a live stream has no length), from their first byte.
    if (dataSpec.position != 0 || length == C.LENGTH_UNSET || length < 64) return length;
    byte[] buf = new byte[(int) Math.min(HEAD_BYTES, length)];
    int n = 0;
    while (n < buf.length) {
      int r = upstream.read(buf, n, buf.length - n);
      if (r == C.RESULT_END_OF_INPUT) break;
      n += r;
    }
    head = buf;
    headLength = n;
    try {
      patch(dataSpec, buf, n, length);
    } catch (Exception e) {
      Log.w(TAG, "second SeekHead not read: " + e);
    }
    return length;
  }

  /** Rewrites [buf]'s first SeekHead entry when the Cues are only named further on. */
  private void patch(DataSpec dataSpec, byte[] buf, int n, long length) throws IOException {
    Chain chain = findChain(buf, n);
    if (chain == null) return;
    long at = chain.segmentDataStart + chain.secondSeekHead;
    if (at <= 0 || at >= length) return;
    int want = (int) Math.min(TAIL_BYTES, length - at);
    byte[] tail = new byte[want];
    int got = 0;
    DataSource side = sideFactory.createDataSource();
    try {
      side.open(dataSpec.buildUpon().setPosition(at).setLength(want).build());
      while (got < want) {
        int r = side.read(tail, got, want - got);
        if (r == C.RESULT_END_OF_INPUT) break;
        got += r;
      }
    } finally {
      side.close();
    }
    long cues = cuesIn(tail, got);
    if (cues < 0 || !apply(buf, chain, cues)) return;
    Log.i(TAG, "seek index named by a second SeekHead: entry rewritten, seeking on");
  }

  /** Where the first SeekHead's entry for the second SeekHead is. */
  @VisibleForTesting
  static final class Chain {
    long segmentDataStart;
    long secondSeekHead; // segment-relative
    int idAt;
    int idLength;
    int positionAt;
    int positionLength;
  }

  /**
   * The layout to fix: an EBML file whose Segment starts with a SeekHead that names no Cues but
   * points to another SeekHead. Null for anything else.
   */
  @Nullable
  @VisibleForTesting
  static Chain findChain(byte[] b, int n) {
    Element ebml = Element.at(b, 0, n);
    if (ebml == null || ebml.id != ID_EBML || ebml.unknownSize) return null;
    Element segment = Element.at(b, ebml.end(), n);
    if (segment == null || segment.id != ID_SEGMENT) return null;
    Element seekHead = Element.at(b, segment.dataAt, n);
    if (seekHead == null || seekHead.id != ID_SEEK_HEAD || seekHead.unknownSize
        || seekHead.end() > n) {
      return null;
    }
    Chain found = null;
    for (int p = seekHead.dataAt; p < seekHead.end(); ) {
      Element seek = Element.at(b, p, seekHead.end());
      if (seek == null || seek.unknownSize) return null;
      if (seek.id == ID_SEEK) {
        long target = -1;
        long position = -1;
        int idAt = -1, idLength = 0, positionAt = -1, positionLength = 0;
        for (int q = seek.dataAt; q < seek.end(); ) {
          Element child = Element.at(b, q, seek.end());
          if (child == null || child.unknownSize) return null;
          if (child.id == ID_SEEK_ID) {
            target = readUnsigned(b, child.dataAt, (int) child.size);
            idAt = child.dataAt;
            idLength = (int) child.size;
          } else if (child.id == ID_SEEK_POSITION) {
            position = readUnsigned(b, child.dataAt, (int) child.size);
            positionAt = child.dataAt;
            positionLength = (int) child.size;
          }
          q = child.end();
        }
        if (target == ID_CUES) return null; // the extractor finds the Cues already
        if (target == ID_SEEK_HEAD && position > 0 && idLength == 4 && positionLength >= 1
            && positionLength <= 8 && found == null) {
          found = new Chain();
          found.segmentDataStart = segment.dataAt;
          found.secondSeekHead = position;
          found.idAt = idAt;
          found.idLength = idLength;
          found.positionAt = positionAt;
          found.positionLength = positionLength;
        }
      }
      p = seek.end();
    }
    return found;
  }

  /** The Cues' segment-relative position named by the SeekHead at [b]'s start, or -1. */
  @VisibleForTesting
  static long cuesIn(byte[] b, int n) {
    Element seekHead = Element.at(b, 0, n);
    if (seekHead == null || seekHead.id != ID_SEEK_HEAD || seekHead.unknownSize) return -1;
    int end = (int) Math.min(seekHead.end(), n);
    for (int p = seekHead.dataAt; p < end; ) {
      Element seek = Element.at(b, p, end);
      if (seek == null || seek.unknownSize) return -1;
      if (seek.id == ID_SEEK) {
        long target = -1;
        long position = -1;
        for (int q = seek.dataAt; q < seek.end(); ) {
          Element child = Element.at(b, q, seek.end());
          if (child == null || child.unknownSize) return -1;
          if (child.id == ID_SEEK_ID) target = readUnsigned(b, child.dataAt, (int) child.size);
          if (child.id == ID_SEEK_POSITION) {
            position = readUnsigned(b, child.dataAt, (int) child.size);
          }
          q = child.end();
        }
        if (target == ID_CUES && position > 0) return position;
      }
      p = seek.end();
    }
    return -1;
  }

  /** The entry now names the Cues at [cues]; false when the position doesn't fit its field. */
  @VisibleForTesting
  static boolean apply(byte[] b, Chain chain, long cues) {
    if (chain.positionLength < 8 && cues >= (1L << (8 * chain.positionLength))) return false;
    b[chain.idAt] = 0x1C;
    b[chain.idAt + 1] = 0x53;
    b[chain.idAt + 2] = (byte) 0xBB;
    b[chain.idAt + 3] = 0x6B;
    for (int i = 0; i < chain.positionLength; i++) {
      b[chain.positionAt + i] = (byte) (cues >>> (8 * (chain.positionLength - 1 - i)));
    }
    return true;
  }

  private static long readUnsigned(byte[] b, int at, int length) {
    long v = 0;
    for (int i = 0; i < length; i++) v = (v << 8) | (b[at + i] & 0xFF);
    return v;
  }

  /** One EBML element header inside [b] (null when it doesn't fit before [limit]). */
  private static final class Element {
    long id;
    long size;
    boolean unknownSize;
    int dataAt;

    int end() {
      return (int) Math.min(Integer.MAX_VALUE, dataAt + size);
    }

    @Nullable
    static Element at(byte[] b, int p, int limit) {
      if (p < 0 || p >= limit) return null;
      int idLength = vintLength(b[p]);
      if (idLength < 1 || idLength > 4 || p + idLength > limit) return null;
      long id = readUnsigned(b, p, idLength);
      int sizeAt = p + idLength;
      if (sizeAt >= limit) return null;
      int sizeLength = vintLength(b[sizeAt]);
      if (sizeLength < 1 || sizeLength > 8 || sizeAt + sizeLength > limit) return null;
      long size = b[sizeAt] & (0xFF >> sizeLength);
      boolean allOnes = size == (0xFF >> sizeLength);
      for (int i = 1; i < sizeLength; i++) {
        int v = b[sizeAt + i] & 0xFF;
        allOnes &= v == 0xFF;
        size = (size << 8) | v;
      }
      Element e = new Element();
      e.id = id;
      e.size = size;
      e.unknownSize = allOnes;
      e.dataAt = sizeAt + sizeLength;
      return e;
    }

    private static int vintLength(byte first) {
      int v = first & 0xFF;
      for (int n = 1; n <= 8; n++) {
        if ((v & (0x80 >> (n - 1))) != 0) return n;
      }
      return 0;
    }
  }

  @Override
  public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
    if (length == 0) return 0;
    byte[] h = head;
    if (h != null && headRead < headLength) {
      int n = Math.min(length, headLength - headRead);
      System.arraycopy(h, headRead, buffer, offset, n);
      headRead += n;
      return n;
    }
    return upstream.read(buffer, offset, length);
  }

  @Nullable
  @Override
  public Uri getUri() {
    return upstream.getUri();
  }

  @NonNull
  @Override
  public Map<String, List<String>> getResponseHeaders() {
    return upstream.getResponseHeaders();
  }

  @Override
  public void close() throws IOException {
    head = null;
    upstream.close();
  }
}
