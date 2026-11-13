import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/sync_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/cloud_sync_service.dart';
import 'package:nox_iptv/services/cloud_sync.dart' show SyncDeviceLimit;
import 'package:nox_iptv/services/cloud_transfer.dart';
import 'package:nox_iptv/services/device_transfer.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const limitMessage =
    'This sync already has 4 devices. Stop syncing on one of them, then try again. A device unused for 30 days frees its place on its own.';
const resetWarning =
    'Resetting the sync code removes all your encrypted data from the server. Every other device stops syncing and must be linked again with a new code. Save the new recovery code.';

const recovery = '0123-4567-89AB-CDEF-GHJK-MNPQ-RS';

class FakeSync extends CloudSyncService {
  FakeSync(super.storage);
  SyncStatus state = SyncStatus.off;
  TransferException? error;
  int setups = 0, syncs = 0, resets = 0, stops = 0, reveals = 0;
  String? joined;
  bool typo = false;
  bool deviceLimit = false;
  DateTime? linkExpires;
  Completer<void>? hold;

  @override
  SyncStatus get status => state;
  @override
  TransferException? get lastError => error;
  @override
  DateTime? get lastSync => syncs == 0 ? null : DateTime(2026, 11, 4, 12);
  @override
  Future<void> setUp() async {
    setups++;
    if (hold != null) await hold!.future;
    state = SyncStatus.on;
    notifyListeners();
  }

  @override
  Future<int> syncNow({bool pushLocal = true}) async {
    syncs++;
    notifyListeners();
    return 0;
  }

  @override
  Future<String?> recoveryCode() async {
    reveals++;
    return recovery;
  }

  @override
  Future<CloudTransfer?> createLinkCode() async => CloudTransfer(
      '1234567890123456',
      linkExpires ?? DateTime.now().add(const Duration(minutes: 10)));
  @override
  Future<void> joinWithLinkCode(String code) async {
    joined = code;
    if (deviceLimit) {
      state = SyncStatus.full;
      notifyListeners();
      throw const SyncDeviceLimit(3);
    }
    if (error != null) throw error!;
    state = SyncStatus.on;
    notifyListeners();
  }

  @override
  Future<bool> joinWithRecoveryCode(String code) async {
    joined = code;
    if (deviceLimit) {
      state = SyncStatus.full;
      notifyListeners();
      throw const SyncDeviceLimit(3);
    }
    if (typo) return false;
    state = SyncStatus.on;
    notifyListeners();
    return true;
  }

  @override
  Future<String> resetCode() async {
    resets++;
    return recovery;
  }

  @override
  Future<void> stop() async {
    stops++;
    state = SyncStatus.off;
    notifyListeners();
  }
}

