import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// The user's own Real-Debrid / TorBox account (Settings > Media Hub >
/// Debrid accounts, bring-your-own key). Only used to confirm that a title
/// the source was still fetching is now in the account (`ArchiveReadyWatch`)
/// — VesperTV never adds, removes or plays anything through it.
class DebridApi {
  DebridApi(this._storage, {http.Client? client})
      : _client = client ?? http.Client();

  final StorageService _storage;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  bool get configured =>
      (_storage.getRealDebridToken()?.isNotEmpty ?? false) ||
      (_storage.getTorBoxKey()?.isNotEmpty ?? false);

  /// The torrent hash in a source's stream URL — debrid-backed sources put
  /// it in the path (`…/{hash}/{file}`). Null when the URL has none.
  static String? infoHashIn(String url) =>
      RegExp(r'(?<![0-9a-fA-F])[0-9a-fA-F]{40}(?![0-9a-fA-F])')
          .firstMatch(url)?[0]
          ?.toLowerCase();

  /// Every torrent in the user's accounts, by lower-case hash: true when
  /// it has finished downloading. Empty when no key is set or every
  /// account failed to answer.
  Future<Map<String, bool>> torrents() async {
    final out = <String, bool>{};
    final rd = _storage.getRealDebridToken();
    if (rd != null && rd.isNotEmpty) out.addAll(await _realDebrid(rd));
    final tb = _storage.getTorBoxKey();
    if (tb != null && tb.isNotEmpty) {
      for (final e in (await _torBox(tb)).entries) {
        out[e.key] = (out[e.key] ?? false) || e.value;
      }
    }
    return out;
  }

  Future<Map<String, bool>> _realDebrid(String token) async {
    try {
      final r = await _client.get(
          Uri.parse('https://api.real-debrid.com/rest/1.0/torrents?limit=500'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);
      // 204 = an empty account.
      if (r.statusCode == 204) return const {};
      if (r.statusCode != 200) return const {};
      final list = jsonDecode(r.body);
      if (list is! List) return const {};
      return {
        for (final t in list.whereType<Map>())
          if (t['hash'] is String)
            (t['hash'] as String).toLowerCase(): t['status'] == 'downloaded',
      };
    } catch (e) {
      debugPrint('DebridApi: Real-Debrid failed: $e');
      return const {};
    }
  }

  Future<Map<String, bool>> _torBox(String key) async {
    try {
      final r = await _client.get(
          Uri.parse(
              'https://api.torbox.app/v1/api/torrents/mylist?bypass_cache=true'),
          headers: {'Authorization': 'Bearer $key'}).timeout(_timeout);
      if (r.statusCode != 200) return const {};
      final data = (jsonDecode(r.body) as Map)['data'];
      if (data is! List) return const {};
      return {
        for (final t in data.whereType<Map>())
          if (t['hash'] is String)
            (t['hash'] as String).toLowerCase():
                t['download_finished'] == true || t['download_present'] == true,
      };
    } catch (e) {
      debugPrint('DebridApi: TorBox failed: $e');
      return const {};
    }
  }

  /// Does Real-Debrid accept [token]? (`/user` answers 200.)
  Future<bool> checkRealDebrid(String token) async {
    try {
      final r = await _client.get(
          Uri.parse('https://api.real-debrid.com/rest/1.0/user'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Does TorBox accept [key]? (`/user/me` answers success.)
  Future<bool> checkTorBox(String key) async {
    try {
      final r = await _client.get(
          Uri.parse('https://api.torbox.app/v1/api/user/me'),
          headers: {'Authorization': 'Bearer $key'}).timeout(_timeout);
      if (r.statusCode != 200) return false;
      return (jsonDecode(r.body) as Map)['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
