import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/archive_models.dart';
import 'addon_import.dart';
import 'addon_service.dart';
import 'archive_service.dart';
import 'storage_service.dart';

/// What a Media Hub source mainly is, for the sources page's filters.
enum HubKind { streams, catalogs, server, lists, live, subtitles }

/// One row of Settings > Media Hub sources (owner, 2026-11-11: one list of
/// every add-on, like Stremio / Nuvio): a Media Hub source, the built-in
/// Cinemeta catalog or a subtitle add-on, with the switches it has. Shared
/// by the TV page and the phone page ([HubRemote]), so both list the same.
class HubEntry {
  HubEntry._({
    required this.key,
    required this.name,
    required this.kind,
    required this.tags,
    required this.enabled,
    this.description = '',
    this.logoUrl,
    this.version,
    this.other,
    this.liveTv,
    this.builtIn = false,
    this.removable = true,
    this.hasUrl = true,
    this.movieCatalogs = 0,
    this.showCatalogs = 0,
    this.otherCatalogs = 0,
    this.source,
    this.addon,
  });

  /// `src:<ArchiveSource.key>`, `sub:<sha1 of its link>` or `cinemeta`.
  final String key;
  final String name;
  final String description;
  final String? logoUrl;
  final String? version;
  final HubKind kind;

  /// What it gives: `streams`, `catalogs`, `movies`, `shows`, `live`,
  /// `subtitles`, `server`, `lists`, `builtin`, `other` (translated where
  /// shown).
  final List<String> tags;
  final bool enabled;

  /// Show under Other: null = not offered (servers, lists, subtitles).
  final bool? other;

  /// TV add-on: null = not offered.
  final bool? liveTv;
  final bool builtIn;
  final bool removable;

  /// Has a link to view and copy (not a Trakt / Simkl account).
  final bool hasUrl;
  final int movieCatalogs, showCatalogs, otherCatalogs;

  /// Catalogs come from Cinemeta (a stream-only add-on).
  bool get cinemetaCatalogs => source?.streamOnly ?? false;

  final ArchiveSource? source;
  final Addon? addon;

  static const cinemetaKey = 'cinemeta';

  /// Every entry: Media Hub sources in their saved order, Cinemeta, then
  /// the subtitle add-ons.
  static List<HubEntry> all(ArchiveService archive, AddonService addons) => [
        for (final s in archive.sources) fromSource(s),
        HubEntry._(
          key: cinemetaKey,
          name: ArchiveCatalogProvider.name,
          kind: HubKind.catalogs,
          tags: const ['catalogs', 'movies', 'shows', 'builtin'],
          enabled: archive.showCinemetaCatalog,
          builtIn: true,
          removable: false,
          hasUrl: false,
        ),
        for (final a in addons.addons) fromAddon(a),
      ];

  static HubEntry fromSource(ArchiveSource s) {
    final types = {for (final c in s.catalogs) c.type};
    final kind = s.server != null
        ? HubKind.server
        : s.tracker != null
            ? HubKind.lists
            : s.isLiveTv
                ? HubKind.live
                : s.listOnly
                    ? HubKind.catalogs
                    : HubKind.streams;
    final plain = s.server == null && s.tracker == null;
    return HubEntry._(
      key: 'src:${s.key}',
      name: s.name,
      description: s.description,
      logoUrl: s.logoUrl,
      version: s.version,
      kind: kind,
      tags: [
        if (kind == HubKind.server) 'server',
        if (kind == HubKind.lists) 'lists',
        if (plain && !s.listOnly && !s.isLiveTv) 'streams',
        if (plain && !s.streamOnly && !s.isLiveTv) 'catalogs',
        if (s.isLiveTv) 'live',
        if (!s.isLiveTv && types.contains(ArchiveType.movie)) 'movies',
        if (!s.isLiveTv && types.contains(ArchiveType.series)) 'shows',
        if (plain && s.underOther) 'other',
      ],
      enabled: s.enabled,
      other: plain ? s.underOther : null,
      liveTv: s.canBeLiveTv ? s.isLiveTv : null,
      hasUrl: s.tracker == null,
      movieCatalogs: s.catalogs
          .where((c) => c.type == ArchiveType.movie && c.wireType == null)
          .length,
      showCatalogs: s.catalogs
          .where((c) => c.type == ArchiveType.series && c.wireType == null)
          .length,
      otherCatalogs: s.catalogs.where((c) => c.wireType != null).length,
      source: s,
    );
  }

  static HubEntry fromAddon(Addon a) => HubEntry._(
        key: 'sub:${sha1.convert(utf8.encode(a.manifestUrl))}',
        name: a.name,
        description: a.description,
        kind: HubKind.subtitles,
        tags: const ['subtitles'],
        enabled: a.enabled,
        removable: a.manifestUrl != AddonService.openSubtitlesManifest,
        addon: a,
      );

  /// The link to view or copy: an add-on's manifest, a server's address.
  String? get url {
    final s = source;
    if (s != null) {
      if (s.tracker != null) return null;
      return s.server == null ? s.manifestUrl : s.baseUrl;
    }
    return addon?.manifestUrl;
  }
}

