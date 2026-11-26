// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: the live player's progressive source when Live pause & rewind is on. Reads the
// network as before until Dart arms Timeshift for the channel; at the next read its open
// connection becomes Timeshift's writer (no reconnect) and the player reads the rolling copy
// from then on. A new load (a jump, the next live copy) opens the copy, not the network. Not
// armed, not MPEG-TS, or a file (a length): the network, exactly as before. See Timeshift.
package io.flutter.plugins.videoplayer;

import android.net.Uri;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

@OptIn(markerClass = UnstableApi.class)
final class TimeshiftDataSource implements DataSource {
  private final DataSource.Factory directFactory;
  private final Timeshift timeshift;
  private final List<TransferListener> listeners = new ArrayList<>();

  @Nullable private DataSpec spec;
  /** The network, before the copy takes over (or when it's off). */
  @Nullable private DataSource upstream;
  /** Reading the copy. */
  @Nullable private Timeshift.Cursor cursor;
  /** This load's position (bytes from its start). */
  private long pos;
  /** Copy offset of this load's position 0. */
  private long base;
  /**
   * Loads read the copy (ExoPlayer keeps one source for the stream: every load after a jump,
   * and the same load reopened after an error, comes back here).
   */
  private boolean ringLoad;
  /** A live stream opened from its start (no length): the copy may take it over. */
  private boolean liveCandidate;
  /** The first byte read was checked: MPEG-TS (0x47) or not. */
  private boolean checked;
  private boolean isTs;

  TimeshiftDataSource(@NonNull DataSource.Factory directFactory, @NonNull Timeshift timeshift) {
    this.directFactory = directFactory;
    this.timeshift = timeshift;
  }

  @Override
  public void addTransferListener(@NonNull TransferListener transferListener) {
    listeners.add(transferListener);
    if (upstream != null) upstream.addTransferListener(transferListener);
  }

  private DataSource newDirect() {
    DataSource d = directFactory.createDataSource();
    for (TransferListener l : listeners) d.addTransferListener(l);
    return d;
  }

  @Override
  public long open(@NonNull DataSpec dataSpec) throws IOException {
    spec = dataSpec;
    pos = dataSpec.position;
    if (timeshift.isActive() && dataSpec.length == C.LENGTH_UNSET
        && (dataSpec.position == 0 || ringLoad)) {
      Timeshift.Cursor c = timeshift.openReader(dataSpec.position, base);
      cursor = c;
      ringLoad = true;
      base = c.pos - dataSpec.position;
      return C.LENGTH_UNSET;
    }
    cursor = null;
    DataSource d = newDirect();
    upstream = d;
    long length = d.open(dataSpec);
    liveCandidate = length == C.LENGTH_UNSET && dataSpec.position == 0
        && dataSpec.length == C.LENGTH_UNSET;
    return length;
  }

  @Override
  public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
    if (length == 0) return 0;
    DataSpec current = spec;
    if (current == null) throw new IOException("timeshift source not open");
    DataSource direct = upstream;
    if (direct != null && liveCandidate && isTs && timeshift.isArmed() && !timeshift.isActive()) {
      // Switched on while this connection reads: it carries on as the copy's writer.
      Timeshift.Cursor c = timeshift.adopt(direct, current, direct.getResponseHeaders());
      upstream = null;
      cursor = c;
      ringLoad = true;
      base = c.pos - pos;
      Log.i(Timeshift.TAG, "took over the live connection after " + pos / 1024 + " KB");
    }
    Timeshift.Cursor c = cursor;
    if (c != null) {
      int n = timeshift.read(c, buffer, offset, length);
      if (n != Timeshift.STOPPED) {
        if (n > 0) pos += n;
        return n;
      }
      // Switched off meanwhile: the network again, from "now" (a live stream has no past).
      c.close();
      cursor = null;
      ringLoad = false;
      base = 0;
      DataSource d = newDirect();
      upstream = d;
      d.open(current.buildUpon().setPosition(0).setLength(C.LENGTH_UNSET).build());
    }
    DataSource d = upstream;
    if (d == null) throw new IOException("timeshift source not open");
    int n = d.read(buffer, offset, length);
    if (n > 0) {
      if (!checked) {
        checked = true;
        isTs = buffer[offset] == 0x47;
      }
      pos += n;
    }
    return n;
  }

  @Nullable
  @Override
  public Uri getUri() {
    if (cursor != null) return spec == null ? null : spec.uri;
    return upstream == null ? null : upstream.getUri();
  }

  @NonNull
  @Override
  public Map<String, List<String>> getResponseHeaders() {
    if (cursor != null) return timeshift.responseHeaders();
    return upstream == null ? Collections.emptyMap() : upstream.getResponseHeaders();
  }

  @Override
  public void close() throws IOException {
    Timeshift.Cursor c = cursor;
    cursor = null;
    if (c != null) c.close();
    spec = null;
    DataSource d = upstream;
    upstream = null;
    if (d != null) d.close();
  }
}
