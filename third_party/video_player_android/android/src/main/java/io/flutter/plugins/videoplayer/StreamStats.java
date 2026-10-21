// VesperTV patch: counts the bytes a player's HTTP data source really downloads, for the Data
// pool's measured bitrate (live MPEG-TS declares none). See StatsBridge.
package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import java.util.concurrent.atomic.AtomicLong;

@OptIn(markerClass = UnstableApi.class)
final class StreamStats implements TransferListener {
  /** Network bytes since the player was created; written on loader threads. */
  final AtomicLong bytes = new AtomicLong();

  @Override
  public void onTransferInitializing(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {}

  @Override
  public void onTransferStart(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {}

  @Override
  public void onBytesTransferred(
      @NonNull DataSource source,
      @NonNull DataSpec dataSpec,
      boolean isNetwork,
      int bytesTransferred) {
    if (isNetwork) bytes.addAndGet(bytesTransferred);
  }

  @Override
  public void onTransferEnd(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {}
}
