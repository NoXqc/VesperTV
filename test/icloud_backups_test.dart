import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/icloud_backups_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/backup_folder.dart';
import 'package:nox_iptv/services/backup_service.dart';
import 'package:nox_iptv/services/icloud_backups.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _folderChannel = MethodChannel('test/backup_folder');
const _icloudChannel = MethodChannel('test/icloud');

/// The iOS folder / CloudKit natives, in memory.
class _Natives {
  String? folder = 'VesperTV Backups';
  final files = <String, String>{};
  String status = 'available';
  final cloud = <String, Map<String, Object?>>{};
  PlatformException? saveError;
  final calls = <String>[];

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_folderChannel, (call) async {
      calls.add('folder.${call.method}');
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'name':
          return folder;
        case 'write':
          files[args['name'] as String] = args['content'] as String;
          return args['name'];
        case 'list':
          return [
            for (final e in files.entries)
              {
                'id': e.key,
                'name': e.key,
                'modified': 1000,
                'size': e.value.length
              },
            {'id': 'notes.txt', 'name': 'notes.txt', 'modified': 1, 'size': 1},
          ];
        case 'read':
          return files[args['id']];
        case 'delete':
          return files.remove(args['id']) != null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_icloudChannel, (call) async {
      calls.add('icloud.${call.method}');
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'status':
          return status;
        case 'save':
          if (saveError != null) throw saveError!;
          cloud['device-me'] = {
            'id': 'device-me',
            'device': 'iPhone',
            'app': args['app'],
            'size': (args['content'] as String).length,
            'modified': 2000,
            'mine': true,
            'content': args['content'],
          };
          return null;
        case 'list':
          return [
            for (final r in cloud.values)
              {
                for (final e in r.entries)
                  if (e.key != 'content') e.key: e.value
              }
          ];
        case 'read':
          return cloud[args['id']]?['content'];
        case 'delete':
          cloud.remove(args['id']);
          return null;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_folderChannel, null);
      messenger.setMockMethodCallHandler(_icloudChannel, null);
    });
  }
}

Future<StorageService> _storage(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final storage = StorageService();
  await storage.init();
  return storage;
}

