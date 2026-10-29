import 'archive_models.dart';

class ArchiveContinueItem {
  const ArchiveContinueItem(
      {required this.source,
      required this.meta,
      this.episode,
      this.progress,
      this.resume = false,
      this.upcoming = false});
  final ArchiveSource source;
  final ArchiveMeta meta;
  final ArchiveVideo? episode;
  final double? progress;
  final bool resume;
  final bool upcoming;
  String get episodeLabel => episode == null
      ? ''
      : 'S${episode!.season.toString().padLeft(2, '0')}E${episode!.episode.toString().padLeft(2, '0')}'
          '${episode!.title.isEmpty ? '' : ' · ${episode!.title}'}';
}

/// Only globally defined IDs can merge catalogs. Source-local IDs keep a
/// namespace, even when a custom content type happens to look like IMDb.
String archiveTitleIdentity(ArchiveSource source, ArchiveMeta meta) {
  if (meta.wireType == null) {
    final imdb = meta.imdb;
    if (imdb != null && RegExp(r'^tt\d+$').hasMatch(imdb)) {
      return '${meta.type.wire}:imdb:$imdb';
    }
    if (RegExp(r'^tmdb:\d+$').hasMatch(meta.id) && source.server == null) {
      return '${meta.type.wire}:${meta.id}';
    }
  }
  return '${source.key}:${meta.wire}:${meta.id}';
}
