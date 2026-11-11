/// Countries (and other repeated prefixes) at the start of a playlist's
/// group names, for Group Management's bulk "by country" switch (owner,
/// 2026-11-11). Providers write the same country many ways — `US: News`,
/// `US| News`, `|US| News`, `[US] News`, `US - News`, `AM | US - News`,
/// `USA ▎ News`, `🇺🇸 News`, `US News` — and they all land on one entry.
/// A short prefix that isn't a country (`VIP | …`, `NBA: …`) is listed
/// too when two or more groups share it.
class GroupRegion {
  GroupRegion._(this.key, {required this.country});

  /// `US`, `UK`, `LATAM`, `VIP`… or '' for the groups with no prefix.
  final String key;

  /// A country, language or region code (not just any prefix).
  final bool country;

  /// The groups it covers, in playlist order.
  final List<String> titles = [];

  /// How the provider wrote it (`US:`, `|US|`, `AM | US -`), first seen
  /// first.
  final List<String> variants = [];

  /// The flag emoji of a country with an unambiguous ISO code.
  String? get flag {
    if (!country) return null;
    final iso = GroupRegions._flagIso[key] ??
        (key.length == 2 && !GroupRegions._noFlag.contains(key) ? key : null);
    if (iso == null) return null;
    return String.fromCharCodes([for (final c in iso.codeUnits) 0x1F1A5 + c]);
  }
}

class GroupRegions {
  /// [titles]' countries (most groups first), then the other shared
  /// prefixes, then one entry with key '' for every group without one.
  static List<GroupRegion> detect(Iterable<String> titles) {
    final byKey = <String, GroupRegion>{};
    final all = titles.toList();
    final none = <String>{};
    for (final title in all) {
      final found = keyOf(title);
      if (found == null) {
        none.add(title);
        continue;
      }
      final region = byKey[found.key] ??=
          GroupRegion._(found.key, country: found.country);
      region.titles.add(title);
      if (!region.variants.contains(found.variant)) {
        region.variants.add(found.variant);
      }
    }
    // A plain prefix on a single group is part of its name.
    for (final region in byKey.values.toList()) {
      if (!region.country && region.titles.length < 2) {
        byKey.remove(region.key);
        none.addAll(region.titles);
      }
    }
    int byCount(GroupRegion a, GroupRegion b) {
      final n = b.titles.length.compareTo(a.titles.length);
      return n != 0 ? n : a.key.compareTo(b.key);
    }

    return [
      ...byKey.values.where((r) => r.country).toList()..sort(byCount),
      ...byKey.values.where((r) => !r.country).toList()..sort(byCount),
      if (none.isNotEmpty)
        GroupRegion._('', country: false)
          ..titles.addAll(all.where(none.contains)),
    ];
  }

  /// The country or prefix [title] starts with, or null.
  static ({String key, bool country, String variant})? keyOf(String title) {
    final flag = _flagPrefix(title);
    if (flag != null) return flag;
    final segments = _segments(title);
    if (segments.isEmpty) return _spaced(title);
    for (var i = 0; i < segments.length; i++) {
      final norm = _norm(segments[i].text);
      final lead = _leadMarkers.contains(norm);
      // `AM | US`, `VIP | UK`: the marker in front of a country.
      if (lead &&
          i + 1 < segments.length &&
          _countryKey(_norm(segments[i + 1].text)) != null) {
        continue;
      }
      final country = lead ? null : _countryKey(norm);
      if (country != null) {
        return (
          key: country,
          country: true,
          variant: title.substring(0, segments[i].end).trim(),
        );
      }
      // `US NEWS | CNN` (a word after the code), `4K | US Sports` (the
      // code after the last marker).
      final spaced = lead
          ? (i == segments.length - 1
              ? _spaced(title.substring(segments[i].end))
              : null)
          : (i == 0 ? _spaced(segments[i].text) : null);
      if (spaced != null) {
        final head = lead ? title.substring(0, segments[i].end).trim() : '';
        return (
          key: spaced.key,
          country: true,
          variant: head.isEmpty ? spaced.variant : '$head ${spaced.variant}',
        );
      }
      break;
    }
    final first = _norm(segments.first.text);
    if (first.isEmpty ||
        first.length > 8 ||
        !first.contains(RegExp('[A-Z]'))) {
      return null;
    }
    return (
      key: first,
      country: false,
      variant: title.substring(0, segments.first.end).trim(),
    );
  }

