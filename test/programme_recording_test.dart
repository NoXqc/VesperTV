import 'dart:convert';
import 'dart:async' show Completer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/recording_service.dart';
import 'programme_reminders_test.dart' show programme, programmeChannel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('vespertv/recorder');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late RecordingService service;
  late DateTime time;
  final calls = <MethodCall>[];
  var fail = false;
  var exact = true;
  var free = 10 << 30;
  var active = <Map<String, Object>>[];
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('vesper-programme-recording-');
    time = DateTime.now();
    calls.clear();
    fail = false;
    exact = true;
    free = 10 << 30;
    active = [];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'active':
          return active;
        case 'storage':
          return [
            {
              'path': directory.path,
              'free': free,
              'total': 20 << 30,
              'removable': false
            }
          ];
        case 'schedule':
          if (fail) throw PlatformException(code: 'RECORDER');
          return exact;
        default:
          return null;
      }
    });
    service = RecordingService.forTesting(directory, now: () => time);
    await service.init();
    calls.clear();
  });
  tearDown(() async {
    service.dispose();
    messenger.setMockMethodCallHandler(bridge, null);
    expect(
        directory.absolute.path,
        startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}vesper-programme-recording-'));
    await directory.delete(recursive: true);
  });
  test(
      'native alarm gets exact programme times/URL/storage; persistence and dedupe survive restart',
      () async {
    final p = programme(time.add(const Duration(minutes: 20)));
    final entry = await service.recordProgramme(programmeChannel, p);
    final schedule = jsonDecode(calls
        .where((c) => c.method == 'schedule')
        .last
        .arguments['items'] as String) as List;
    expect(schedule.single['startAt'], p.start.millisecondsSinceEpoch);
    expect(schedule.single['endAt'], p.stop.millisecondsSinceEpoch);
    expect(schedule.single['url'], programmeChannel.url);
    expect(schedule.single['path'], startsWith(directory.path));
    expect(entry.isChannel, isTrue);
    expect(await service.recordProgramme(programmeChannel, p), same(entry));
    final reload = RecordingService.forTesting(directory, now: () => time);
    await reload.init();
    expect(reload.entryForProgramme(programmeChannel, p)?.id, entry.id);
    expect(reload.items.single.program, p.title);
    reload.dispose();
    await service.cancelProgramme(entry);
    expect(service.items, isEmpty);
    expect(
        jsonDecode(calls
            .where((c) => c.method == 'schedule')
            .last
            .arguments['items'] as String),
        isEmpty);
    expect(calls.where((c) => c.method == 'stop').single.arguments['id'],
        entry.id);
  });
  test(
      'overlap sweep counts simultaneous recordings only and keeps adjacent programmes possible',
      () async {
    final a = programme(time.add(const Duration(minutes: 10)), minutes: 10);
    final b = programme(time.add(const Duration(minutes: 20)), minutes: 10);
    await service.recordProgramme(programmeChannel, a);
    await service.recordProgramme(programmeChannel.copyWith(id: 'p::two'), b);
    final spanning =
        programme(time.add(const Duration(minutes: 15)), minutes: 10);
    expect(service.programmeConflict(programmeChannel, spanning, 1), isNotNull);
    expect(service.programmeConflict(programmeChannel, spanning, 2), isNull);
    expect(service.programmeConflict(programmeChannel, b, 1), isNotNull);
    expect(service.programmeConflict(programmeChannel, programme(b.stop), 1),
        isNull);
    expect(
        service.programmeConflict(
            Channel(
                id: 'other::one',
                rawId: 'one',
                playlistId: 'other',
                name: 'Other',
                group: 'TV',
                url: 'https://example.test/live'),
            spanning,
            1),
        isNull);
  });
  test(
      'low storage and native schedule failure never create phantom scheduled recordings',
      () async {
    final p = programme(time.add(const Duration(minutes: 10)));
    free = 0;
    await expectLater(
        service.recordProgramme(programmeChannel, p), throwsStateError);
    expect(service.items, isEmpty);
    free = 10 << 30;
    fail = true;
    await expectLater(service.recordProgramme(programmeChannel, p),
        throwsA(isA<PlatformException>()));
    expect(service.items, isEmpty);
    expect(
        (jsonDecode(
                await File('${directory.path}/recordings.json').readAsString())
            as Map)['items'],
        isEmpty);
  });
  test(
      'reports inexact alarms, rejects past programmes, and retains partial recordings when cancelled after start',
      () async {
    exact = false;
    final p = programme(time.add(const Duration(minutes: 1)));
    final entry = await service.recordProgramme(programmeChannel, p);
    expect(service.exactSchedule, isFalse);
    expect(service.recordProgramme(programmeChannel, programme(time)),
        throwsStateError);
    time = p.start;
    active = [
      {'id': entry.id, 'bytes': 100}
    ];
    await service.refreshStatus();
    expect(entry.state, RecState.recording);
    await service.cancelProgramme(entry);
    expect(service.items.single, same(entry));
    expect(entry.state, RecState.stopped);
  });

  test(
      'foreground preparation runs once before the native start without changing its alarm',
      () async {
    final prepared = Completer<void>();
    var callsCount = 0;
    service.prepareProgramme = (entry) async {
      callsCount++;
      prepared.complete();
    };
    final p = programme(time.add(const Duration(seconds: 2)));
    final entry = await service.recordProgramme(programmeChannel, p);
    await prepared.future.timeout(const Duration(seconds: 2));
    await service.updateSettings(service.settings);
    expect(callsCount, 1);
    expect(entry.startAt, p.start);
  });
}
