import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../models/channel.dart';
import 'addon_service.dart';
import 'storage_service.dart';

/// Display name for a subtitle/audio language code ("fr-CA" → "Français
/// (CA)"), in that language — how pickers usually list them.
String languageName(String? code) {
  if (code == null || code.isEmpty || code == 'und') return '';
  final parts = code.split(RegExp('[-_]'));
  const names = {
    'en': 'English',
    'eng': 'English',
    'fr': 'Français',
    'fre': 'Français',
    'fra': 'Français',
    'es': 'Español',
    'spa': 'Español',
    'it': 'Italiano',
    'ita': 'Italiano',
    'de': 'Deutsch',
    'ger': 'Deutsch',
    'deu': 'Deutsch',
    'pt': 'Português',
    'por': 'Português',
    'nl': 'Nederlands',
    'dut': 'Nederlands',
    'nld': 'Nederlands',
    'ar': 'العربية',
    'ara': 'العربية',
    'ru': 'Русский',
    'rus': 'Русский',
    'ja': '日本語',
    'jpn': '日本語',
    'ko': '한국어',
    'kor': '한국어',
    'zh': '中文',
    'chi': '中文',
    'zho': '中文',
    'hi': 'हिन्दी',
    'hin': 'हिन्दी',
    'tr': 'Türkçe',
    'tur': 'Türkçe',
    'pl': 'Polski',
    'pol': 'Polski',
    'sv': 'Svenska',
    'swe': 'Svenska',
    'da': 'Dansk',
    'dan': 'Dansk',
    'no': 'Norsk',
    'nb': 'Norsk',
    'nor': 'Norsk',
    'fi': 'Suomi',
    'fin': 'Suomi',
    'el': 'Ελληνικά',
    'gre': 'Ελληνικά',
    'he': 'עברית',
    'heb': 'עברית',
    'cs': 'Čeština',
    'cze': 'Čeština',
    'hu': 'Magyar',
    'hun': 'Magyar',
    'ro': 'Română',
    'rum': 'Română',
    'uk': 'Українська',
    'vi': 'Tiếng Việt',
    'vie': 'Tiếng Việt',
    'th': 'ไทย',
    'tha': 'ไทย',
    'id': 'Bahasa Indonesia',
    'ind': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
    'hr': 'Hrvatski',
    'bg': 'Български',
    'ta': 'தமிழ்',
    'tam': 'தமிழ்',
    'ell': 'Ελληνικά',
    'srp': 'Српски',
    'ron': 'Română',
    'bul': 'Български',
    'ukr': 'Українська',
    'slv': 'Slovenščina',
    'slk': 'Slovenčina',
    'est': 'Eesti',
    'lav': 'Latviešu',
    'lit': 'Lietuvių',
    'per': 'فارسی',
    'fas': 'فارسی',
    'hrv': 'Hrvatski',
    'pob': 'Português (BR)',
    'zht': '中文 (繁體)',
    'zhe': '中文',
    'may': 'Bahasa Melayu',
    'msa': 'Bahasa Melayu',
  };
  final base = names[parts.first.toLowerCase()] ?? parts.first.toUpperCase();
  return parts.length > 1 ? '$base (${parts.sublist(1).join('-')})' : base;
}

/// The languages offered as a preferred audio/subtitle language.
const trackLanguages = [
  'en', 'fr', 'es', 'it', 'el', 'de', 'pt', 'nl', 'ar', 'ru', 'ja', 'ko', //
  'zh', 'hi', 'tr', 'pl', 'sv', 'da', 'no', 'fi',
];

/// Treat ISO-639 aliases and region variants as the same base language.
bool sameTrackLanguage(String? a, String? b) {
  final left = languageName(a?.toLowerCase()).split(' (').first;
  final right = languageName(b?.toLowerCase()).split(' (').first;
  return left.isNotEmpty && left == right;
}

