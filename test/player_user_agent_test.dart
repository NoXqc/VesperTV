import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/player_user_agent.dart';
import 'package:nox_iptv/widgets/native_video_hole.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:video_player_android/video_player_android.dart';

/// Owner, 2026-11-25: Tuliprox's player column named other apps (iMPlayer,
/// TiviMate) and "ExoPlayer" for VesperTV. The Android player now says
/// VesperTV, on the first play and on a native channel change alike.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AndroidVideoPlayer.defaultUserAgent = 'ExoPlayer');

  test('names VesperTV and its version, keeps the ExoPlayer token', () async {
    PackageInfo.setMockInitialValues(
        appName: 'VesperTV',
        packageName: 'com.nox.nox_iptv',
        version: '1.0.74-dev.999',
        buildNumber: '999',
        buildSignature: '');
    expect(AndroidVideoPlayer.defaultUserAgent, 'ExoPlayer');
    await PlayerUserAgent.init();
    expect(PlayerUserAgent.value,
        'VesperTV/1.0.74-dev.999 (Linux; Android) ExoPlayerLib/1.9.2');
    expect(AndroidVideoPlayer.defaultUserAgent, PlayerUserAgent.value);
    expect(PlayerUserAgent.value, startsWith('VesperTV/'));
    expect(PlayerUserAgent.value, contains('ExoPlayerLib/'));
  });

  test('a native channel change sends the same User-Agent', () async {
    AndroidVideoPlayer.defaultUserAgent = PlayerUserAgent.forVersion('1.0.74');
    Map<Object?, Object?>? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/native_surface'), (call) async {
      if (call.method == 'replaceLive') {
        sent = call.arguments as Map<Object?, Object?>;
      }
      return {'accepted': true};
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/native_surface'), null));
    await NativeVideoSurface.replaceLive(3, 'http://x/live/1.ts', hls: false);
    expect(sent?['userAgent'],
        'VesperTV/1.0.74 (Linux; Android) ExoPlayerLib/1.9.2');
  });
}
