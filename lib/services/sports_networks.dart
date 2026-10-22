/// Sports TV networks, for Sports Trak › Channels: which of a playlist's
/// channels belong to one network (TSN 1–5 and every quality copy = one
/// "TSN" card), which row it sits in, and which sports it carries.
///
/// Owner, 2026-10-22: the first Channels page was a plain list, and the
/// hockey filter missed TSN, ESPN, Sportsnet, TVA Sports and RDS — a sport
/// was only known when the channel's own name said "NHL"/"HOCKEY". A
/// multi-sport network now counts for every sport ([SportsNetwork.sports]
/// null), a league network only for its own.
library;

import '../models/channel.dart';

enum SportsNetworkKind { league, sports, regional }

class SportsNetwork {
  const SportsNetwork(this.id, this.name, this.kind, this.pattern,
      {this.sports});

  final String id;
  final String name;
  final SportsNetworkKind kind;

  /// Matched against the upper-cased channel name (region tag included).
  final String pattern;

  /// The sports it shows; null = all of them (a general sports network).
  final Set<String>? sports;

  RegExp get regex => _regexes[id] ??= RegExp(pattern);
  static final _regexes = <String, RegExp>{};
}

/// Every sport key [SportsChannelLibrary] tags with.
const kChannelSports = [
  'hockey',
  'basketball',
  'football',
  'soccer',
  'baseball',
  'tennis',
  'golf',
  'racing',
];

/// Most specific first: the first match wins (US "SportsNet LA" before
/// Canada's Sportsnet, regional NBC Sports before NBC Sports, ESPN+ before
/// ESPN).
const kSportsNetworks = <SportsNetwork>[
  // ------------------------------------------------------- league networks
  SportsNetwork('nhl_network', 'NHL Network', SportsNetworkKind.league,
      r'\bNHL ?NETWORK\b',
      sports: {'hockey'}),
  SportsNetwork('nba_tv', 'NBA TV', SportsNetworkKind.league, r'\bNBA ?TV\b',
      sports: {'basketball'}),
  SportsNetwork('nfl_network', 'NFL Network', SportsNetworkKind.league,
      r'\bNFL ?(NETWORK|REDZONE|RED ZONE)\b',
      sports: {'football'}),
  SportsNetwork('mlb_network', 'MLB Network', SportsNetworkKind.league,
      r'\bMLB ?(NETWORK|STRIKE ?ZONE)\b',
      sports: {'baseball'}),
  SportsNetwork('mls', 'MLS', SportsNetworkKind.league, r'\bMLS\b',
      sports: {'soccer'}),
  SportsNetwork(
      'golf', 'Golf Channel', SportsNetworkKind.league, r'\bGOLF( CHANNEL)?\b',
      sports: {'golf'}),
  SportsNetwork('tennis', 'Tennis Channel', SportsNetworkKind.league,
      r'\bTENNIS( CHANNEL)?\b',
      sports: {'tennis'}),
  SportsNetwork('big_ten', 'Big Ten Network', SportsNetworkKind.league,
      r'\b(BIG ?TEN|BTN)\b'),
  SportsNetwork('sec_network', 'SEC Network', SportsNetworkKind.league,
      r'\bSEC ?NETWORK\b'),
  SportsNetwork('acc_network', 'ACC Network', SportsNetworkKind.league,
      r'\bACC ?NETWORK\b'),
  // ---------------------------------------------------- regional networks
  SportsNetwork('fanduel', 'FanDuel Sports Network', SportsNetworkKind.regional,
      r'\b(FANDUEL SPORTS|BALLY SPORTS|FDSN)\b'),
  SportsNetwork(
      'nbc_regional',
      'NBC Sports regional',
      SportsNetworkKind.regional,
      r'\bNBC ?SPORTS ?(BAY AREA|CALIFORNIA|CHICAGO|BOSTON|PHILADELPHIA|PHILLY|WASHINGTON|NORTHWEST)\b'),
  SportsNetwork('sportsnet_us', 'SportsNet (US)', SportsNetworkKind.regional,
      r'\b(SPORTSNET (LA|PITTSBURGH|NEW YORK)|SPECTRUM SPORTS ?NET|SNY)\b'),
  SportsNetwork('msg', 'MSG', SportsNetworkKind.regional, r'\bMSG\b'),
  SportsNetwork('nesn', 'NESN', SportsNetworkKind.regional, r'\bNESN\b'),
  SportsNetwork(
      'yes', 'YES Network', SportsNetworkKind.regional, r'\bYES ?NETWORK\b'),
  SportsNetwork(
      'marquee', 'Marquee Sports', SportsNetworkKind.regional, r'\bMARQUEE\b'),
  SportsNetwork('monumental', 'Monumental Sports', SportsNetworkKind.regional,
      r'\bMONUMENTAL\b'),
  SportsNetwork(
      'altitude', 'Altitude', SportsNetworkKind.regional, r'\bALTITUDE\b'),
  SportsNetwork(
      'root', 'Root Sports', SportsNetworkKind.regional, r'\bROOT ?SPORTS\b'),
  SportsNetwork('chsn', 'Chicago Sports Network', SportsNetworkKind.regional,
      r'\b(CHICAGO SPORTS NETWORK|CHSN)\b'),
  SportsNetwork('space_city', 'Space City Home Network',
      SportsNetworkKind.regional, r'\bSPACE CITY\b'),
  // -------------------------------------------------------- sports networks
  SportsNetwork(
      'espn_plus', 'ESPN+', SportsNetworkKind.sports, r'\bESPN ?(\+|PLUS)'),
  SportsNetwork('espn', 'ESPN', SportsNetworkKind.sports, r'\bESPN'),
  SportsNetwork('tsn', 'TSN', SportsNetworkKind.sports, r'\bTSN'),
  SportsNetwork('sportsnet', 'Sportsnet', SportsNetworkKind.sports,
      r'\b(SPORTSNET|SN ?(ONE|1|360|WORLD|EAST|WEST|ONTARIO|PACIFIC))\b'),
  SportsNetwork('rds', 'RDS', SportsNetworkKind.sports, r'\bRDS'),
  SportsNetwork('tva_sports', 'TVA Sports', SportsNetworkKind.sports,
      r'\bTVA ?SPORTS?\b'),
  SportsNetwork('fox_sports', 'Fox Sports', SportsNetworkKind.sports,
      r'\b(FOX ?SPORTS?|FS ?1|FS ?2)\b'),
  SportsNetwork('cbs_sports', 'CBS Sports Network', SportsNetworkKind.sports,
      r'\b(CBS ?SPORTS|CBSSN)\b'),
  SportsNetwork(
      'nbc_sports', 'NBC Sports', SportsNetworkKind.sports, r'\bNBC ?SPORTS\b'),
  SportsNetwork('tnt_sports', 'TNT Sports', SportsNetworkKind.sports,
      r'\b(TNT ?SPORTS?|BT ?SPORT)\b'),
  SportsNetwork('sky_sports', 'Sky Sports', SportsNetworkKind.sports,
      r'\bSKY ?SPORTS?\b'),
  SportsNetwork('bein', 'beIN Sports', SportsNetworkKind.sports, r'\bBEIN\b'),
  SportsNetwork('dazn', 'DAZN', SportsNetworkKind.sports, r'\bDAZN\b'),
  SportsNetwork(
      'eurosport', 'Eurosport', SportsNetworkKind.sports, r'\bEUROSPORT\b'),
  SportsNetwork('supersport', 'SuperSport', SportsNetworkKind.sports,
      r'\bSUPER ?SPORT\b'),
  SportsNetwork('nova_sports', 'Nova Sports', SportsNetworkKind.sports,
      r'\bNOVA ?SPORTS?\b'),
  SportsNetwork('cosmote', 'Cosmote Sport', SportsNetworkKind.sports,
      r'\bCOSMOTE ?SPORT\b'),
  SportsNetwork(
      'digi_sport', 'Digi Sport', SportsNetworkKind.sports, r'\bDIGI ?SPORT\b'),
  SportsNetwork('prima_sport', 'Prima Sport', SportsNetworkKind.sports,
      r'\bPRIMA ?SPORT\b'),
  SportsNetwork('arena_sport', 'Arena Sport', SportsNetworkKind.sports,
      r'\bARENA ?SPORT\b'),
  SportsNetwork(
      'sport_klub', 'Sport Klub', SportsNetworkKind.sports, r'\bSPORT ?KLUB\b'),
  SportsNetwork('canal_sport', 'Canal+ Sport', SportsNetworkKind.sports,
      r'\bCANAL ?\+ ?SPORT'),
  SportsNetwork(
      'viaplay', 'Viaplay Sports', SportsNetworkKind.sports, r'\bVIAPLAY'),
  SportsNetwork('willow', 'Willow', SportsNetworkKind.sports, r'\bWILLOW\b'),
];

