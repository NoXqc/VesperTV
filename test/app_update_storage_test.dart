import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/check_updates_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/app_update_service.dart';
import 'package:nox_iptv/services/storage_service.dart';

class _Client extends http.BaseClient {
  _Client(this.response);
  final http.StreamedResponse Function() response;
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return response();
  }
}

class _AndroidUpdater extends AppUpdateService {
  _AndroidUpdater(_Client client, Directory cache)
      : super(downloadClient: client, cacheDirectory: () async => cache);
  @override
  bool get downloadInBrowser => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nox.nox_iptv/app_update');
  const mb = 1024 * 1024;
  const url = 'https://example.test/update.apk';
  late Directory cache;
  late File apk;
  late Object? available;
  late List<MethodCall> calls;
  var storageError = false;

  setUp(() async {
    L10n.code = 'en';
    available = 5 * 1024 * mb; // Long-sized Android free-space result.
    storageError = false;
    calls = [];
    cache = await Directory.systemTemp.createTemp('vesper-updater-test-');
    apk = File(p.join(cache.path, 'noxplayer_update.apk'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getAvailableStorageBytes':
          if (storageError) {
            throw PlatformException(code: 'STORAGE_CHECK_FAILED');
          }
          return available;
        case 'canRequestInstalls':
          return true;
        case 'installApk':
          return null;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() async {
    L10n.code = 'en';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await apk.exists()) await apk.delete();
    await cache.delete();
  });

  _Client client(List<List<int>> chunks,
          {int status = 200, int? contentLength}) =>
      _Client(() => http.StreamedResponse(Stream.fromIterable(chunks), status,
          contentLength: contentLength));

  test('native free bytes are not truncated to 32 bits', () async {
    expect(await AppUpdateService().getAvailableStorageBytes(), 5 * 1024 * mb);
    expect(calls.single.method, 'getAvailableStorageBytes');
  });

  test(
      'three APK sizes required before any HTTP or cache file is opened; shortfall rounds up',
      () async {
    final httpClient = client([
      [1, 2]
    ]);
    final updater = _AndroidUpdater(httpClient, cache);
    available = 30 * mb - 1;
    await expectLater(
        updater.downloadUpdate(url, expectedSizeBytes: 10 * mb),
        throwsA(isA<UpdateDownloadException>().having(
            (e) => e.message, 'message', 'Free about 1 MB and try again.')));
    expect(httpClient.requests, 0);
    expect(await apk.exists(), false);
    available = 0;
    await expectLater(
        updater.downloadUpdate(url, expectedSizeBytes: 100 * mb),
        throwsA(isA<UpdateDownloadException>().having(
            (e) => e.message, 'message', 'Free about 300 MB and try again.')));
    expect(httpClient.requests, 0);
  });

  test(
      'exact reserve succeeds; GitHub size is used despite missing/misleading Content-Length',
      () async {
    for (final length in [null, 999]) {
      available = 12;
      final httpClient = client([
        [1, 2],
        [3, 4]
      ], contentLength: length);
      final progress = <double>[];
      final result = await _AndroidUpdater(httpClient, cache)
          .downloadUpdate(url, expectedSizeBytes: 4, onProgress: progress.add);
      expect(result.path, apk.path);
      expect(await result.readAsBytes(), [1, 2, 3, 4]);
      expect(progress, [.5, 1]);
    }
  });

  for (final size in [0, -1]) {
    test('unknown/invalid release size $size cannot bypass validation',
        () async {
      final httpClient = client([
        [1]
      ]);
      await expectLater(
          _AndroidUpdater(httpClient, cache)
              .downloadUpdate(url, expectedSizeBytes: size),
          throwsA(isA<UpdateDownloadException>()));
      expect(calls, isEmpty);
      expect(httpClient.requests, 0);
    });
  }

  for (final free in [null, -1]) {
    test('unavailable free-space result $free blocks downloading', () async {
      available = free;
      final httpClient = client([
        [1]
      ]);
      await expectLater(
          _AndroidUpdater(httpClient, cache)
              .downloadUpdate(url, expectedSizeBytes: 1),
          throwsA(isA<UpdateDownloadException>().having(
              (e) => e.message,
              'message',
              'Could not check free storage. Restart VesperTV and try again.')));
      expect(httpClient.requests, 0);
    });
  }

  test('native storage failure is a plain localized error, not a bypass',
      () async {
    storageError = true;
    final httpClient = client([
      [1]
    ]);
    await expectLater(
        _AndroidUpdater(httpClient, cache)
            .downloadUpdate(url, expectedSizeBytes: 1),
        throwsA(isA<UpdateDownloadException>()));
    expect(httpClient.requests, 0);
  });

  for (final chunks in [
    <List<int>>[],
    [
      [1, 2]
    ],
    [
      [1, 2, 3, 4, 5]
    ]
  ]) {
    test(
        'empty, truncated or oversized body $chunks is deleted and cannot be returned for install',
        () async {
      await apk.writeAsBytes([9, 9, 9, 9]); // an older same-name cache file
      final httpClient = client(chunks);
      await expectLater(
          _AndroidUpdater(httpClient, cache)
              .downloadUpdate(url, expectedSizeBytes: 4),
          throwsA(isA<UpdateDownloadException>().having((e) => e.message,
              'message', 'Download failed. Please try again.')));
      expect(await apk.exists(), false);
      expect(calls.any((call) => call.method == 'installApk'), false);
    });
  }

  test('interrupted stream removes the partial APK', () async {
    Stream<List<int>> broken() async* {
      yield [1, 2];
      throw const SocketException('Interrupted');
    }

    final httpClient = _Client(() => http.StreamedResponse(broken(), 200));
    await expectLater(
        _AndroidUpdater(httpClient, cache)
            .downloadUpdate(url, expectedSizeBytes: 4),
        throwsA(isA<UpdateDownloadException>()));
    expect(await apk.exists(), false);
  });

  test('non-success HTTP status cannot create a ready-to-install APK',
      () async {
    final httpClient = client([
      [1, 2, 3, 4]
    ], status: 503);
    await expectLater(
        _AndroidUpdater(httpClient, cache)
            .downloadUpdate(url, expectedSizeBytes: 4),
        throwsA(isA<UpdateDownloadException>()));
    expect(await apk.exists(), false);
  });

  Future<void> openUpdater(WidgetTester tester, _Client httpClient,
      {int size = 4}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    addTearDown(prefs.dispose);
    PackageInfo.setMockInitialValues(
        appName: 'VesperTV',
        packageName: 'com.nox.nox_iptv',
        version: '1.0.49',
        buildNumber: '530',
        buildSignature: '');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs,
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: CheckUpdatesScreen(
                updateService: _AndroidUpdater(httpClient, cache),
                startWith: UpdateInfo(
                    version: '1.0.50',
                    releaseNotes: '',
                    downloadUrl: url,
                    apkSizeBytes: size)))));
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'fr', 'es', 'it', 'el']) {
    testWidgets(
        'shortfall is shown in plain words and offers no Install in $language',
        (tester) async {
      L10n.code = language;
      available = 0;
      final httpClient = client([
        [1]
      ]);
      await openUpdater(tester, httpClient, size: 100 * mb);
      final message = tr('Free about {mb} MB and try again.', {'mb': 300});
      expect(find.textContaining(message), findsOneWidget);
      expect(find.widgetWithText(FilledButton, tr('Install')), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
      expect(httpClient.requests, 0);
      expect(calls.any((call) => call.method == 'installApk'), false);
      if (language != 'en') expect(message, isNot(startsWith('Free about')));
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a truncated download never reaches Install', (tester) async {
    await openUpdater(
        tester,
        client([
          [1, 2]
        ]));
    expect(find.textContaining(tr('Download failed. Please try again.')),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, tr('Install')), findsNothing);
    expect(await tester.runAsync(apk.exists), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only a verified full download reaches the native installer',
      (tester) async {
    await openUpdater(
        tester,
        client([
          [1, 2, 3, 4]
        ]));
    final install = find.widgetWithText(FilledButton, 'Install');
    expect(install, findsOneWidget);
    await tester.tap(install);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'installApk').single.arguments,
        {'filePath': apk.path});
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
