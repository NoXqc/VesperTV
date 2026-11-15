import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/apple_tv_storage.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  late Directory dir;
  late File file;
  late InMemorySharedPreferencesStore defaults;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('appletv_prefs');
    file = File('${dir.path}/Support/vesper_prefs.json');
    defaults = InMemorySharedPreferencesStore.empty();
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('keeps every value type through the file', () async {
    final store = AppleTvPrefsStore(defaults, file);
    await store.setValue('Bool', 'flutter.b', true);
    await store.setValue('Int', 'flutter.i', 7);
    await store.setValue('Double', 'flutter.d', 1.0);
    await store.setValue('String', 'flutter.s', 'x');
    await store.setValue('StringList', 'flutter.l', <String>['a', 'b']);
    await store.flush();

    final again = AppleTvPrefsStore(defaults, file);
    final all = await again.getAll();
    expect(all['flutter.b'], true);
    expect(all['flutter.i'], isA<int>());
    expect(all['flutter.i'], 7);
    expect(all['flutter.d'], isA<double>());
    expect(all['flutter.s'], 'x');
    expect(all['flutter.l'], <String>['a', 'b']);
    expect(again.restoredFromCopy, isFalse);
  });

  test('restores from the NSUserDefaults copy when Caches was emptied',
      () async {
    final store = AppleTvPrefsStore(defaults, file);
    await store.setValue('String', 'flutter.login', 'secret');
    await store.flush();
    await file.delete();

    final again = AppleTvPrefsStore(defaults, file);
    expect((await again.getAll())['flutter.login'], 'secret');
    expect(again.restoredFromCopy, isTrue);
  });

  test('drops the copy once the settings outgrow NSUserDefaults', () async {
    final store = AppleTvPrefsStore(defaults, file);
    await store.setValue('String', 'flutter.small', 'x');
    await store.flush();
    expect((await defaults.getAll()).keys, contains(startsWith('flutter.')));

    await store.setValue(
        'String', 'flutter.big', 'y' * (AppleTvPrefsStore.copyLimit + 1));
    await store.flush();
    expect(await defaults.getAll(), isEmpty);
    expect(await file.length(), greaterThan(AppleTvPrefsStore.copyLimit));
  });

  test('remove, clear and prefix filters', () async {
    final store = AppleTvPrefsStore(defaults, file);
    await store.setValue('String', 'flutter.a', '1');
    await store.setValue('String', 'flutter.b', '2');
    await store.setValue('String', 'other.c', '3');
    await store.remove('flutter.a');
    expect((await store.getAll()).keys, ['flutter.b']);
    expect((await store.getAllWithPrefix('other.')).keys, ['other.c']);
    await store.clear();
    expect(await store.getAll(), isEmpty);
    expect((await store.getAllWithPrefix('other.')).keys, ['other.c']);
  });
}
