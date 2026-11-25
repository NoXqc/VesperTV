import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_log.dart';

// GitHub #20 (Apple TV 968): every movie closed the app and the log ended
// before it. A step is written at once to its own file so the next session
// can say where the app was.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vesper_step_');
    file = File('${dir.path}/vespertv_step.txt');
    AppLog.stepFileForTest = file;
  });

  tearDown(() {
    AppLog.stepFileForTest = null;
    dir.deleteSync(recursive: true);
  });

  test('a step is on disk at once and named by the next session', () async {
    AppLog.step('DisplayMatch: asked the TV for 23.976 Hz');
    expect(file.readAsStringSync(),
        endsWith(' DisplayMatch: asked the TV for 23.976 Hz'));

    expect(await AppLog.takeLastStep(file),
        endsWith('DisplayMatch: asked the TV for 23.976 Hz'));
    expect(file.existsSync(), isFalse);
    expect(await AppLog.takeLastStep(file), isNull);
  });

  test('a finished step leaves nothing', () async {
    final id = AppLog.step('Player: opening a movie / episode on Apple TV');
    AppLog.stepDone(id);
    expect(await AppLog.takeLastStep(file), isNull);
  });

  test('the latest step wins; finishing an older one keeps it', () async {
    final opening =
        AppLog.step('Player: opening a movie / episode on Apple TV');
    AppLog.step('DisplayMatch: asked the TV for 23.976 Hz');
    AppLog.stepDone(opening);
    expect(await AppLog.takeLastStep(file), contains('DisplayMatch'));
  });
}