void main() {
  Future<(FakeSync, ParentalPin)> pump(WidgetTester tester,
      {bool tv = true,
      SyncStatus state = SyncStatus.off,
      bool pin = false}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage)..isTelevision = tv;
    await prefs.init();
    final sync = FakeSync(storage)..state = state;
    final parental = ParentalPin(storage);
    if (pin) await parental.setPin('1234');
    addTearDown(sync.dispose);
    addTearDown(prefs.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CloudSyncService>.value(value: sync),
        ChangeNotifierProvider.value(value: prefs),
        Provider.value(value: parental),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const SyncScreen()),
    ));
    await tester.pumpAndSettle();
    return (sync, parental);
  }

  Future<void> tap(WidgetTester tester, String title) async {
    final target = find.widgetWithText(TvMenuTile, title).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  TvMenuTile tile(WidgetTester tester, String title) =>
      tester.widget<TvMenuTile>(find.widgetWithText(TvMenuTile, title).last);

  for (final tv in [true, false]) {
    for (final state in SyncStatus.values) {
      testWidgets('$state at ${tv ? 'TV' : 'phone'} size has reachable actions',
          (tester) async {
        tester.view.physicalSize =
            tv ? const Size(1280, 720) : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, tv: tv, state: state);
        final first = state == SyncStatus.on ? 'Sync now' : 'Set up sync';
        expect(tile(tester, first).focusNode!.hasFocus, isTrue);
        if (state == SyncStatus.revoked) {
          expect(
              find.text(
                  'The sync code was reset on another device. Link this device again.'),
              findsOneWidget);
        }
        if (state == SyncStatus.full) {
          expect(find.text(limitMessage), findsOneWidget);
          expect(find.text('Sync now'), findsNothing);
        }
        final expected = state == SyncStatus.on
            ? [
                'Link a device',
                'Show recovery code',
                'Reset sync code',
                'Stop syncing on this device'
              ]
            : ['I have a code'];
        for (final title in expected) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(tile(tester, title).focusNode!.hasFocus, isTrue);
          expect(
              tester.getRect(find.widgetWithText(TvMenuTile, title)).overlaps(
                  Offset.zero &
                      (tv ? const Size(1280, 720) : const Size(390, 844))),
              isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('setup shows recovery once and restores focus to on actions',
      (tester) async {
    final (sync, _) = await pump(tester);
    await tap(tester, 'Set up sync');
    expect(sync.setups, 1);
    expect(find.text(recovery), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
        tile(tester, 'I saved my recovery code').focusNode!.hasFocus, isTrue);
    await tap(tester, 'I saved my recovery code');
    expect(tile(tester, 'Sync now').focusNode!.hasFocus, isTrue);
    await tap(tester, 'Sync now');
    expect(sync.syncs, 1);
    expect(find.textContaining('Last sync: '), findsOneWidget);
  });

  testWidgets('recovery requires PIN, Back never reveals it', (tester) async {
    final (sync, _) = await pump(tester, state: SyncStatus.on, pin: true);
    await tap(tester, 'Show recovery code');
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(sync.reveals, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tile(tester, 'Show recovery code').focusNode!.hasFocus, isTrue);
    await tap(tester, 'Show recovery code');
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();
    expect(sync.reveals, 1);
    expect(find.text(recovery), findsOneWidget);
  });

  testWidgets('reset and stop both default to Cancel, confirm then act',
      (tester) async {
    final (sync, _) = await pump(tester, state: SyncStatus.on);
    await tap(tester, 'Reset sync code');
    expect(find.text(resetWarning), findsOneWidget);
    expect(sync.resets, 0);
    expect(tile(tester, 'Cancel').focusNode!.hasFocus, isTrue);
    await tap(tester, 'Cancel');
    expect(sync.resets, 0);
    expect(tile(tester, 'Reset sync code').focusNode!.hasFocus, isTrue);
    await tap(tester, 'Reset sync code');
    await tap(tester, 'Reset sync code');
    expect(sync.resets, 1);
    expect(find.text(recovery), findsOneWidget);
    await tap(tester, 'I saved my recovery code');
    await tap(tester, 'Stop syncing on this device');
    await tap(tester, 'Cancel');
    expect(sync.stops, 0);
    await tap(tester, 'Stop syncing on this device');
    await tap(tester, 'Stop syncing on this device');
    expect(sync.stops, 1);
    expect(tile(tester, 'Set up sync').focusNode!.hasFocus, isTrue);
  });

  testWidgets('link QR expires and hides the code; Back restores link focus',
      (tester) async {
    final (sync, _) = await pump(tester, state: SyncStatus.on);
    await tap(tester, 'Link a device');
    expect(
        find.text(
            'This code works for one device, once. Create a new code to link another device.'),
        findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('1234 5678 9012 3456'), findsOneWidget);
    expect(find.textContaining('Expires in '), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tap(tester, 'Done');
    sync.linkExpires = DateTime.now().subtract(const Duration(seconds: 1));
    await tap(tester, 'Link a device');
    expect(
        find.text(
            'This code works for one device, once. Create a new code to link another device.'),
        findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('1234 5678 9012 3456'), findsNothing);
    await tap(tester, 'Done');
    expect(tile(tester, 'Link a device').focusNode!.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final tv in [true, false]) {
    testWidgets('join link / recovery and retry typo (${tv ? 'TV' : 'phone'})',
        (tester) async {
      tester.view.physicalSize =
          tv ? const Size(1280, 720) : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (sync, _) = await pump(tester, tv: tv);
      await tap(tester, 'I have a code');
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, tv);
      if (tv) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField), '1234567890123456');
      sync.error = const TransferException(TransferError.notFound);
      await tap(tester, 'Join sync');
      expect(find.textContaining('Nothing was found for that code.'),
          findsWidgets);
      sync.error = null;
      await tap(tester, 'Use a recovery code');
      if (tv) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField), recovery);
      sync.typo = true;
      await tap(tester, 'Join sync');
      expect(find.text('That code isn\'t right. Check it on the other device.'),
          findsOneWidget);
      sync.typo = false;
      await tap(tester, 'Join sync');
      expect(sync.joined, recovery);
      expect(tile(tester, 'Sync now').focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'setup double press is ignored while busy; pop during request is safe',
      (tester) async {
    final (sync, _) = await pump(tester);
    sync.hold = Completer<void>();
    tile(tester, 'Set up sync').onTap();
    tile(tester, 'Set up sync').onTap();
    await tester.pump();
    expect(sync.setups, 1);
    await tester.pumpWidget(const SizedBox());
    sync.hold!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final tv in [true, false]) {
    for (final recoveryMode in [true, false]) {
      testWidgets(
          'device limit on ${recoveryMode ? 'recovery' : 'link'} join (${tv ? 'TV' : 'phone'}) stays actionable',
          (tester) async {
        tester.view.physicalSize =
            tv ? const Size(1280, 720) : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (sync, _) = await pump(tester, tv: tv);
        sync.deviceLimit = true;
        await tap(tester, 'I have a code');
        if (recoveryMode) await tap(tester, 'Use a recovery code');
        if (tv) {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField),
            recoveryMode ? recovery : '1234567890123456');
        await tap(tester, 'Join sync');
        expect(find.text(limitMessage), findsOneWidget);
        expect(
            find.text("That code isn't right. Check it on the other device."),
            findsNothing);
        expect(tile(tester, 'Join sync').focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(limitMessage), findsOneWidget);
        expect(tile(tester, 'Set up sync').focusNode!.hasFocus, isTrue);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
