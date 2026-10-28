import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/programme_reminders.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

final programmeChannel = Channel(
    id: 'p::one',
    rawId: 'one',
    playlistId: 'p',
    name: 'Channel One',
    group: 'TV',
    url: 'https://example.test/live');
EpgProgram programme(DateTime start,
        {int minutes = 30, String title = 'Upcoming show'}) =>
    EpgProgram(
        channelId: 'one',
        title: title,
        start: start,
        stop: start.add(Duration(minutes: minutes)));

class _FailingStorage extends StorageService {
  @override
  Future<void> setProgrammeReminders(String json, {String? viewerId}) =>
      Future.error(StateError('fixture'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ProgrammeReminders service;
  late DateTime time;
  late EpgProgram show;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    time = DateTime.utc(2026, 10, 28, 18);
    show = programme(time.add(const Duration(minutes: 20)));
    service = ProgrammeReminders(storage, now: () => time);
  });
  tearDown(() => service.dispose());
  test(
      'persists channel/start identity, excludes reminders from transfers, cancels',
      () async {
    expect(await service.toggle(programmeChannel, show), isTrue);
    final reloaded = ProgrammeReminders(storage, now: () => time);
    expect(reloaded.isSet(programmeChannel, show), isTrue);
    expect(reloaded.isSet(programmeChannel.copyWith(id: 'other::one'), show),
        isFalse);
    expect(storage.getProgrammeReminders(), isNot(contains('https:')));
    expect(
        storage
            .exportForTransfer()
            .keys
            .any((k) => k.startsWith(AppConstants.keyProgrammeReminders)),
        isFalse);
    expect(await service.toggle(programmeChannel, show), isFalse);
    expect(service.nextDeadline, isNull);
    reloaded.dispose();
  });
  test(
      'five-minute and start notices fire once; delivered flags survive reload',
      () async {
    await service.toggle(programmeChannel, show);
    expect(
        service.nextDeadline, show.start.subtract(const Duration(minutes: 5)));
    time = show.start.subtract(const Duration(minutes: 5));
    expect(service.poll().single.atStart, isFalse);
    expect(service.poll(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    final reload = ProgrammeReminders(storage, now: () => time);
    expect(reload.poll(), isEmpty);
    reload.dispose();
    time = show.start;
    expect(service.poll().single.atStart, isTrue);
    expect(service.poll(), isEmpty);
    time = show.start.add(const Duration(minutes: 3));
    expect(service.poll(), isEmpty);
    expect(service.nextDeadline, isNull);
    await Future<void>.delayed(Duration.zero);
  });
  test(
      'recent selection skips a late early notice; resume never replays stale notices',
      () async {
    show = programme(time.add(const Duration(minutes: 2)));
    await service.toggle(programmeChannel, show);
    expect(service.nextDeadline, show.start);
    expect(service.poll(), isEmpty);
    time = show.start.add(const Duration(minutes: 3));
    expect(service.poll(), isEmpty);
    await Future<void>.delayed(Duration.zero);
  });
  test('viewer switching isolates reminders and restores the original viewer',
      () async {
    await service.toggle(programmeChannel, show);
    final first = storage.getActiveViewerId();
    await storage.setActiveViewerId('other');
    service.loadViewer();
    expect(service.isSet(programmeChannel, show), isFalse);
    await storage.setActiveViewerId(first);
    service.loadViewer();
    expect(service.isSet(programmeChannel, show), isTrue);
  });
  test('rejects started/invalid programmes and rolls back failed persistence',
      () async {
    expect(service.toggle(programmeChannel, programme(time)), throwsStateError);
    expect(
        service.toggle(programmeChannel,
            programme(time.add(const Duration(minutes: 1)), minutes: 0)),
        throwsStateError);
    final failing = _FailingStorage();
    await failing.init();
    final reminders = ProgrammeReminders(failing, now: () => time);
    await expectLater(
        reminders.toggle(programmeChannel, show), throwsStateError);
    expect(reminders.isSet(programmeChannel, show), isFalse);
    reminders.dispose();
  });
}
