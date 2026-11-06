import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../phone_pairing_service.dart' show kPairRelayBase, kRelayAppHeaders;
import '../storage_service.dart';
import 'phone_mic_server.dart' show askFromPhone;
import 'vesper_ai.dart';
import 'vesper_tools.dart';

/// Settings > Vesper AI > AI apps: the viewer's own AI app (Claude,
/// ChatGPT, any MCP client) drives VesperTV through the relay
/// (tools/pair_relay/ai_link.py). The app adds the connector URL
/// [connectorUrl]; while VesperTV is open and the link is on, this polls the
/// relay for the app's requests, runs them with [VesperToolbox] (as
/// [VesperCaller.remoteApp]: plays and changes are confirmed on the TV) and
/// posts the answers back. The phone page on the relay ([phoneUrl]) uses
/// the same link with `vesper/say`.
///
/// Only the link's SHA-256 is known to the relay; the secret stays on this
/// device (never transferred or synced). Reset makes a new one.
class McpBridge {
  McpBridge._();
  static final instance = McpBridge._();

  StorageService? _storage;
  http.Client _client = http.Client();
  bool _running = false;
  int _generation = 0;

  /// For Settings: when the relay last answered a poll (null = never).
  final lastContact = ValueNotifier<DateTime?>(null);

  /// The last AI-app tool calls (Settings shows them), newest first.
  final activity = ValueNotifier<List<String>>(const []);

  @visibleForTesting
  set client(http.Client c) => _client = c;

  void attach(StorageService storage) {
    _storage = storage;
    if (storage.getAiLinkEnabled()) start();
  }

  bool get enabled => _storage?.getAiLinkEnabled() ?? false;

  String? get _secret => _storage?.getAiLinkSecret();

  String? get connectorUrl {
    final s = _secret;
    return s == null || !enabled ? null : '$kPairRelayBase/mcp/$s';
  }

  String? get phoneUrl {
    final s = _secret;
    return s == null || !enabled ? null : '$kPairRelayBase/ai#$s';
  }

  static String newSecret() {
    final rng = Random.secure();
    return base64Url
        .encode(List<int>.generate(32, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> setEnabled(bool on) async {
    final storage = _storage;
    if (storage == null) return;
    if (on && storage.getAiLinkSecret() == null) {
      await storage.setAiLinkSecret(newSecret());
    }
    await storage.setAiLinkEnabled(on);
    on ? start() : stop();
  }

  /// A new secret: every AI app / phone using the old address stops working.
  Future<void> reset() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.setAiLinkSecret(newSecret());
    stop();
    if (enabled) start();
  }

  void start() {
    if (_running || _secret == null) return;
    _running = true;
    final gen = ++_generation;
    unawaited(_loop(gen));
  }

  void stop() {
    _running = false;
    _generation++;
  }

  /// Pauses while the app is in the background (the long-poll would keep the
  /// radio awake); [resume] picks it up again.
  void pause() => stop();
  void resume() {
    if (enabled) start();
  }

  Future<void> _loop(int gen) async {
    var failures = 0;
    while (_running && gen == _generation) {
      final secret = _secret;
      if (secret == null) break;
      try {
        final res = await _client.get(Uri.parse('$kPairRelayBase/api/ai/poll'),
            headers: {
              ...kRelayAppHeaders,
              'X-Vesper-Link': secret
            }).timeout(const Duration(seconds: 40));
        if (gen != _generation) break;
        failures = 0;
        lastContact.value = DateTime.now();
        if (res.statusCode == 200) {
          final item = jsonDecode(utf8.decode(res.bodyBytes));
          if (item is Map && item['id'] is String && item['msg'] is Map) {
            // Answered in the background: the next poll starts at once.
            unawaited(_answer(secret, item['id'] as String,
                (item['msg'] as Map).cast<String, Object?>()));
          }
        } else if (res.statusCode != 204) {
          failures++;
        }
      } catch (e) {
        failures++;
      }
      if (failures > 0) {
        // Offline or relay down: back off up to a minute.
        await Future<void>.delayed(
            Duration(seconds: min(60, 2 << min(failures, 5))));
      }
    }
  }

  Future<void> _answer(
      String secret, String id, Map<String, Object?> msg) async {
    Map<String, Object?> reply;
    try {
      reply = await handle(msg);
    } catch (e) {
      reply = {
        'error': {'code': -32603, 'message': 'VesperTV failed: $e'}
      };
    }
    try {
      await _client
          .post(Uri.parse('$kPairRelayBase/api/ai/reply'),
              headers: {
                ...kRelayAppHeaders,
                'X-Vesper-Link': secret,
                'content-type': 'application/json',
              },
              body: jsonEncode({'id': id, 'msg': reply}))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('McpBridge: reply failed: $e');
    }
  }

  void _log(String line) {
    final list = [line, ...activity.value];
    activity.value = list.take(8).toList();
  }

  /// One JSON-RPC request from the relay -> `{"result"}` or `{"error"}`.
  @visibleForTesting
  Future<Map<String, Object?>> handle(Map<String, Object?> msg) async {
    final method = msg['method'];
    final params = msg['params'] is Map
        ? (msg['params'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final box = VesperAi.instance.toolbox;
    if (box == null) {
      return {
        'error': {'code': -32000, 'message': 'VesperTV is still starting.'}
      };
    }
    switch (method) {
      case 'tools/list':
        return {
          'result': {
            'tools': [
              for (final t in box.tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'inputSchema': t.schema,
                }
            ],
          }
        };
      case 'tools/call':
        final name = '${params['name'] ?? ''}';
        final args = params['arguments'] is Map
            ? (params['arguments'] as Map).cast<String, Object?>()
            : const <String, Object?>{};
        _log('${_clock()} $name');
        final result =
            await box.call(name, args, caller: VesperCaller.remoteApp);
        return {
          'result': {
            'content': [
              {'type': 'text', 'text': jsonEncode(result)}
            ],
            'structuredContent': result,
            if (result.containsKey('error')) 'isError': true,
          }
        };
      case 'vesper/say':
        // The relay phone page (not a tool: AI apps never see it).
        final text = '${params['text'] ?? ''}'.trim();
        if (text.isEmpty || text.length > 500) {
          return {
            'error': {'code': -32602, 'message': 'Say something.'}
          };
        }
        _log('${_clock()} phone');
        return {
          'result': {'reply': await askFromPhone(text)}
        };
    }
    return {
      'error': {'code': -32601, 'message': 'Method not found: $method'}
    };
  }

  static String _clock() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}