/// The network [channel] belongs to, or null.
SportsNetwork? sportsNetworkOf(Channel channel) {
  final name = channel.name.toUpperCase();
  for (final n in kSportsNetworks) {
    if (n.regex.hasMatch(name)) return n;
  }
  return null;
}

/// Order inside a network card: numbered feeds in order (TSN 1 before
/// TSN 2), HD/FHD before 4K before SD at the same number — the first is
/// what OK previews.
int compareNetworkChannels(Channel a, Channel b) {
  int quality(String name) {
    final n = name.toUpperCase();
    if (RegExp(r'\b(FHD|1080)').hasMatch(n)) return 0;
    if (RegExp(r'\bHD\b').hasMatch(n)) return 1;
    if (RegExp(r'\b(4K|UHD|2160)').hasMatch(n)) return 2;
    if (RegExp(r'\bSD\b').hasMatch(n)) return 4;
    return 3;
  }

  String base(String name) => name
      .toUpperCase()
      .replaceAll(RegExp(r'\b(FHD|UHD|HD|SD|4K|1080P?|2160P?|HEVC)\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  int number(String name) =>
      int.tryParse(RegExp(r'(\d+)').firstMatch(base(name))?.group(1) ?? '') ??
      0;
  final byNumber = number(a.name).compareTo(number(b.name));
  if (byNumber != 0) return byNumber;
  final byBase = base(a.name).compareTo(base(b.name));
  if (byBase != 0) return byBase;
  return quality(a.name).compareTo(quality(b.name));
}