  // --- reading the start of a title ---------------------------------------

  static const _separators = '|:]})▎┃│⎪•»★☆✦◆■▶►';
  static const _decoration = ' \t|[({«<-_~*#★☆✦◆■▶►•▎┃│⎪';

  /// Up to three leading pieces of [title] that each end in a separator,
  /// with the index just past that separator.
  static List<({String text, int end})> _segments(String title) {
    final out = <({String text, int end})>[];
    final n = title.length;
    var i = 0;
    while (out.length < 3) {
      while (i < n && _decoration.contains(title[i])) {
        i++;
      }
      if (i >= n) break;
      int? cut;
      var j = i;
      for (; j < n && j - i <= 14; j++) {
        final c = title[j];
        if (_separators.contains(c)) {
          cut = j;
          break;
        }
        // `US - News` / `US -News`: a dash with a space beside it (never
        // inside a word: `Al-Jazeera`, `EX-YU`).
        if (c == '-' &&
            ((j > i && title[j - 1] == ' ') ||
                (j + 1 < n && title[j + 1] == ' '))) {
          cut = j;
          break;
        }
      }
      if (cut == null) break;
      final text = title.substring(i, cut).trim();
      if (text.isEmpty || text.length > 12) break;
      out.add((text: text, end: cut + 1));
      i = cut + 1;
    }
    return out;
  }

  /// `US NEWS`: a capital country code and a space, no separator.
  static ({String key, bool country, String variant})? _spaced(String title) {
    final m = RegExp(r'^\s*([A-Z]{2,3})\s+\S').firstMatch(title);
    if (m == null) return null;
    final word = m.group(1)!;
    if (_spacedStop.contains(word)) return null;
    final country = _countryKey(word);
    if (country == null) return null;
    return (key: country, country: true, variant: word);
  }

