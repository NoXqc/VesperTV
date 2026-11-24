import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/multiview_sports.dart';
import 'package:nox_iptv/services/storage_service.dart';

/// Settings > Sports Trak > Sports Trak off (issue #15, owner 2026-11-24):
/// every sports feature off on this device, while hiding only the tab keeps
/// the games on Home and the rest.
void main() {
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
  });

  test('hiding only the tab keeps the leagues (Home games row, launcher)', () {
    final before = MultiviewSports.leagues(storage);
    expect(before, isNotEmpty, reason: 'default leagues');
    prefs.setHideSportsTrak(true);
    expect(prefs.sportsTabHidden, isTrue);
    expect(prefs.sportsOff, isFalse);
    expect(MultiviewSports.leagues(storage), hasLength(before.length));
  });

  test('Sports Trak off: no tab, no Sports Mode, no leagues, no reminders',
      () async {
    await prefs.setSportsMode(true);
    expect(prefs.sportsMode, isTrue);

    prefs.setSportsOff(true);
    expect(prefs.sportsTabHidden, isTrue);
    expect(prefs.sportsMode, isFalse);
    expect(prefs.hideSportsTrak, isFalse, reason: 'the tab switch is kept');
    expect(MultiviewSports.leagues(storage), isEmpty);
    expect(GameReminders(storage).poll(), isEmpty);

    // The setting survives a restart.
    final again = AppPreferences(storage);
    await again.init();
    expect(again.sportsOff, isTrue);
  });

  test('turning Sports Mode on turns Sports Trak back on', () async {
    prefs.setSportsOff(true);
    await prefs.setSportsMode(true);
    expect(prefs.sportsOff, isFalse);
    expect(prefs.sportsMode, isTrue);
    expect(MultiviewSports.leagues(storage), isNotEmpty);
  });
}
