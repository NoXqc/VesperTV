import 'dart:convert';

import '../models/channel.dart';
import 'sports_networks.dart';
import 'storage_service.dart';

/// Codes follow the existing Sports Networks country tags (UK, not GB).
/// Brand names shared across markets (Sky, DAZN, beIN, Eurosport...) do not
/// establish a country by themselves.
class SportsChannelCountries {
  static const names = {
    'CA': 'Canada',
    'US': 'United States',
    'UK': 'United Kingdom',
    'FR': 'France',
    'ES': 'Spain',
    'IT': 'Italy',
    'DE': 'Germany',
    'PT': 'Portugal',
    'GR': 'Greece',
    'IE': 'Ireland',
    'NL': 'Netherlands',
    'BE': 'Belgium',
    'CY': 'Cyprus',
    'EE': 'Estonia',
    'LV': 'Latvia',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'MT': 'Malta',
    'IS': 'Iceland',
    'CH': 'Switzerland',
    'AT': 'Austria',
    'DK': 'Denmark',
    'SE': 'Sweden',
    'NO': 'Norway',
    'FI': 'Finland',
    'PL': 'Poland',
    'CZ': 'Czechia',
    'SK': 'Slovakia',
    'HU': 'Hungary',
    'RO': 'Romania',
    'BG': 'Bulgaria',
    'HR': 'Croatia',
    'RS': 'Serbia',
    'SI': 'Slovenia',
    'BA': 'Bosnia and Herzegovina',
    'AL': 'Albania',
    'TR': 'Türkiye',
    'UA': 'Ukraine',
    'AU': 'Australia',
    'NZ': 'New Zealand',
    'BR': 'Brazil',
    'MX': 'Mexico',
    'AR': 'Argentina',
  };
  static const _aliases = {
    'USA': 'US',
    'GB': 'UK',
    'GBR': 'UK',
    'CAN': 'CA',
    'CAFR': 'CA',
    'CA FR': 'CA',
    'QC': 'CA',
    'QUEBEC': 'CA',
  };

  static String? normalize(String value) {
    final upper = value.trim().toUpperCase();
    final code = _aliases[upper] ?? upper;
    if (names.containsKey(code)) return code;
    for (final entry in names.entries) {
      if (entry.value.toUpperCase() == upper) return entry.key;
    }
    return null;
  }

  static String? _prefix(String value) {
    final text =
        value.trim().toUpperCase().replaceFirst(RegExp(r'^[^A-Z0-9]+'), '');
    // Prefix tags only: "beIN" and "ITV" must not become BE/IT.
    final match =
        RegExp(r'^[\[(]?([A-Z]{2,3}|CAFR|CA FR)[\])]?(?=\s|[:|_\-]|$)')
            .firstMatch(text);
    final code = match == null ? null : normalize(match.group(1)!);
    if (code != null) return code;
    for (final entry in names.entries) {
      final country = entry.value.toUpperCase();
      if (text == country ||
          text.startsWith('$country ') ||
          text.startsWith('$country:') ||
          text.startsWith('$country|')) {
        return entry.key;
      }
    }
    return null;
  }

  static String? infer(Channel channel) {
    final explicit = _prefix(channel.name);
    if (explicit != null) return explicit;
    final group = _prefix(channel.group);
    if (group != null) return group;
    final network = sportsNetworkOf(channel)?.id;
    if (const {'tsn', 'tsn_plus', 'sportsnet', 'rds', 'tva_sports'}
        .contains(network)) {
      return 'CA';
    }
    if (network == 'sportsnet_us') return 'US';
    return null;
  }
}

/// Immutable, once-per-match snapshot. No candidate search or EPG changes.
class SportsCountryPreferences {
  SportsCountryPreferences(this.selected, this.overrides);
  final Set<String> selected;
  final Map<String, Set<String>> overrides;

  factory SportsCountryPreferences.load(StorageService storage) {
    final selected = storage
        .getSportsPreferredCountries()
        .map(SportsChannelCountries.normalize)
        .whereType<String>()
        .toSet();
    final overrides = <String, Set<String>>{};
    if (selected.isNotEmpty) {
      try {
        final value = jsonDecode(storage.getSportsChannelLists() ?? '{}');
        if (value is Map && value['tags'] is Map) {
          for (final entry in (value['tags'] as Map).entries) {
            if (entry.value is! Map) continue;
            final countries = (entry.value as Map)['Country'];
            if (countries is! List) continue;
            overrides[entry.key.toString()] = countries
                .whereType<String>()
                .map(SportsChannelCountries.normalize)
                .whereType<String>()
                .toSet();
          }
        }
      } catch (_) {
        // Bad optional tag data cannot prevent matching or remove channels.
      }
    }
    return SportsCountryPreferences(selected, overrides);
  }

  bool prefers(Channel channel) {
    if (overrides[channel.id] case final countries?) {
      return countries.any(selected.contains);
    }
    return selected.contains(SportsChannelCountries.infer(channel));
  }
}
