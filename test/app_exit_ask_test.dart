import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_exit.dart';

import 'warm_exit_helper.dart';

// Settings > Ask before exiting (Discord request, 2026-11-13): older viewers
// left the app with one Back too many. Off = Android leaves at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppExit.askFirst = () => false);

  test('off: Back leaves at once, nothing asked', () async {
    final exits = recordWarmExits();
    var asked = 0;
    await AppExit.back(() async {
      asked++;
      return false;
    });
    expect(asked, 0);
    expect(exits, ['warm']);
  });

  test('on: Stay keeps the app, Exit leaves (warm)', () async {
    final exits = recordWarmExits();
    AppExit.askFirst = () => true;
    var asked = 0;
    await AppExit.back(() async {
      asked++;
      return false;
    });
    expect(asked, 1);
    expect(exits, isEmpty);
    await AppExit.back(() async => true);
    expect(exits, ['warm']);
  });
}
