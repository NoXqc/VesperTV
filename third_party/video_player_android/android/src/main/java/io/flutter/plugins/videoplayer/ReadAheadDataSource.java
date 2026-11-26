// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: the player's progressive-file source; reads from ReadAhead's ring file once
// read-ahead is on, else straight from the network as before. Switched on mid-read, its open
// connection becomes the download's first one (no reconnect: the 8 s freeze at 0:00 of the
// owner's 94.5 GB test, 2026-11-21, came partly from reconnecting 5 s in). See ReadAhead.
package io.flutter.plugins.videoplayer;

import android.net.Uri;
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
final class ReadAheadDataSource implements DataSource {
  private final DataSource.Factory directFactory;
  private final ReadAhead readAhead;
  private final List<TransferListener> listeners = new ArrayList<>();

  @Nullable private DataSpec spec;
  /** The open network connection when reading directly. */
  @Nullable private DataSource upstream;
  /** Absolute position of the next byte. */
  private long pos;
  /** Absolute end of a bounded open, else -1. */
  private long end = -1;
  /** The resource's length from the direct open, else C.LENGTH_UNSET. */
  private long total = C.LENGTH_UNSET;
  private boolean ring;

  ReadAheadDataSource(@NonNull DataSource.Factory directFactory, @NonNull ReadAhead readAhead) {
    this.directFactory = directFactory;
    this.readAhead = readAhead;
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
    end = dataSpec.length == C.LENGTH_UNSET ? -1 : pos + dataSpec.length;
    total = C.LENGTH_UNSET;
    if (readAhead.openReader(dataSpec)) {
      ring = true;
      if (dataSpec.length != C.LENGTH_UNSET) return dataSpec.length;
      long length = readAhead.length();
      return length == C.LENGTH_UNSET ? C.LENGTH_UNSET : Math.max(0, length - pos);
    }
    DataSource d = newDirect();
    upstream = d;
    long opened = d.open(dataSpec);
    if (opened != C.LENGTH_UNSET && end == -1) total = pos + opened;
    return opened;
  }

  @Override
  public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
    if (length == 0) return 0;
    DataSpec current = spec;
    if (current == null) throw new IOException("read-ahead source not open");
    DataSource direct = upstream;
    if (direct != null && end == -1 && readAhead.isArmed()) {
      // Switched on while this connection was reading: it carries on as the download.
      DataSpec here = current.buildUpon().setPosition(pos).setLength(C.LENGTH_UNSET).build();
      if (readAhead.adopt(here, direct, total)) {
        upstream = null;
        ring = true;
      }
    }
    if (end != -1) {
      if (pos >= end) return C.RESULT_END_OF_INPUT;
      length = (int) Math.min(length, end - pos);
    }
    if (ring) {
      int n = readAhead.read(pos, buffer, offset, length);
      if (n != ReadAhead.STOPPED) {
        if (n > 0) pos += n;
        return n;
      }
      // Switched off meanwhile: the network again, from this byte.
      ring = false;
      DataSource d = newDirect();
      upstream = d;
      d.open(current.buildUpon().setPosition(pos)
          .setLength(end == -1 ? C.LENGTH_UNSET : end - pos).build());
    }
    DataSource d = upstream;
    if (d == null) throw new IOException("read-ahead source not open");
    int n = d.read(buffer, offset, length);
    if (n > 0) pos += n;
    return n;
  }

  @Nullable
  @Override
  public Uri getUri() {
    if (ring) return spec == null ? null : spec.uri;
    return upstream == null ? null : upstream.getUri();
  }

  @NonNull
  @Override
  public Map<String, List<String>> getResponseHeaders() {
    return upstream == null ? Collections.emptyMap() : upstream.getResponseHeaders();
  }

  @Override
  public void close() throws IOException {
    ring = false;
    spec = null;
    DataSource d = upstream;
    upstream = null;
    if (d != null) d.close();
  }
}
