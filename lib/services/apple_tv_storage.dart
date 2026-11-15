import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Where VesperTV keeps its data on Apple TV (dev-notes/apple-tv.md).
///
/// A physical Apple TV lets an app write only to its Caches and tmp folders:
/// Documents is read-only there (the simulator allows the write, so only a
/// real box shows it), and NSUserDefaults is meant for ~500 KB. tvOS may
/// empty Caches when the box runs low on space while the app isn't running:
/// the guide and catalogs then reload like on a first launch.
///
/// [install] runs once at startup, on Apple TV only, before anything opens a
/// file or SharedPreferences:
/// - path_provider's Documents and Application Support become folders inside
///   Caches, so every database and file the app (and its plugins) writes
///   lands somewhere writable without touching each caller;
/// - SharedPreferences live in a JSON file in Caches (no size limit), with a
///   copy in NSUserDefaults while it stays under [AppleTvPrefsStore.copyLimit],
///   so settings and logins survive Caches being emptied.
class AppleTvStorage {
  static bool _installed = false;

  static Future<void> install() async {
    if (_installed) return;
    _installed = true;
    final paths = PathProviderPlatform.instance;
    final caches = await paths.getApplicationCachePath();
    if (caches == null) {
      debugPrint('AppleTvStorage: no Caches folder, paths unchanged');
      return;
    }
    PathProviderPlatform.instance = AppleTvPaths(paths, caches);
    final store = AppleTvPrefsStore(
      SharedPreferencesStorePlatform.instance,
      File('$caches/Support/vesper_prefs.json'),
    );
    SharedPreferencesStorePlatform.instance = store;
    final count = (await store.getAll()).length;
    debugPrint('AppleTvStorage: data under $caches, $count settings loaded '
        '(${store.restoredFromCopy ? 'from the NSUserDefaults copy' : 'from the file'})');
  }
}

/// path_provider with Documents and Application Support moved under Caches
/// ([AppleTvStorage]). Everything else is asked of the tvOS plugin.
class AppleTvPaths extends PathProviderPlatform {
  AppleTvPaths(this._inner, this._caches);

  final PathProviderPlatform _inner;
  final String _caches;

  Future<String> _folder(String name) async {
    final dir = Directory('$_caches/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() => _folder('Documents');

  @override
  Future<String?> getApplicationSupportPath() => _folder('Support');

  @override
  Future<String?> getTemporaryPath() => _inner.getTemporaryPath();

  @override
  Future<String?> getApplicationCachePath() => _inner.getApplicationCachePath();

  @override
  Future<String?> getLibraryPath() => _inner.getLibraryPath();

  @override
  Future<String?> getDownloadsPath() => _inner.getDownloadsPath();

  @override
  Future<String?> getExternalStoragePath() => _inner.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() =>
      _inner.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      _inner.getExternalStoragePaths(type: type);
}

/// SharedPreferences kept in a JSON file ([AppleTvStorage]), with a copy in
/// NSUserDefaults ([_defaults], the tvOS plugin's store) while the file is
/// under [copyLimit]. The file wins; the copy is read only when the file is
/// missing (Caches emptied).
class AppleTvPrefsStore extends SharedPreferencesStorePlatform {
  AppleTvPrefsStore(this._defaults, this._file);

  final SharedPreferencesStorePlatform _defaults;
  final File _file;

  /// NSUserDefaults' guaranteed space is ~500 KB; the copy stays under it.
  static const copyLimit = 400 * 1024;
  static const _copyKey = 'flutter.vesper_appletv_prefs_copy';
  static const _defaultPrefix = 'flutter.';

  Map<String, Object>? _data;
  Future<Map<String, Object>>? _loading;
  bool _dirty = false;
  Future<void>? _writing;

  /// True when this run's settings came from the NSUserDefaults copy.
  bool restoredFromCopy = false;

  Future<Map<String, Object>> _load() {
    final data = _data;
    if (data != null) return Future.value(data);
    return _loading ??= () async {
      var loaded = <String, Object>{};
      try {
        if (await _file.exists()) loaded = decode(await _file.readAsString());
      } catch (e) {
        debugPrint('AppleTvPrefs: settings file unreadable: $e');
      }
      if (loaded.isEmpty) {
        try {
          final copy = (await _defaults.getAll())[_copyKey];
          if (copy is String) {
            loaded = decode(copy);
            restoredFromCopy = loaded.isNotEmpty;
          }
        } catch (e) {
          debugPrint('AppleTvPrefs: no NSUserDefaults copy: $e');
        }
      }
      return _data = loaded;
    }();
  }

  /// `{"key": {"t": "String", "v": "..."}}`: the value type keeps ints, doubles
  /// and string lists apart through JSON.
  static String encode(Map<String, Object> data) => jsonEncode({
        for (final e in data.entries)
          e.key: {'t': _typeOf(e.value), 'v': e.value},
      });

  static Map<String, Object> decode(String json) {
    final out = <String, Object>{};
    final raw = jsonDecode(json);
    if (raw is! Map) return out;
    raw.forEach((key, entry) {
      if (key is! String || entry is! Map) return;
      final value = entry['v'];
      switch (entry['t']) {
        case 'Bool':
          if (value is bool) out[key] = value;
        case 'Int':
          if (value is num) out[key] = value.toInt();
        case 'Double':
          if (value is num) out[key] = value.toDouble();
        case 'String':
          if (value is String) out[key] = value;
        case 'StringList':
          if (value is List) out[key] = value.whereType<String>().toList();
      }
    });
    return out;
  }

  static String _typeOf(Object value) => switch (value) {
        bool() => 'Bool',
        int() => 'Int',
        double() => 'Double',
        List() => 'StringList',
        _ => 'String',
      };

  void _save() {
    _dirty = true;
    _writing ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        final json = encode(_data!);
        try {
          await _file.parent.create(recursive: true);
          final tmp = File('${_file.path}.tmp');
          await tmp.writeAsString(json, flush: true);
          await tmp.rename(_file.path);
        } catch (e) {
          debugPrint('AppleTvPrefs: settings file not written: $e');
        }
        try {
          if (utf8.encode(json).length <= copyLimit) {
            await _defaults.setValue('String', _copyKey, json);
          } else {
            await _defaults.remove(_copyKey);
          }
        } catch (e) {
          debugPrint('AppleTvPrefs: NSUserDefaults copy not written: $e');
        }
      }
    } finally {
      _writing = null;
    }
  }

  /// Waits for pending writes (tests).
  @visibleForTesting
  Future<void> flush() async {
    while (_writing != null) {
      await _writing;
    }
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final data = await _load();
    data[key] = value is List ? List<String>.from(value) : value;
    _save();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    final data = await _load();
    if (data.remove(key) != null) _save();
    return true;
  }

  @override
  Future<bool> clear() => clearWithParameters(
        ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
      );

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
        ClearParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final data = await _load();
    final filter = parameters.filter;
    final before = data.length;
    data.removeWhere((key, _) =>
        key.startsWith(filter.prefix) &&
        (filter.allowList == null || filter.allowList!.contains(key)));
    if (data.length != before) _save();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final data = await _load();
    final filter = parameters.filter;
    return {
      for (final e in data.entries)
        if (e.key.startsWith(filter.prefix) &&
            (filter.allowList == null || filter.allowList!.contains(e.key)))
          e.key: e.value is List ? List<String>.from(e.value as List) : e.value,
    };
  }
}