/// One subtitle track inside the playing file (MKV/MP4 text tracks).
class SubtitleTrack {
  const SubtitleTrack({
    required this.group,
    required this.track,
    this.language,
    this.label,
    this.forced = false,
    this.selected = false,
    this.closedCaptions = false,
    this.mimeType,
  });

  final int group;
  final int track;
  final String? language;
  final String? label;
  final bool forced;
  final bool selected;

  /// Broadcast closed captions (CEA-608/708) on a live channel. Every .ts
  /// stream lists one; it stays empty on channels that don't carry them.
  final bool closedCaptions;
  final String? mimeType;
}

/// One complete embedded-caption snapshot, not a delta to append to history.
class SubtitleCueEvent {
  const SubtitleCueEvent(
      {required this.playerId,
      required this.text,
      this.closedCaptions = false,
      this.enabled = true,
      this.reset = false,
      this.mimeType});

  final int playerId;
  final String text;
  final bool closedCaptions;
  final bool enabled;
  final bool reset;
  final String? mimeType;

  factory SubtitleCueEvent.fromMap(Map data) {
    final cc = data['cc'] == true;
    var text = data['text'] as String? ?? '';
    final rows = (data['cues'] as List? ?? const []).whereType<Map>().toList();
    if (cc && rows.isNotEmpty) {
      // Media3 orders boxes by priority, not screen row. Only sort when all
      // rows share a known coordinate system; otherwise retain source order.
      final type = rows.first['lineType'];
      if (type is num &&
          rows.every((r) =>
              r['lineType'] == type &&
              r['line'] is num &&
              (r['line'] as num).isFinite)) {
        final indexed = rows.indexed.toList();
        double line(Map row) {
          final value = (row['line'] as num).toDouble();
          // Numbered negative rows count back from the bottom of the screen.
          return type == 1 && value < 0 ? 1000000 + value : value;
        }

        indexed.sort((a, b) {
          final order = line(a.$2).compareTo(line(b.$2));
          if (order != 0) return order;
          final x = (a.$2['position'] as num?)?.toDouble() ?? 0.5;
          final y = (b.$2['position'] as num?)?.toDouble() ?? 0.5;
          final horizontal = x.compareTo(y);
          return horizontal != 0 ? horizontal : a.$1.compareTo(b.$1);
        });
        rows
          ..clear()
          ..addAll(indexed.map((r) => r.$2));
      }
      text = rows
          .map((r) => r['text'] as String? ?? '')
          .where((s) => s.trim().isNotEmpty)
          .join('\n');
    }
    return SubtitleCueEvent(
        playerId: (data['playerId'] as num).toInt(),
        text: text,
        closedCaptions: cc,
        enabled: data['enabled'] != false,
        reset: data['reset'] == true,
        mimeType: data['mime'] as String?);
  }
}

/// Embedded subtitles on Android, through the vendored ExoPlayer plugin's
/// `SubtitleBridge` (third_party/video_player_android). The stock plugin has
/// no text-track API; providers' VOD files often carry 20-30 subtitle
/// languages (user report, 2026-10-18). Text tracks start off on every
/// player; [select] turns one on and [cues] then carries what to draw.
/// [playerId] is the controller's `textureId` (the plugin's player id).
class SubtitleTracks {
  static const _methods = MethodChannel('vespertv/subtitles');
  static const _events = EventChannel('vespertv/subtitles/cues');

  static final Stream<SubtitleCueEvent> cues = _events
      .receiveBroadcastStream()
      .map((e) => SubtitleCueEvent.fromMap(e as Map));

  /// The plugin's player id for [controller]. video_player_hdr marks
  /// `textureId` test-only, but it is exactly the id the native bridge keys
  /// players by (the platform-view player's id).
  static int playerIdOf(VideoPlayerHdrController controller) =>
      // ignore: invalid_use_of_visible_for_testing_member
      controller.textureId;

