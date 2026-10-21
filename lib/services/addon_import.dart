import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/archive_models.dart';
import 'addon_service.dart';
import 'archive_api_service.dart';
import 'archive_service.dart';

/// What an import of several add-on links did (Settings > Media Hub
/// sources: a pasted list, or Import from Stremio). Names, for the summary.
class AddonImportResult {
  final added = <String>[];
  final subtitles = <String>[];
  final alreadyThere = <String>[];

  /// Links no part of VesperTV can use (no streams/lists/subtitles, or
  /// lists on their own ids), and links that didn't answer.
  final unusable = <String>[];
  final unreachable = <String>[];

  int get total =>
      added.length +
      subtitles.length +
      alreadyThere.length +
      unusable.length +
      unreachable.length;
}

/// Adds many add-on links at once: each one becomes a Media Hub source
/// when it can ([ArchiveService.checkSource]), else a subtitle add-on
/// (Settings > Add-ons) when it offers subtitles; the sources are saved in
/// one go so the Media Hub refreshes once.
class AddonImporter {
  AddonImporter(this._archive, this._addons);

  final ArchiveService _archive;
  final AddonService _addons;

  /// Every add-on link in [text] — one per line, separated by spaces, or
  /// run together (a single-line field drops pasted line breaks).
  static List<String> linksIn(String text) {
    final seen = <String>{};
    return [
      for (final m in RegExp(r'(?:https?|stremio)://\S+?/manifest\.json')
          .allMatches(text))
        if (seen.add(ArchiveApiService.normalizeManifestUrl(m[0]!)))
          ArchiveApiService.normalizeManifestUrl(m[0]!),
    ];
  }

  /// [names]: a known name per link (Stremio's list), shown for links
  /// that fail before their manifest is read.
  Future<AddonImportResult> importLinks(List<String> links,
      {Map<String, String> names = const {}}) async {
    final result = AddonImportResult();
    final checked = <ArchiveSource>[];
    final subtitleLinks = <String>{
      for (final a in _addons.addons) a.manifestUrl,
    };
    final newSubtitles = <Addon>[];
    String nameOf(String url) => names[url] ?? Uri.parse(url).host;

    await Future.wait(links.map((url) async {
      if (_archive.hasSource(url)) {
        result.alreadyThere.add(nameOf(url));
        return;
      }
      try {
        checked.add(await _archive.checkSource(url));
        return;
      } on ArchiveApiException {
        // Not a Media Hub source: maybe subtitles.
      } catch (e) {
        debugPrint('AddonImporter: $url failed: $e');
        result.unreachable.add(nameOf(url));
        return;
      }
      try {
        final sub = await AddonService.fetchManifest(url);
        if (sub == null) {
          result.unusable.add(nameOf(url));
        } else if (!subtitleLinks.add(sub.manifestUrl)) {
          result.alreadyThere.add(sub.name);
        } else {
          newSubtitles.add(sub);
        }
      } catch (_) {
        result.unusable.add(nameOf(url));
      }
    }));

    for (final s in await _archive.addCheckedSources(checked)) {
      result.added.add(s.name);
    }
    if (newSubtitles.isNotEmpty) {
      await _addons.save([..._addons.addons, ...newSubtitles]);
      result.subtitles.addAll(newSubtitles.map((a) => a.name));
    }
    return result;
  }
}

/// One add-on in a Stremio account.
class StremioAddon {
  const StremioAddon(this.url, this.name);
  final String url;
  final String name;
}

/// Reads the add-ons installed on a Stremio account, signed in from a
/// phone with a short code (link.stremio.com — the flow Stremio's own TV
/// app uses; no password typed on the TV). Stremio's account API isn't
/// publicly documented: checked by hand 2026-10-21.
class StremioAccount {
  StremioAccount({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _link = 'https://link.stremio.com/api/v2';
  static const _api = 'https://api.strem.io/api';
  static const _timeout = Duration(seconds: 15);

  /// A new sign-in code: show [link] as a QR and [code] as text.
  Future<({String code, String link})> createCode() async {
    final r = await _client
        .get(Uri.parse('$_link/create?type=Create'))
        .timeout(_timeout);
    final j = jsonDecode(r.body) as Map;
    final res = (j['result'] ?? j) as Map;
    return (code: res['code'] as String, link: res['link'] as String);
  }

  /// The session once someone signed in with [code]; null while waiting
  /// (Stremio answers "invalid or expired" until then).
  Future<String?> sessionFor(String code) async {
    final r = await _client
        .get(Uri.parse(
            '$_link/read?type=Read&code=${Uri.encodeQueryComponent(code)}'))
        .timeout(_timeout);
    final j = jsonDecode(r.body);
    if (j is! Map) return null;
    final res = j['result'];
    final key = res is Map ? res['authKey'] : j['authKey'];
    return key is String && key.isNotEmpty ? key : null;
  }

  /// The account's add-ons, in its own order. Stremio's built-ins
  /// (Cinemeta, Local Files — `protected`) and non-web links are left out:
  /// VesperTV has its own Cinemeta, and the others only work inside
  /// Stremio.
  Future<List<StremioAddon>> addons(String authKey) async {
    final r = await _client
        .post(Uri.parse('$_api/addonCollectionGet'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': 'AddonCollectionGet',
              'authKey': authKey,
              'update': true,
            }))
        .timeout(_timeout);
    final j = jsonDecode(r.body) as Map;
    if (j['error'] != null) throw StateError('${j['error']}');
    final list = ((j['result'] as Map?)?['addons'] as List?) ?? const [];
    return [
      for (final a in list.whereType<Map>())
        if (a['transportUrl'] case final String url
            when url.startsWith('https://') || url.startsWith('http://'))
          if ((a['flags'] as Map?)?['protected'] != true &&
              !Uri.parse(url).host.startsWith('127.') &&
              Uri.parse(url).host != 'localhost' &&
              !url.contains('v3-cinemeta.strem.io'))
            StremioAddon(
                url, ((a['manifest'] as Map?)?['name'] ?? url).toString()),
    ];
  }

  /// Ends the session VesperTV used (the account stays signed in on the
  /// user's own devices).
  Future<void> signOut(String authKey) async {
    try {
      await _client
          .post(Uri.parse('$_api/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'type': 'Logout', 'authKey': authKey}))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('StremioAccount: sign-out failed: $e');
    }
  }
}
