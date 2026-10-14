import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'fr.dart';

/// App-wide UI language. English strings in the code are the keys
/// (`tr('Settings')`); [kFr] maps them to French. A missing entry falls back
/// to the English text, so a forgotten string shows in English, never blank.
///
/// Deliberately not Flutter's gen-l10n: many strings live in services and
/// dialogs without a BuildContext, and English-as-key keeps the code readable.
/// The language is applied once at startup (before `runApp`) and again from
/// Settings > General, which remounts the UI so every screen rebuilds.
class L10n {
  L10n._();

  /// The setting: 'auto' (follow the device), 'en' or 'fr'.
  static String setting = 'auto';

  /// The resolved language actually in use: 'en' or 'fr'.
  static String code = 'en';

  static bool get isFrench => code == 'fr';

  static Locale get locale => Locale(code);

  static const supportedLocales = [Locale('en'), Locale('fr')];

  static Future<void> apply(String newSetting) async {
    setting = newSetting;
    code = switch (newSetting) {
      'en' => 'en',
      'fr' => 'fr',
      _ =>
        PlatformDispatcher.instance.locale.languageCode == 'fr' ? 'fr' : 'en',
    };
    await initializeDateFormatting(code);
    Intl.defaultLocale = code;
  }
}

/// Translate [en] into the current language. `{name}` placeholders are filled
/// from [args], e.g. `tr('Version {version}', {'version': v})`.
String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = L10n.code == 'fr' ? (kFr[en] ?? en) : en;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// ESPN's English game statuses and standing lines ("Final/OT", "End of 2nd",
/// "Top 5th", "7th in Pacific Division") in the current language. Pattern
/// based, so an unknown status passes through untouched.
String trSports(String s) {
  if (L10n.code != 'fr' || s.isEmpty) return s;
  const words = {
    'Final': 'Fin',
    'Halftime': 'Mi-temps',
    'Half': 'demie',
    'Delayed': 'Retardé',
    'Rain Delay': 'Retard (pluie)',
    'Postponed': 'Reporté',
    'Canceled': 'Annulé',
    'Cancelled': 'Annulé',
    'Suspended': 'Suspendu',
    'Forfeit': 'Forfait',
    'End of': 'Fin',
    'End': 'Fin',
    'Top': 'Haut',
    'Bot': 'Bas',
    'Bottom': 'Bas',
    'Mid': 'Mil.',
    'Middle': 'Mil.',
    'OT': 'Prol.',
    'SO': 'TB',
    'FT': 'Fin',
    'HT': 'Mi-temps',
    'AET': 'Prol.',
    'Pens': 'TAB',
    'Intermission': 'Entracte',
    'Quarter': 'quart',
    'Period': 'période',
    'Inning': 'manche',
  };
  // "7th in Pacific Division" -> "7e – Pacific Division" (ties: "T-3rd in").
  var out = s.replaceFirstMapped(RegExp(r'^(T-)?(\d+)(st|nd|rd|th) in (the )?'),
      (m) => '${m[1] ?? ''}${m[2]}th – ');
  // "2OT" / "Final/2OT" -> "2e prol.", "2SO" -> "2e TB".
  out = out.replaceAllMapped(RegExp(r'\b(\d)(OT|SO)\b'),
      (m) => '${m[1]}e ${m[2] == 'OT' ? 'prol.' : 'TB'}');
  out = out.replaceAllMapped(RegExp(r'\b(\d+)(st|nd|rd|th)\b'),
      (m) => m[1] == '1' ? '1re' : '${m[1]}e');
  out = out.replaceAllMapped(
      RegExp(r'\b(Rain Delay|End of|[A-Z][a-z]+|OT|SO|FT|HT|AET)\b'),
      (m) => words[m[0]] ?? m[0]!);
  return out;
}

/// Picks the singular or plural English form by [n] (French treats 0 as
/// singular), then translates it. `{n}` is filled with [n].
String trPlural(int n, String one, String other,
    [Map<String, Object?> args = const {}]) {
  final singular = L10n.code == 'fr' ? n.abs() < 2 : n == 1;
  return tr(singular ? one : other, {'n': n, ...args});
}