/// The phone side of Settings > Media Hub sources > Manage from phone
/// (owner, 2026-11-11): the relay's page (`/hub`, tools/pair_relay/hub.html)
/// sends `hub/...` JSON-RPC through the Vesper link ([McpBridge]) and this
/// runs them on the TV with the same switches as the TV page. A source's
/// link (it can hold a debrid key) only travels on `hub/url`, when the
/// phone copies it.
class HubRemote {
  HubRemote._();
  static final instance = HubRemote._();

  ArchiveService? _archive;
  StorageService? _storage;

  void attach(ArchiveService archive, StorageService storage) {
    _archive = archive;
    _storage = storage;
  }

  static bool handles(String method) => method.startsWith('hub/');

  Future<Map<String, Object?>> handle(
      String method, Map<String, Object?> params) async {
    final archive = _archive, storage = _storage;
    if (archive == null || storage == null) {
      return _error('VesperTV is still starting.');
    }
    final addons = AddonService(storage);
    HubEntry? find() {
      final key = '${params['key'] ?? ''}';
      return HubEntry.all(archive, addons)
          .where((e) => e.key == key)
          .firstOrNull;
    }

    switch (method) {
      case 'hub/list':
        return {'result': _list(archive, addons)};
      case 'hub/set':
        final e = find();
        if (e == null) return _error('That source is gone.');
        final value = params['value'] == true;
        switch (params['field']) {
          case 'enabled':
            await setEntryEnabled(archive, addons, e, value);
          case 'other' when e.other != null:
            await archive.setUnderOther(e.source!, value);
          case 'tv' when e.liveTv != null:
            await archive.setLiveTv(e.source!, value);
          default:
            return _error('That switch isn\'t there for ${e.name}.');
        }
        return {'result': _list(archive, addons)};
      case 'hub/remove':
        final e = find();
        if (e == null) return _error('That source is gone.');
        if (!e.removable) return _error('${e.name} is built in.');
        await removeEntry(archive, addons, e);
        return {'result': _list(archive, addons)};
      case 'hub/url':
        final e = find();
        final url = e?.url;
        if (url == null) return _error('No link for that source.');
        return {
          'result': {'url': url}
        };
      case 'hub/add':
        final links = AddonImporter.linksIn('${params['links'] ?? ''}');
        if (links.isEmpty) {
          return _error('Paste a link that ends with manifest.json.');
        }
        if (links.length > 40) return _error('40 links at a time, at most.');
        final result =
            await AddonImporter(archive, addons).importLinks(links);
        return {
          'result': {
            ..._list(archive, addons),
            'summary': _summary(result),
          }
        };
    }
    return {
      'error': {'code': -32601, 'message': 'Method not found: $method'}
    };
  }

  /// Turns [e] on or off: a source for the profile in use, Cinemeta's
  /// rows, or a subtitle add-on (for the device). The TV page uses it too.
  static Future<void> setEntryEnabled(ArchiveService archive,
      AddonService addons, HubEntry e, bool on) async {
    if (e.key == HubEntry.cinemetaKey) {
      await archive.setShowCinemetaCatalog(on);
    } else if (e.source != null) {
      await archive.setEnabled(e.source!, on);
    } else {
      await addons.save([
        for (final a in addons.addons)
          a.manifestUrl == e.addon!.manifestUrl ? a.copyWith(enabled: on) : a
      ]);
    }
  }

  /// Removes [e] for every profile (a source) or from the device (a
  /// subtitle add-on). Built-in entries stay.
  static Future<void> removeEntry(
      ArchiveService archive, AddonService addons, HubEntry e) async {
    if (!e.removable) return;
    if (e.source != null) {
      await archive.removeSource(e.source!);
    } else if (e.addon != null) {
      await addons.save([
        for (final a in addons.addons)
          if (a.manifestUrl != e.addon!.manifestUrl) a
      ]);
    }
  }

  static Map<String, Object?> _list(
          ArchiveService archive, AddonService addons) =>
      {
        'sources': [
          for (final e in HubEntry.all(archive, addons))
            {
              'key': e.key,
              'name': e.name,
              if (e.description.isNotEmpty) 'description': e.description,
              if (e.logoUrl != null) 'logo': e.logoUrl,
              if (e.version != null) 'version': e.version,
              'kind': e.kind.name,
              'tags': e.tags,
              'enabled': e.enabled,
              if (e.other != null) 'other': e.other,
              if (e.liveTv != null) 'tv': e.liveTv,
              'removable': e.removable,
              'hasUrl': e.hasUrl,
              if (e.cinemetaCatalogs) 'cinemeta': true,
              'movies': e.movieCatalogs,
              'shows': e.showCatalogs,
              'others': e.otherCatalogs,
            }
        ],
      };

  static String _summary(AddonImportResult r) => [
        if (r.added.isNotEmpty) 'Added: ${r.added.join(', ')}.',
        if (r.subtitles.isNotEmpty)
          'Subtitle add-ons: ${r.subtitles.join(', ')}.',
        if (r.alreadyThere.isNotEmpty)
          'Already there: ${r.alreadyThere.join(', ')}.',
        if (r.unusable.isNotEmpty)
          'Not a Media Hub source: ${r.unusable.length} link(s).',
        if (r.unreachable.isNotEmpty)
          'Couldn\'t reach: ${r.unreachable.length} link(s).',
      ].join(' ');

  static Map<String, Object?> _error(String message) => {
        'error': {'code': -32000, 'message': message}
      };
}
