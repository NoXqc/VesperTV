import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/source_profiles.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wide_guide_back_test.dart' show GuidePlaylist;

/// The Profiles row on Media Hub sources (owner, 2026-11-24): pick which
/// profiles get a source; a kids profile only with the PIN.
void main() {
  late StorageService storage;
  late ViewerProfileService viewers;

  Future<void> setUpProfiles({bool pin = true, int count = 3}) async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    if (pin) await ParentalPin(storage).setPin('1234');
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'vpguest',
          name: 'Guest',
          colorIndex: 1,
          isRestricted: false,
          createdAt: DateTime(2026)),
      ViewerProfile(
          id: 'vpkids',
          name: 'Kids',
          colorIndex: 2,
          isRestricted: true,
          createdAt: DateTime(2026)),
    ].take(count).toList());
    await storage.setActiveViewerId(count > 1 ? 'vpguest' : 'main');
    final playlist = GuidePlaylist(storage);
    viewers = ViewerProfileService(
        storage, playlist, PlaybackService(storage, playlist));
  }

  Future<ValueNotifier<Set<String>>> pump(WidgetTester tester) async {
    final ids = ValueNotifier(SourceProfiles.usual(viewers));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<ParentalPin>.value(value: ParentalPin(storage)),
        ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Set<String>>(
            valueListenable: ids,
            builder: (_, value, __) => SourceProfilesRow(
              title: 'Profiles',
              profileIds: value,
              onChanged: (v) => ids.value = v,
            ),
          ),
        ),
      ),
    ));
    return ids;
  }

  testWidgets('usual = regular profiles; Only this profile', (tester) async {
    await setUpProfiles();
    final ids = await pump(tester);
    expect(ids.value, {'main', 'vpguest'});
    expect(find.text('Main, Guest'), findsOneWidget);

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Which profiles get it?'), findsOneWidget);
    await tester.tap(find.text('Only this profile'));
    await tester.pumpAndSettle();
    expect(ids.value, {'vpguest'});
    expect(find.text('Only this profile (Guest)'), findsOneWidget);
  });

  testWidgets('ticking a kids profile asks the PIN', (tester) async {
    await setUpProfiles();
    final ids = await pump(tester);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();

    // Cancelled PIN: stays off.
    await tester.tap(find.text('Kids'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    await tester.tap(find.text('✕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(ids.value, {'main', 'vpguest'});

    // Right PIN: on.
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kids'));
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.sendKeyEvent(
          LogicalKeyboardKey.findKeyByKeyId(0x00000000030 + int.parse(d))!);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(ids.value, {'main', 'vpguest', 'vpkids'});
    expect(find.text('Every profile'), findsOneWidget);
  });

  testWidgets('hidden with one profile', (tester) async {
    await setUpProfiles(pin: false, count: 1);
    await pump(tester);
    expect(find.text('Profiles'), findsNothing);
  });
}