  static Future<List<SubtitleTrack>> list(int playerId) async {
    final raw = await _methods
            .invokeListMethod<Map>('getTextTracks', {'playerId': playerId}) ??
        const [];
    return [
      for (final m in raw)
        SubtitleTrack(
          group: (m['group'] as num).toInt(),
          track: (m['track'] as num).toInt(),
          language: m['language'] as String?,
          label: m['label'] as String?,
          forced: m['forced'] == true,
          selected: m['selected'] == true,
          closedCaptions: m['cc'] == true,
          mimeType: m['mime'] as String?,
        ),
    ];
  }

  /// The player showing a downloaded subtitle file (an add-on's, see
  /// AddonService) instead of an embedded track; SubtitleOverlay then draws
  /// the controller's caption.
  static final ValueNotifier<int?> externalFor = ValueNotifier(null);

  /// Shows [text] (SRT or WebVTT) on [controller], embedded tracks off.
  static Future<void> useExternal(
      VideoPlayerHdrController controller, String text) async {
    final id = playerIdOf(controller);
    await select(id, null);
    final file = text.trimLeft().startsWith('WEBVTT')
        ? WebVTTCaptionFile(text)
        : SubRipCaptionFile(text);
    await controller.setClosedCaptionFile(Future.value(file));
    externalFor.value = id;
  }

  /// Drops a downloaded file from [controller] (picking Off or an embedded
  /// track).
  static Future<void> clearExternal(VideoPlayerHdrController controller) async {
    final id = playerIdOf(controller);
    if (externalFor.value != id) return;
    externalFor.value = null;
    await controller.setClosedCaptionFile(null);
  }

  /// null = subtitles off.
  static Future<void> select(int playerId, SubtitleTrack? track) =>
      _methods.invokeMethod('selectTextTrack', {
        'playerId': playerId,
        'group': track?.group ?? -1,
        'track': track?.track ?? 0,
      });

  /// What a downloaded subtitle shows as in the picker, by player id.
  static final Map<int, String> externalLabel = {};

  // ------------------------------------------------- per-series memory

  /// Choices follow a series across episodes and a movie across resumes.
  /// Explicit Off overrides the viewer's preferred subtitle language.
  static String? seriesKeyOf(Channel channel) {
    final raw = channel.rawId;
    if (raw.startsWith('arc_ep_')) {
      final source = RegExp(r'^arc_ep_([^_]+)_').firstMatch(raw)?.group(1);
      return '${channel.playlistId}::$source::${channel.group}';
    }
    if (raw.startsWith('xt_ep_')) {
      return '${channel.playlistId}::${channel.group}';
    }
    return channel.isLive ? null : 'title:${channel.id}';
  }

