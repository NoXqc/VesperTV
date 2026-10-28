import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_size.dart';

/// A cached debrid link that answers with the provider's 0.4 MB error clip
/// (Comet "Unexpected provider response", 2026-10-28) is told apart from
/// the file, and from an uncached link's "being downloaded" clip.
void main() {
  ArchiveStreamOption option(String name, {int? size, String title = ''}) =>
      ArchiveStreamOption(
        source: const ArchiveSource(
            manifestUrl: 'https://a.example/manifest.json', name: 'A'),
        stream: ArchiveStream(
            url: 'https://a.example/x',
            name: name,
            title: title,
            sizeBytes: size),
      );
  const clip = 419051;
  const url = 'https://comet.example/eyJ/playback/abc';

  test('cached remux answered with a tiny clip = failed', () {
    expect(
        archiveProviderFailed(
            option('[TB⚡] 2160p', size: 90373327794), url, clip),
        isTrue);
    expect(
        archiveProviderFailed(
            option('[RD+] Torrentio 4k', title: '💾 58.2 GB'), url, clip),
        isTrue);
  });

  test('never a false positive', () {
    // The real file.
    expect(
        archiveProviderFailed(
            option('[TB⚡] 2160p', size: 90373327794), url, 90373327794),
        isFalse);
    // Unknown served size.
    expect(
        archiveProviderFailed(
            option('[TB⚡] 2160p', size: 90373327794), url, null),
        isFalse);
    // Uncached: the Ready watch's "being downloaded" clip.
    expect(
        archiveProviderFailed(
            option('[TB download] 2160p', size: 9e10.toInt()), url, clip),
        isFalse);
    expect(
        archiveProviderFailed(
            option('[TB⏳] 2160p', size: 9e10.toInt()), url, clip),
        isFalse);
    expect(
        archiveProviderFailed(option('[TB⚡] 2160p', size: 9e10.toInt()),
            'https://torrentio.example/videos/downloading_v3.mp4', clip),
        isFalse);
    // No cached mark, or no big size listed (a short clip is real).
    expect(
        archiveProviderFailed(
            option('Direct 1080p', size: 9e10.toInt()), url, clip),
        isFalse);
    expect(
        archiveProviderFailed(
            option('[TB⚡] trailer', size: 3000000), url, clip),
        isFalse);
    expect(archiveProviderFailed(option('[TB⚡] 2160p'), url, clip), isFalse);
  });
}