  /// `🇺🇸 USA`: two regional indicator letters.
  static ({String key, bool country, String variant})? _flagPrefix(
      String title) {
    final runes = title.trimLeft().runes.take(2).toList();
    if (runes.length < 2 ||
        !runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF)) {
      return null;
    }
    final iso = String.fromCharCodes([for (final r in runes) r - 0x1F1A5]);
    final key = iso == 'GB' ? 'UK' : iso;
    return (key: key, country: true, variant: String.fromCharCodes(runes));
  }

  static String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9+]'), '');

  static String? _countryKey(String norm) {
    final alias = _aliases[norm];
    if (alias != null) return alias;
    if (_extra.contains(norm)) return norm;
    if (norm.length == 2 &&
        _iso2.contains(norm) &&
        !_notCountries.contains(norm) &&
        !_continentLike.contains(norm)) {
      return norm;
    }
    return null;
  }

  // --- tables ---------------------------------------------------------------

  static final Set<String> _iso2 = ('AD AE AF AG AI AL AM AO AQ AR AS AT AU '
          'AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW '
          'BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE '
          'DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE '
          'GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID '
          'IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW '
          'KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML '
          'MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO '
          'NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO '
          'RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX '
          'SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US '
          'UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW')
      .split(' ')
      .toSet();

  /// ISO codes IPTV names use for something else (TV, SD quality, FM radio).
  static const _notCountries = {'TV', 'SD', 'FM'};

  /// ISO codes that providers also use for a continent (`AM` = Americas,
  /// `AF` = Africa, `ME` = Middle East…): a country only as an alias.
  static const _continentLike = {'AM', 'AF', 'AS', 'NA', 'SA', 'ME'};

  /// Markers in front of the country (`AM | US`, `VIP | UK`, `4K | FR`).
  static const _leadMarkers = {
    ..._continentLike,
    'EU', 'EUR', 'EUROPE', 'OC', 'OCE', 'OCEANIA', 'AMER', 'AMERICA',
    'AMERICAS', 'AFR', 'AFRICA', 'ASIA', 'MENA', 'WORLD', 'INT', 'INTL',
    'VIP', 'PREMIUM', 'PRIME', 'PLUS', 'RAW', 'PPV', '4K', 'UHD', 'FHD',
    'HD', 'HEVC', 'H265', 'SD', 'VOD',
  };

  /// Country-like keys that aren't ISO codes.
  static const _extra = {'UK', 'ENG', 'EN', 'LATAM', 'EXYU', 'KSA'};

  /// Codes that aren't a single country's flag (`AR` is Arabic as often as
  /// Argentina).
  static const _noFlag = {'AR', 'EN', 'EU'};
  static const _flagIso = {'UK': 'GB', 'KSA': 'SA'};

  /// 3-letter codes, names and spellings -> one key.
  static const _aliases = {
    'GB': 'UK', 'GBR': 'UK', 'USA': 'US', 'CAN': 'CA', 'MEX': 'MX',
    'BRA': 'BR', 'FRA': 'FR', 'GER': 'DE', 'DEU': 'DE', 'ESP': 'ES',
    'ITA': 'IT', 'POR': 'PT', 'PRT': 'PT', 'NED': 'NL', 'NLD': 'NL',
    'BEL': 'BE', 'SUI': 'CH', 'CHE': 'CH', 'AUT': 'AT', 'SWE': 'SE',
    'NOR': 'NO', 'DEN': 'DK', 'DNK': 'DK', 'FIN': 'FI', 'POL': 'PL',
    'TUR': 'TR', 'GRE': 'GR', 'GRC': 'GR', 'IRL': 'IE', 'IND': 'IN',
    'PAK': 'PK', 'AUS': 'AU', 'NZL': 'NZ', 'ROU': 'RO', 'ROM': 'RO',
    'RUS': 'RU', 'UKR': 'UA', 'ALB': 'AL', 'HRV': 'HR', 'CRO': 'HR',
    'SRB': 'RS', 'BIH': 'BA', 'SVN': 'SI', 'SLO': 'SI', 'HUN': 'HU',
    'CZE': 'CZ', 'SVK': 'SK', 'BGR': 'BG', 'BUL': 'BG', 'CYP': 'CY',
    'LUX': 'LU', 'ISL': 'IS', 'ISR': 'IL', 'EGY': 'EG', 'MAR': 'MA',
    'TUN': 'TN', 'DZA': 'DZ', 'ALG': 'DZ', 'NGA': 'NG', 'ZAF': 'ZA',
    'RSA': 'ZA', 'COL': 'CO', 'CHL': 'CL', 'PER': 'PE', 'VEN': 'VE',
    'CUB': 'CU', 'DOM': 'DO', 'PRI': 'PR', 'PHI': 'PH', 'PHL': 'PH',
    'JPN': 'JP', 'KOR': 'KR', 'CHN': 'CN', 'VNM': 'VN', 'THA': 'TH',
    'IDN': 'ID', 'MYS': 'MY', 'SGP': 'SG', 'HKG': 'HK', 'TWN': 'TW',
    'IRN': 'IR', 'IRQ': 'IQ', 'SYR': 'SY', 'LBN': 'LB', 'JOR': 'JO',
    'KWT': 'KW', 'QAT': 'QA', 'UAE': 'AE', 'ARM': 'AM', 'AFG': 'AF',
    'CANADA': 'CA', 'FRANCE': 'FR', 'GERMANY': 'DE', 'DEUTSCHLAND': 'DE',
    'ITALY': 'IT', 'ITALIA': 'IT', 'SPAIN': 'ES', 'ESPANA': 'ES',
    'PORTUGAL': 'PT', 'BRAZIL': 'BR', 'BRASIL': 'BR', 'MEXICO': 'MX',
    'INDIA': 'IN', 'TURKEY': 'TR', 'TURKIYE': 'TR', 'GREECE': 'GR',
    'POLAND': 'PL', 'IRELAND': 'IE', 'ENGLAND': 'UK', 'ENGLISH': 'EN',
    'ARABIC': 'AR', 'ARAB': 'AR', 'LATINO': 'LATAM', 'LATIN': 'LATAM',
    'LAT': 'LATAM', 'NETHERLANDS': 'NL', 'BELGIUM': 'BE', 'SWEDEN': 'SE',
  };

  /// Capital words that start group names without being a country.
  static const _spacedStop = {
    'IN', 'IS', 'NO', 'MY', 'BE', 'DO', 'GO', 'SO', 'TO', 'AT', 'OR',
    'ON', 'UP', 'BY', 'ID', 'PM', 'TV', 'HD', 'SD', 'FM', 'ALL', 'THE',
    'NEW', 'OLD', 'TOP', 'MAX', 'ONE', 'BIG',
  };
}