  static Map<String, dynamic> _seriesChoices(StorageService storage) {
    try {
      final raw = storage.getSeriesSubtitlesJson();
      return raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  /// The remembered choice for [channel]'s series (`kind`/`lang`/`label`),
  /// or null — Windows' player reapplies it itself (desktop_subtitles.dart).
  static Map<String, dynamic>? seriesChoiceFor(
      StorageService storage, Channel channel) {
    final key = seriesKeyOf(channel);
    if (key == null) return null;
    final choice = _seriesChoices(storage)[key];
    if (choice is Map) return Map<String, dynamic>.from(choice);
    final language = storage.getPreferredSubtitleLanguage();
    return language == 'off'
        ? {'kind': 'off'}
        : {'kind': 'embedded', 'lang': language, 'preferred': true};
  }

  /// The viewer's preferred language from an add-on, for a title whose file
  /// has no track in it: the first match, or null (no add-on on, nothing
  /// found, or the stream brings its own subtitle file).
  static Future<OnlineSubtitle?> preferredOnline(
      StorageService storage, Channel channel, String? lang) async {
    final addons = AddonService(storage);
    if (lang == null ||
        channel.subtitleUrl != null ||
        (channel.subtitles.isEmpty &&
            (!AddonService.supports(channel) || !addons.anyEnabled))) {
      return null;
    }
    return (await addons.search(channel))
        .where((s) => sameTrackLanguage(s.lang, lang))
        .firstOrNull;
  }

  /// [kind] 'embedded' (a track of the file, matched by [lang] + [label])
  /// or 'online' (the first add-on match in [lang]); null = explicitly Off.
  static Future<void> rememberForSeries(
      StorageService storage, Channel? channel,
      {String? kind, String? lang, String? label, bool forced = false}) async {
    final key = channel == null ? null : seriesKeyOf(channel);
    if (key == null) return;
    final all = _seriesChoices(storage);
    all[key] = {
      'kind': kind ?? 'off',
      'lang': lang,
      'label': label,
      'forced': forced
    };
    await storage.setSeriesSubtitlesJson(jsonEncode(all));
  }

  /// Drops [channel]'s remembered choice: the preferred language applies
  /// again (the player's Preferred subtitle language row).
  static Future<void> forgetForSeries(
      StorageService storage, Channel? channel) async {
    final key = channel == null ? null : seriesKeyOf(channel);
    if (key == null) return;
    final all = _seriesChoices(storage);
    if (all.remove(key) == null) return;
    await storage.setSeriesSubtitlesJson(jsonEncode(all));
  }

  /// Reapplies the series' remembered subtitles on a new episode's player.
  /// Gives up quietly when the episode has no matching track/subtitle;
  /// false then.
  static Future<bool> applyForSeries(StorageService storage, Channel channel,
      VideoPlayerHdrController controller,
      {bool Function()? isCurrent}) async {
    final choice = seriesChoiceFor(storage, channel);
    if (choice == null) return false;
    final viewer = storage.getActiveViewerId();
    final initial = jsonEncode(choice);
    bool current() =>
        (isCurrent?.call() ?? true) &&
        storage.getActiveViewerId() == viewer &&
        jsonEncode(seriesChoiceFor(storage, channel)) == initial;
    if (!current()) return false;
    if (choice['kind'] == 'off') {
      await clearExternal(controller);
      if (current()) await select(playerIdOf(controller), null);
      return true;
    }
    final lang = choice['lang'] as String?;
    final id = playerIdOf(controller);
    if (choice['kind'] == 'online') {
      final addons = AddonService(storage);
      if (lang == null || !addons.anyEnabled) return false;
      final match = (await addons.search(channel))
          .where((s) => s.lang == lang)
          .firstOrNull;
      if (match == null) return false;
      final text = await AddonService.download(match);
      if (!current()) return false;
      await useExternal(controller, text);
      externalLabel[id] =
          languageName(lang).isEmpty ? lang : languageName(lang);
      return true;
    }
    // Embedded: the track list exists once the file's header is read.
    for (var i = 0; i < 6; i++) {
      List<SubtitleTrack> tracks;
      try {
        tracks = await list(id);
      } catch (_) {
        return false; // player gone
      }
      if (!current()) return false;
      if (tracks.isNotEmpty) {
        final label = choice['label'] as String?;
        final sameLang = tracks.where((t) =>
            (sameTrackLanguage(t.language, lang) ||
                ((lang == null || lang.isEmpty || lang == 'und') &&
                    label != null &&
                    label.isNotEmpty &&
                    t.label == label)) &&
            t.forced == (choice['forced'] == true));
        final pick = sameLang.where((t) => t.label == label).firstOrNull ??
            sameLang.firstOrNull;
        if (pick != null) {
          await select(id, pick);
          return true;
        }
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    // The preferred language isn't in the file: an add-on's, if any.
    if (choice['preferred'] != true || !current()) return false;
    final match = await preferredOnline(storage, channel, lang);
    if (match == null || !current()) return false;
    final text = await AddonService.download(match);
    if (!current()) return false;
    await useExternal(controller, text);
    externalLabel[id] = languageName(match.lang).isEmpty
        ? match.lang
        : languageName(match.lang);
    return true;
  }
}
