import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Profile lock (owner, 2026-11-23, user requests: a kid leaving the app or
/// starting it in the morning got into Main): a locked profile asks the
/// parental PIN to open, and again after a start or the chosen time away.
void main() {
  test('relock time: 0 = every time, else the minutes away', () {
    expect(profileRelockDue(Duration.zero, 0), isTrue);
    expect(
        profileRelockDue(const Duration(minutes: 4, seconds: 59), 5), isFalse);
    expect(profileRelockDue(const Duration(minutes: 5), 5), isTrue);
    expect(profileRelockDue(const Duration(minutes: 59), 60), isFalse);
  });

  test('the lock is saved with the profile, old profiles are unlocked', () {
    final locked = ViewerProfile.main().copyWith(isLocked: true);
    final back = ViewerProfile.fromJson(locked.toJson());
    expect(back.isLocked, isTrue);
    expect(ViewerProfile.fromJson(ViewerProfile.main().toJson()).isLocked,
        isFalse);
    expect(ViewerProfile.main().toJson().containsKey('isLocked'), isFalse);
  });

  group('switching', () {
    late StorageService storage;
    late ViewerProfileService viewers;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      await ParentalPin(storage).setPin('1234');
      await storage.setViewerProfiles([
        ViewerProfile.main().copyWith(isLocked: true),
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
      ]);
      await storage.setActiveViewerId('vpguest');
      final playlist = GuidePlaylist(storage);
      viewers = ViewerProfileService(
          storage, playlist, PlaybackService(storage, playlist));
    });

    Future<BuildContext> pumpApp(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(Provider.value(
          value: ParentalPin(storage),
          child: MaterialApp(home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          }))));
      return context;
    }

    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.sendKeyEvent(
            LogicalKeyboardKey.findKeyByKeyId(0x00000000030 + int.parse(d))!);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a locked profile asks the PIN, an unlocked one does not',
        (tester) async {
      final context = await pumpApp(tester);
      final main = viewers.profiles.firstWhere((p) => p.isMain);
      final kids = viewers.profiles.firstWhere((p) => p.isRestricted);
      final guest = viewers.profiles.firstWhere((p) => p.id == 'vpguest');
      expect(viewers.needsPinFor(main), isTrue);
      expect(viewers.needsPinFor(kids), isFalse);
      expect(viewers.needsPinFor(guest), isFalse);

      // The switch to Main stops at the PIN pad (cancelled here: a real
      // switch reloads the whole app's state, outside this test).
      final toMain = viewers.switchTo(context, ViewerProfile.mainId);
      await tester.pumpAndSettle();
      expect(find.text('Enter PIN'), findsOneWidget);
      await tester.tap(find.text('✕'));
      await tester.pumpAndSettle();
      expect(await toMain, isFalse);
      expect(viewers.active.id, 'vpguest');
    });

    testWidgets('after a start or time away, the same profile asks again',
        (tester) async {
      final context = await pumpApp(tester);
      await storage.setActiveViewerId(ViewerProfile.mainId);
      final playlist = GuidePlaylist(storage);
      viewers = ViewerProfileService(
          storage, playlist, PlaybackService(storage, playlist));
      final main = viewers.active;
      // In use and open: picking it again is free.
      expect(viewers.needsPinFor(main), isFalse);
      expect(await viewers.switchTo(context, ViewerProfile.mainId), isTrue);

      expect(viewers.lockActive(), isTrue);
      expect(viewers.needsPinFor(main), isTrue);
      final again = viewers.switchTo(context, ViewerProfile.mainId);
      await tester.pumpAndSettle();
      expect(find.text('Enter PIN'), findsOneWidget);
      await typePin(tester, '1234');
      expect(await again, isTrue);
      expect(viewers.lockedOut, isFalse);
    });

    testWidgets('a wrong PIN keeps the locked profile shut', (tester) async {
      final context = await pumpApp(tester);
      final toMain = viewers.switchTo(context, ViewerProfile.mainId);
      await tester.pumpAndSettle();
      await typePin(tester, '9999');
      expect(find.text('Incorrect PIN'), findsOneWidget);
      // Back out of the pad.
      await tester.tap(find.text('✕'));
      await tester.pumpAndSettle();
      expect(await toMain, isFalse);
      expect(viewers.active.id, 'vpguest');
    });

    test('an unlocked or kids profile in use is never locked out', () async {
      expect(viewers.lockActive(), isFalse); // Guest: not locked
      await storage.setActiveViewerId('vpkids');
      final playlist = GuidePlaylist(storage);
      viewers = ViewerProfileService(
          storage, playlist, PlaybackService(storage, playlist));
      expect(viewers.lockActive(), isFalse);
    });
  });
}