String _backupFile(Map<String, Object?> data) =>
    jsonEncode({'format': 'vespertv-backup', 'data': data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('vesper_icloud');
    addTearDown(() => temp.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => temp.path);
    PackageInfo.setMockInitialValues(
        appName: 'VesperTV',
        packageName: 'app.vespertv.player',
        version: '1.0.74',
        buildNumber: '965',
        buildSignature: '');
  });

  BackupService service(StorageService storage) => BackupService(storage,
      folder: BackupFolder(channel: _folderChannel),
      icloud: ICloudBackups(channel: _icloudChannel));

  group('backup folder (iPhone / iPad)', () {
    test('backups are written, listed, read and deleted in the chosen folder',
        () async {
      final natives = _Natives()..install();
      final storage = await _storage({
        'nox_favorites': <String>['a::1']
      });
      final backups = service(storage);

      expect(await backups.location(), 'VesperTV Backups');
      final entry = await backups.create();
      expect(entry.id, startsWith('folder:vespertv-backup-'));
      expect(natives.files.keys.single, entry.name);

      final listed = await backups.list();
      expect(listed.map((e) => e.name), [entry.name]); // not notes.txt
      final values = await backups.load(listed.single);
      expect(jsonEncode(values['nox_favorites']), contains('a::1'));

      expect(await backups.delete(listed.single), isTrue);
      expect(natives.files, isEmpty);
      // iCloud is off by default: nothing went there.
      expect(natives.calls, isNot(contains('icloud.save')));
    });

    test('no folder chosen = the usual place', () async {
      final natives = _Natives()
        ..folder = null
        ..install();
      final backups = service(await _storage({}));
      expect(await backups.location(), BackupService.locationLabel);
      final entry = await backups.create();
      expect(entry.id, isNot(startsWith('folder:')));
      expect(natives.files, isEmpty);
    });
  });

  group('iCloud', () {
    test('with Also save to iCloud on, a backup replaces this device\'s copy',
        () async {
      final natives = _Natives()..install();
      final storage = await _storage({
        AppConstants.keyBackupICloud: true,
        'nox_favorites': <String>['a::1'],
      });
      final backups = service(storage);
      await backups.create();
      expect(backups.lastICloudError, isNull);
      expect(natives.cloud['device-me']!['app'], '1.0.74+965');

      final icloud = ICloudBackups(channel: _icloudChannel);
      final entries = await icloud.list();
      expect(entries.single.mine, isTrue);
      expect(entries.single.device, 'iPhone');
      final values = await backups.loadFromICloud(entries.single);
      expect(jsonEncode(values['nox_favorites']), contains('a::1'));
    });

    test('the undo point a restore makes never goes to iCloud', () async {
      final natives = _Natives()..install();
      final storage = await _storage({AppConstants.keyBackupICloud: true});
      await service(storage).create(auto: true, cloud: false);
      expect(natives.calls, isNot(contains('icloud.save')));
    });

    test('an iCloud failure keeps the backup and says why', () async {
      final natives = _Natives()
        ..saveError = PlatformException(code: 'QUOTA')
        ..install();
      final storage = await _storage({AppConstants.keyBackupICloud: true});
      final backups = service(storage);
      final entry = await backups.create();
      expect(natives.files.keys, [entry.name]);
      expect(ICloudBackups.errorMessage(backups.lastICloudError!),
          'Your iCloud storage is full.');
    });

    test('status: a build without the entitlement says not set up', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_icloudChannel,
          (_) async => throw PlatformException(code: 'NOT_SET_UP'));
      addTearDown(
          () => messenger.setMockMethodCallHandler(_icloudChannel, null));
      expect(await ICloudBackups(channel: _icloudChannel).status(), 'notSetUp');
      expect(ICloudBackups.statusMessage('notSetUp'),
          'iCloud backups aren\'t available in this build yet.');
    });

    test('the setting never syncs between devices', () async {
      final storage = await _storage({AppConstants.keyBackupICloud: true});
      expect(storage.getBackupToICloud(), isTrue);
      expect(storage.exportForSync().keys,
          isNot(contains(AppConstants.keyBackupICloud)));
    });
  });

  group('Restore from iCloud screen', () {
    Future<_Natives> pump(WidgetTester tester, _Natives natives) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      natives.install();
      final storage = await _storage({});
      final prefs = AppPreferences(storage)..isTelevision = true;
      await prefs.init();
      addTearDown(prefs.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: ICloudBackupsScreen(
                icloud: ICloudBackups(channel: _icloudChannel))),
      ));
      await tester.pumpAndSettle();
      return natives;
    }

    testWidgets('lists each device, newest first; OK asks before restoring',
        (tester) async {
      final natives = _Natives();
      natives.cloud['device-tv'] = {
        'id': 'device-tv',
        'device': 'Apple TV',
        'app': '1.0.74+965',
        'size': 2048,
        'modified': 1000,
        'mine': true,
        'content': _backupFile({'nox_favorites': <String>[]}),
      };
      natives.cloud['device-phone'] = {
        'id': 'device-phone',
        'device': 'iPhone',
        'app': '1.0.74+965',
        'size': 4096,
        'modified': 5000,
        'mine': false,
        'content': _backupFile({
          'nox_favorites': <String>['a::1']
        }),
      };
      await pump(tester, natives);
      expect(tester.takeException(), isNull);

      final tiles = find.byType(TvMenuTile);
      expect(tester.widget<TvMenuTile>(tiles.at(0)).title, 'iPhone');
      expect(tester.widget<TvMenuTile>(tiles.at(0)).autofocus, isTrue);
      expect(tester.widget<TvMenuTile>(tiles.at(1)).title,
          'Apple TV · This device');

      await tester.tap(tiles.at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore this backup'));
      await tester.pumpAndSettle();
      // restoreBackup's own confirmation (Cancel focused): nothing replaced yet.
      expect(find.text('Restore backup?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(natives.calls, contains('icloud.read'));
    });

    testWidgets('nothing in iCloud yet: says where to turn it on',
        (tester) async {
      await pump(tester, _Natives());
      expect(
          find.text(
              'No backups in iCloud yet. On the other device: Settings > Backup & devices > Backup & restore > Also save to iCloud.'),
          findsOneWidget);
      expect(find.widgetWithText(TvMenuTile, 'Try again'), findsOneWidget);
    });

    testWidgets('signed out of iCloud: says so, no list', (tester) async {
      await pump(tester, _Natives()..status = 'noAccount');
      expect(
          find.text(
              'Sign in to iCloud in this device\'s Settings to keep backups in iCloud.'),
          findsOneWidget);
    });
  });
}
