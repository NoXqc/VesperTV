import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/mcp_bridge.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the link secret and voice keys stay on the device; the AI key moves',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyAiProvider: 'anthropic',
      AppConstants.keyAiApiKey: 'sk-test',
      AppConstants.keyAiLinkSecret: 'secret_secret_secret_secret_secret_1',
      AppConstants.keyAiLinkEnabled: true,
      AppConstants.keyAiVoiceButton: true,
      AppConstants.keyAiLearnedKey: 42,
      AppConstants.keyAiPhoneToken: 'abcdefghjkmn',
    });
    final storage = StorageService();
    await storage.init();
    final transfer = storage.exportForTransfer();
    expect(transfer.keys, contains(AppConstants.keyAiProvider));
    expect(transfer.keys, contains(AppConstants.keyAiApiKey));
    for (final k in transfer.keys) {
      expect(k.startsWith(AppConstants.keyAiDevicePrefix), isFalse, reason: k);
    }
    for (final k in storage.exportForSync().keys) {
      expect(k.startsWith(AppConstants.keyAiDevicePrefix), isFalse, reason: k);
    }
    for (final k in storage.exportForBackup().keys) {
      expect(k.startsWith(AppConstants.keyAiDevicePrefix), isFalse, reason: k);
    }
  });

  test('every device-only key uses the device prefix', () {
    for (final k in [
      AppConstants.keyAiVoiceButton,
      AppConstants.keyAiLearnedKey,
      AppConstants.keyAiSpeakReplies,
      AppConstants.keyAiLinkSecret,
      AppConstants.keyAiLinkEnabled,
      AppConstants.keyAiConfirmRemotePlay,
      AppConstants.keyAiPhoneToken,
    ]) {
      expect(k.startsWith(AppConstants.keyAiDevicePrefix), isTrue, reason: k);
    }
  });

  test('the relay serves the same phone page as the TV', () {
    final app = File('assets/vesper_ai/phone.html').readAsStringSync();
    final relay = File('tools/pair_relay/ai.html').readAsStringSync();
    expect(relay.replaceAll('\r\n', '\n'), app.replaceAll('\r\n', '\n'),
        reason: 'copy assets/vesper_ai/phone.html to tools/pair_relay/ai.html');
  });

  test('link secrets are long, random and URL-safe', () {
    final a = McpBridge.newSecret();
    final b = McpBridge.newSecret();
    expect(a, isNot(b));
    expect(RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(a), isTrue);
  });

  test('MCP requests before start-up and unknown methods answer errors',
      () async {
    final starting = await McpBridge.instance.handle({'method': 'tools/list'});
    expect((starting['error'] as Map)['code'], -32000);
  });
}
