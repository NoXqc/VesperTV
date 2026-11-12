import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/remote_buttons.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android's Bookmark key on the Homatics remote arrives as a key Flutter
/// has no name for (0x11 << 32 | keycode).
const _bookmarkId = 0x11000000ae;
const _bookmark = LogicalKeyboardKey(_bookmarkId);
const _bookmarkPhysical = PhysicalKeyboardKey(0x700a0);

KeyDownEvent _down(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
        physicalKey: physical, logicalKey: key, timeStamp: Duration.zero);
KeyRepeatEvent _repeat(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    KeyRepeatEvent(
        physicalKey: physical, logicalKey: key, timeStamp: Duration.zero);
KeyUpEvent _up(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    KeyUpEvent(
        physicalKey: physical, logicalKey: key, timeStamp: Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late List<String> ran;
  final buttons = RemoteButtons.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    ran = [];
    buttons
      ..attach(storage)
      ..isActive = (() => true)
      ..learning = null
      ..runner = (action) async => ran.add(action);
    await buttons.reset();
  });

  test('a short-only button fires on the way down and takes the release',
      () async {
    await buttons
        .saveBinding(const RemoteBinding(keyId: _bookmarkId, short: 'guide'));
    expect(buttons.handle(_down(_bookmark, _bookmarkPhysical)), isTrue);
    expect(ran, ['guide']);
    expect(buttons.handle(_repeat(_bookmark, _bookmarkPhysical)), isTrue);
    expect(buttons.handle(_up(_bookmark, _bookmarkPhysical)), isTrue);
    expect(ran, ['guide']);
  });

  test(
      'with a hold: a tap runs the short press on release, a hold only '
      'the hold', () async {
    await buttons.saveBinding(const RemoteBinding(
        keyId: _bookmarkId, short: 'favourites', hold: 'record'));
    buttons.handle(_down(_bookmark, _bookmarkPhysical));
    expect(ran, isEmpty);
    buttons.handle(_up(_bookmark, _bookmarkPhysical));
    expect(ran, ['favourites']);

    ran.clear();
    buttons.handle(_down(_bookmark, _bookmarkPhysical));
    buttons.handle(_repeat(_bookmark, _bookmarkPhysical));
    buttons.handle(_repeat(_bookmark, _bookmarkPhysical));
    buttons.handle(_up(_bookmark, _bookmarkPhysical));
    expect(ran, ['record']);
  });

  test('a hold-only button does nothing on a tap', () async {
    await buttons
        .saveBinding(const RemoteBinding(keyId: _bookmarkId, hold: 'stop'));
    expect(buttons.handle(_down(_bookmark, _bookmarkPhysical)), isTrue);
    buttons.handle(_up(_bookmark, _bookmarkPhysical));
    expect(ran, isEmpty);
  });

  test('OK, Back and the arrows are never taken, unknown keys pass', () async {
    for (final (key, physical) in [
      (LogicalKeyboardKey.select, PhysicalKeyboardKey.select),
      (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
      (LogicalKeyboardKey.goBack, PhysicalKeyboardKey.escape),
    ]) {
      expect(buttons.handle(_down(key, physical)), isFalse);
      expect(buttons.handle(_up(key, physical)), isFalse);
    }
    expect(buttons.handle(_down(_bookmark, _bookmarkPhysical)), isFalse);
    expect(buttons.handle(_up(_bookmark, _bookmarkPhysical)), isFalse);
  });

  test('nothing is taken while the app is not ready', () async {
    await buttons
        .saveBinding(const RemoteBinding(keyId: _bookmarkId, short: 'guide'));
    buttons.isActive = () => false;
    expect(buttons.handle(_down(_bookmark, _bookmarkPhysical)), isFalse);
    expect(ran, isEmpty);
  });

  test('learn mode takes the pressed key and its release, not OK', () async {
    KeyDownEvent? learned;
    buttons.learning = (e) => learned = e;
    expect(
        buttons.handle(
            _down(LogicalKeyboardKey.select, PhysicalKeyboardKey.select)),
        isFalse);
    expect(learned, isNull);
    expect(buttons.handle(_down(_bookmark, _bookmarkPhysical)), isTrue);
    expect(learned?.logicalKey.keyId, _bookmarkId);
    buttons.learning = null;
    expect(buttons.handle(_up(_bookmark, _bookmarkPhysical)), isTrue);
    expect(ran, isEmpty);
  });

  test(
      'buttons and arrows are per viewer, kept by a backup, never '
      'transferred', () async {
    await buttons
        .saveBinding(const RemoteBinding(keyId: _bookmarkId, short: 'guide'));
    await buttons.setArrow(PlayerArrow.right, 'panel');
    expect(buttons.arrowAction(PlayerArrow.right), 'panel');
    expect(buttons.arrowAction(PlayerArrow.left), 'panel');
    expect(buttons.arrowAction(PlayerArrow.up), 'channel_up');

    final transfer = storage.exportForTransfer().keys;
    expect(transfer.any((k) => k.startsWith(AppConstants.keyRemoteButtons)),
        isFalse);
    expect(transfer.any((k) => k.startsWith(AppConstants.keyPlayerArrows)),
        isFalse);
    final backup = storage.exportForBackup().keys;
    expect(backup, contains(AppConstants.keyRemoteButtons));
    expect(backup, contains(AppConstants.keyPlayerArrows));

    await storage.setActiveViewerId('kid');
    expect(buttons.bindings, isEmpty);
    expect(buttons.arrowAction(PlayerArrow.right), 'last');
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    expect(buttons.bindingFor(_bookmarkId)?.short, 'guide');
  });

  test('choosing the default arrow back stores nothing', () async {
    await buttons.setArrow(PlayerArrow.down, 'none');
    expect(storage.getPlayerArrows(), isNotNull);
    await buttons.setArrow(PlayerArrow.down, 'channel_down');
    expect(storage.getPlayerArrows(), isNull);
    expect(buttons.isCustomised, isFalse);
  });

  test('stored JSON with unknown actions is dropped', () {
    final decoded = RemoteButtons.decodeBindings(
        '{"$_bookmarkId": {"s": "guide", "h": "teleport"}, "x": {"s": "stop"}}');
    expect(decoded.keys, [_bookmarkId]);
    expect(decoded[_bookmarkId]?.hold, isNull);
    expect(RemoteButtons.decodeArrows('{"left": "fly", "up": "bar"}'),
        {PlayerArrow.up: 'bar'});
  });

  test('button names', () {
    expect(
        RemoteButtons.describe(LogicalKeyboardKey.channelUp.keyId).$1, 'CH+');
    expect(RemoteButtons.describe(_bookmarkId), (null, '#174'));
  });
}
