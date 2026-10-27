package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import android.net.Uri;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class StreamStatsTest {
  private static final Uri FILE = Uri.parse("https://example.com/movie.mp4");
  private static DataSpec spec(long position, long length) {
    return new DataSpec.Builder().setUri(FILE).setPosition(position).setLength(length).build();
  }
  private static Map<String, List<String>> headers(String... fields) {
    Map<String, List<String>> result = new HashMap<>();
    for (int i = 0; i < fields.length; i += 2) result.put(fields[i], List.of(fields[i + 1]));
    return result;
  }
  @Test public void fullFileSupportsLargeLengthsAndCaseInsensitiveHeaders() {
    assertEquals(70000000000L, StreamStats.fileSizeFromHeaders(
        headers("content-length", "70000000000", "content-type", "video/mp4"), spec(0, C.LENGTH_UNSET)));
  }
  @Test public void partialResponseReportsTotalNotChunkLength() {
    assertEquals(70000000000L, StreamStats.fileSizeFromHeaders(
        headers("Content-Length", "1024", "Content-Range", "bytes 2000-3023/70000000000"), spec(2000, C.LENGTH_UNSET)));
  }
  @Test public void unknownOrMalformedRangesNeverFallBackToChunkLength() {
    for (String range : List.of("bytes 0-1023/*", "bytes 20-10/100", "bytes 0-100/100",
        "bytes 0-1/-1", "bytes 0-1/9999999999999999999999", "not a range")) {
      assertEquals(-1, StreamStats.fileSizeFromHeaders(
          headers("Content-Length", "1024", "Content-Range", range), spec(0, C.LENGTH_UNSET)));
    }
  }
  @Test public void boundedOrOffsetRequestWithoutTotalIsNotFileSize() {
    assertEquals(-1, StreamStats.fileSizeFromHeaders(headers("Content-Length", "1024"), spec(0, 1024)));
    assertEquals(-1, StreamStats.fileSizeFromHeaders(headers("Content-Length", "1024"), spec(100, C.LENGTH_UNSET)));
  }
  @Test public void missingInvalidAndZeroLengthsStayUnknown() {
    assertEquals(-1, StreamStats.fileSizeFromHeaders(Map.of(), spec(0, C.LENGTH_UNSET)));
    assertEquals(-1, StreamStats.fileSizeFromHeaders(null, spec(0, C.LENGTH_UNSET)));
    for (String length : List.of("0", "-100", "unknown", "9999999999999999999999")) {
      assertEquals(-1, StreamStats.fileSizeFromHeaders(headers("Content-Length", length), spec(0, C.LENGTH_UNSET)));
    }
  }
  @Test public void errorDocumentsAndManifestsAreNotVideoFiles() {
    for (String type : List.of("text/html", "application/json", "application/vnd.apple.mpegurl",
        "application/dash+xml", "application/x-mpegURL")) {
      assertEquals(-1, StreamStats.fileSizeFromHeaders(headers("Content-Type", type, "Content-Length", "4096"), spec(0, C.LENGTH_UNSET)));
    }
  }
  @Test public void compressedResponseLengthIsNotUncompressedFileSize() {
    assertEquals(-1, StreamStats.fileSizeFromHeaders(headers("Content-Length", "4096", "Content-Encoding", "gzip"), spec(0, C.LENGTH_UNSET)));
  }
  @Test public void activeConnectionHeadersWorkAcrossRedirectAndKeepByteCounterSeparate() {
    StreamStats stats = new StreamStats(FILE);
    DataSource source = mock(DataSource.class);
    when(source.getUri()).thenReturn(Uri.parse("https://cdn.example/redirected-file"));
    when(source.getResponseHeaders()).thenReturn(headers("Content-Length", "70000000000"));
    stats.onTransferStart(source, spec(0, C.LENGTH_UNSET), true);
    stats.onBytesTransferred(source, spec(0, C.LENGTH_UNSET), true, 1024);
    assertEquals(70000000000L, stats.fileSizeBytes.get());
    assertEquals(1024, stats.bytes.get());
  }
  @Test public void ignoresSideResourcesAndNonNetworkTransfers() {
    StreamStats stats = new StreamStats(FILE);
    DataSource source = mock(DataSource.class);
    when(source.getResponseHeaders()).thenReturn(headers("Content-Length", "4096"));
    stats.onTransferStart(source, new DataSpec(Uri.parse("https://example.com/subtitles.srt")), true);
    stats.onTransferStart(source, spec(0, C.LENGTH_UNSET), false);
    assertEquals(-1, stats.fileSizeBytes.get());
  }
  @Test public void newFileCannotInheritPreviousFileSize() {
    StreamStats stats = new StreamStats(FILE);
    DataSource source = mock(DataSource.class);
    when(source.getResponseHeaders()).thenReturn(headers("Content-Length", "4096"));
    stats.onTransferStart(source, spec(0, C.LENGTH_UNSET), true);
    assertEquals(4096, stats.fileSizeBytes.get());
    assertEquals(-1, new StreamStats(FILE).fileSizeBytes.get());
  }
  @Test public void allAdaptiveHintsExcludeManifestAndSegmentSizes() {
    for (VideoAsset.StreamingFormat format : List.of(VideoAsset.StreamingFormat.HTTP_LIVE,
        VideoAsset.StreamingFormat.DYNAMIC_ADAPTIVE, VideoAsset.StreamingFormat.SMOOTH)) {
      assertExcluded("https://example.com/extensionless", format);
    }
  }
  @Test public void inferredAdaptiveTypesAlsoExcludeManifestSizes() {
    for (String url : List.of("https://example.com/index.m3u8?token=test",
        "https://example.com/manifest.mpd", "https://example.com/channel.ism/Manifest")) {
      assertExcluded(url, VideoAsset.StreamingFormat.UNKNOWN);
    }
  }
  private static void assertExcluded(String url, VideoAsset.StreamingFormat format) {
    StreamStats stats = new HttpVideoAsset(url, format, Map.of(), null).streamStats();
    DataSource source = mock(DataSource.class);
    when(source.getResponseHeaders()).thenReturn(headers("Content-Length", "4096"));
    stats.onTransferStart(source, new DataSpec(Uri.parse(url)), true);
    assertEquals(-1, stats.fileSizeBytes.get());
  }
  @Test public void ordinaryProgressiveAssetReportsSize() {
    StreamStats stats = new HttpVideoAsset(FILE.toString(), VideoAsset.StreamingFormat.UNKNOWN, Map.of(), null).streamStats();
    DataSource source = mock(DataSource.class);
    when(source.getResponseHeaders()).thenReturn(headers("Content-Length", "9000000000"));
    stats.onTransferStart(source, new DataSpec(FILE), true);
    assertEquals(9000000000L, stats.fileSizeBytes.get());
  }
}
