import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Automatic per-device defaults: a list of known boxes that need a
/// setting turned on (e.g. a Fire TV Cube that keeps the live picture on
/// top of other pages). A matching rule only changes the *default*; a
/// switch the user has set themselves always wins.
///
/// The list ships with the app ([bundledRules]) and is refreshed from
/// [remoteUrl] (`docs/device-defaults.json` on the site) once per launch,
/// cached for the next one. Remote rules replace bundled ones with the
/// same id, so a bad entry can be corrected without a release (an empty
/// `set` turns it off).
class DeviceDefaults {
  static const remoteUrl = 'https://vespertv.app/device-defaults.json';

  /// Settings a rule may turn on. Anything else in a rule is ignored.
  static const compatVideo = 'compatVideo';
  static const hideVideoOnSports = 'hideVideoOnSports';
  static const _known = {compatVideo, hideVideoOnSports};

  static const List<DeviceRule> bundledRules = [
    // Fire TV Cube (3rd gen), Fire OS 7 / Android 9: the live channel's
    // picture stayed on top of Sports Trak / Settings / Search until
    // Background video was turned on (owner's user, 2026-10-23).
    DeviceRule(
      id: 'fire-tv-cube-3',
      note: 'Fire TV Cube (3rd gen)',
      match: {'model': 'AFTGAZL'},
      set: {hideVideoOnSports: true},
    ),
  ];

  /// This device, read once at startup ([load]). Empty off Android.
  static DeviceFingerprint fingerprint = const DeviceFingerprint();

  /// Rules that matched [fingerprint].
  static List<DeviceRule> matched = const [];

  /// The settings the matched rules turn on.
  static Map<String, bool> get values => {
        for (final rule in matched) ...rule.set,
      };

  /// Reads the device and applies bundled + cached remote rules.
  /// [cachedJson] is the last downloaded list (or null).
  static Future<void> load(String? cachedJson) async {
    if (Platform.isAndroid) fingerprint = await DeviceFingerprint.read();
    apply(cachedJson);
  }

  /// Re-matches with [remoteJson] merged over the bundled rules.
  static void apply(String? remoteJson) {
    matched = rulesFor(fingerprint, merge(bundledRules, parse(remoteJson)));
  }

  /// Downloads the current list. Returns the raw JSON when it parses (so
  /// the caller can cache it), null on any failure.
  static Future<String?> fetch() async {
    try {
      final r = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final body = utf8.decode(r.bodyBytes);
      return parse(body) == null ? null : body;
    } catch (_) {
      return null;
    }
  }

  /// `{"rules": [{"id", "note", "match": {...}, "set": {...}}]}`, or null
  /// if [json] is missing or malformed.
  static List<DeviceRule>? parse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final root = jsonDecode(json);
      if (root is! Map || root['rules'] is! List) return null;
      final rules = <DeviceRule>[];
      for (final r in root['rules'] as List) {
        if (r is! Map || r['id'] is! String || r['match'] is! Map) continue;
        final match = <String, String>{
          for (final e in (r['match'] as Map).entries)
            if (e.value is String) '${e.key}': e.value as String,
        };
        if (match.isEmpty) continue; // would match every device
        final set = <String, bool>{
          if (r['set'] is Map)
            for (final e in (r['set'] as Map).entries)
              if (_known.contains(e.key) && e.value is bool)
                e.key as String: e.value as bool,
        };
        rules.add(DeviceRule(
          id: r['id'] as String,
          note: r['note'] is String ? r['note'] as String : '',
          match: match,
          set: set,
        ));
      }
      return rules;
    } catch (_) {
      return null;
    }
  }

  static List<DeviceRule> merge(
      List<DeviceRule> bundled, List<DeviceRule>? remote) {
    if (remote == null) return bundled;
    final ids = remote.map((r) => r.id).toSet();
    return [...bundled.where((r) => !ids.contains(r.id)), ...remote];
  }

  static List<DeviceRule> rulesFor(
          DeviceFingerprint device, List<DeviceRule> rules) =>
      [
        for (final r in rules)
          if (r.set.isNotEmpty && r.matches(device)) r
      ];

  /// One line for Send log.
  static String describe() {
    final applied = matched.isEmpty
        ? 'none'
        : matched.map((r) => '${r.id} (${r.set.keys.join(', ')})').join('; ');
    return 'Device defaults: $applied · ${fingerprint.describe()}';
  }
}

class DeviceRule {
  const DeviceRule({
    required this.id,
    required this.match,
    required this.set,
    this.note = '',
  });

  final String id;
  final String note;

  /// Fingerprint field → value; every field must match (case-insensitive).
  final Map<String, String> match;
  final Map<String, bool> set;

  bool matches(DeviceFingerprint device) {
    final fields = device.fields;
    return match.entries.every((e) {
      final have = fields[e.key];
      return have != null &&
          have.isNotEmpty &&
          have.toLowerCase() == e.value.toLowerCase();
    });
  }
}

/// What a rule can match on (Android system properties).
class DeviceFingerprint {
  const DeviceFingerprint({
    this.manufacturer = '',
    this.model = '',
    this.hardware = '',
    this.socModel = '',
    this.sdk = '',
  });

  final String manufacturer;
  final String model;
  final String hardware;
  final String socModel;
  final String sdk;

  Map<String, String> get fields => {
        'manufacturer': manufacturer,
        'model': model,
        'hardware': hardware,
        'socModel': socModel,
        'sdk': sdk,
      };

  String describe() => fields.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${e.key}=${e.value}')
      .join(' ');

  static Future<DeviceFingerprint> read() async {
    Future<String> prop(String name) async {
      try {
        final r = await Process.run('getprop', [name]);
        return '${r.stdout}'.trim();
      } catch (_) {
        return '';
      }
    }

    final values = await Future.wait([
      prop('ro.product.manufacturer'),
      prop('ro.product.model'),
      prop('ro.hardware'),
      prop('ro.soc.model'), // Android 12+ only
      prop('ro.build.version.sdk'),
    ]);
    return DeviceFingerprint(
      manufacturer: values[0],
      model: values[1],
      hardware: values[2],
      socModel: values[3],
      sdk: values[4],
    );
  }
}
