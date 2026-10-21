import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner request (2026-10-20): Transfer (and Backup) carry everything on
/// the Sports Trak tab — leagues shown/added and their order, favourite
/// league, My Teams, game -> channel picks, spoiler mode — for every
/// viewer, not only Main.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> sender() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyPlaylists: '[{"id":"a"}]',
    });
    final s = StorageService();
    await s.init();
    // Main, through the same setters the Sports screens use.
    await s.setSportsLeagues(['nba', 'eng.1', 'nhl']);
    await s.setSportsAddedLeagues(['gre.1']);
    await s.setSportsFavoriteLeague('eng.1');
    await s.setSportsFollowedTeams(['soccer/eng.1/359', 'nba/2']);
    await s.setSportsChannelPicks('{"401":"a::espn"}');
    await s.setSportsHideScores(true);
    // A second viewer has a setup of their own.
    await s.setActiveViewerId('kid');
    await s.setSportsLeagues(['nhl']);
    await s.setSportsFavoriteLeague('nhl');
    await s.setSportsFollowedTeams(['hockey/nhl/10']);
    await s.setActiveViewerId(AppConstants.mainViewerId);
    return s;
  }

  Future<StorageService> receiver() async {
    // The receiving device had its own, different Sports setup.
    SharedPreferences.setMockInitialValues({
      AppConstants.keySportsLeagues: ['mlb'],
      AppConstants.keySportsFollowedTeams: ['baseball/mlb/1'],
      AppConstants.keySportsFavoriteLeague: 'mlb',
    });
    final r = StorageService();
    await r.init();
    return r;
  }

  void expectSportsCopied(StorageService r) {
    expect(r.getSportsLeagues(), ['nba', 'eng.1', 'nhl']);
    expect(r.getSportsAddedLeagues(), ['gre.1']);
    expect(r.getSportsFavoriteLeague(), 'eng.1');
    expect(r.getSportsFollowedTeams(), ['soccer/eng.1/359', 'nba/2']);
    expect(r.getSportsChannelPicks(), '{"401":"a::espn"}');
    expect(r.getSportsHideScores(), isTrue);
  }

  Future<void> expectKidCopied(StorageService r) async {
    await r.setActiveViewerId('kid');
    expect(r.getSportsLeagues(), ['nhl']);
    expect(r.getSportsFavoriteLeague(), 'nhl');
    expect(r.getSportsFollowedTeams(), ['hockey/nhl/10']);
  }

  test('transfer: every viewer\'s Sports Trak setup goes across', () async {
    final payload = (await sender()).exportForTransfer();
    final r = await receiver();
    await r.importForTransfer(payload);
    expectSportsCopied(r);
    await expectKidCopied(r);
  });

  test('transfer without Media Hub data still carries Sports Trak', () async {
    final payload = (await sender()).exportForTransfer(includeArchive: false);
    final r = await receiver();
    await r.importForTransfer(payload);
    expectSportsCopied(r);
  });

  test('backup and restore keep the Sports Trak setup', () async {
    final payload = (await sender()).exportForBackup();
    final r = await receiver();
    await r.importForBackup(payload);
    expectSportsCopied(r);
    await expectKidCopied(r);
  });
}
