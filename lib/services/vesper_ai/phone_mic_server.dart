import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../l10n/l10n.dart';
import '../phone_pairing_service.dart' show privateLanIpv4;
import '../storage_service.dart';
import 'vesper_ai.dart';

/// "Talk from my phone" on the same Wi-Fi: the TV serves
/// assets/vesper_ai/phone.html at `http://<tv-ip>:8931/v/<token>` and the
/// phone POSTs what was said (typed, or the phone keyboard's microphone) to
/// `/v/<token>/say`; the answer goes back to the phone and on the TV.
///
/// The token is kept per device so a bookmark keeps working; nothing
/// leaves the home network. Stopped after an hour without use.
class PhoneMicServer {
  PhoneMicServer._();
  static final instance = PhoneMicServer._();

  static const preferredPort = 8931;
  static const idleLimit = Duration(hours: 1);

  HttpServer? _server;
  String? _url;
  String? _page;
  String? _token;
  Timer? _idle;
  bool _busy = false;

  /// The phone address, or null when the TV has no Wi-Fi / LAN address.
  String? get url => _url;

  Future<String?> start(StorageService storage) async {
    _touch();
    if (_server != null) return _url;
    _page ??= await rootBundle.loadString('assets/vesper_ai/phone.html');
    _token = storage.getAiPhoneToken();
    if (_token == null || _token!.length < 10) {
      _token = _randomToken(12);
      await storage.setAiPhoneToken(_token!);
    }
    final ip = await privateLanIpv4();
    if (ip == null) return null;
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } catch (_) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      } catch (e) {
        debugPrint('PhoneMic: could not open the local server: $e');
        return null;
      }
    }
    _server = server;
    _url = 'http://${ip.address}:${server.port}/v/$_token';
    server.listen(_handle, onError: (Object e) {
      debugPrint('PhoneMic: server error $e');
    });
    return _url;
  }

  Future<void> stop() async {
    _idle?.cancel();
    final server = _server;
    _server = null;
    _url = null;
    await server?.close(force: true);
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(idleLimit, stop);
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Cache-Control', 'no-store')
      ..set('Referrer-Policy', 'no-referrer')
      ..set('X-Content-Type-Options', 'nosniff');
    try {
      final base = '/v/$_token';
      if (req.method == 'GET' && req.uri.path == base) {
        _touch();
        res.headers.contentType = ContentType.html;
        res.write(_page ?? '');
        return;
      }
      if (req.method == 'POST' && req.uri.path == '$base/say') {
        _touch();
        final body = await _readLimited(req, 4096);
        final text = _textOf(body);
        if (text == null) {
          res.statusCode = HttpStatus.badRequest;
          return;
        }
        if (_busy) {
          res.statusCode = HttpStatus.tooManyRequests;
          return;
        }
        _busy = true;
        try {
          final reply = await askFromPhone(text);
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({'reply': reply}));
        } finally {
          _busy = false;
        }
        return;
      }
      res.statusCode = HttpStatus.notFound;
    } catch (_) {
      res.statusCode = HttpStatus.internalServerError;
    } finally {
      await res.close();
    }
  }

  static String? _textOf(String? body) {
    if (body == null) return null;
    try {
      final json = jsonDecode(body);
      final text = json is Map ? json['text'] : null;
      if (text is! String) return null;
      final t = text.trim();
      if (t.isEmpty || t.length > 500) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readLimited(HttpRequest req, int max) async {
    final bytes = <int>[];
    await for (final chunk in req.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > max) return null;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _randomToken(int n) {
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random.secure();
    return List.generate(n, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }
}

/// What the phone said, asked on the TV: shown there too, so whoever sits
/// in front of the TV sees what changed and why.
Future<String> askFromPhone(String text) async {
  final reply = await VesperAi.instance.ask(text);
  final shown = reply.text.isEmpty ? '"$text"' : '"$text" · ${reply.text}';
  VesperAi.instance.showBubble(shown, from: tr('Phone'), spoken: reply.text);
  return reply.text.isEmpty ? tr('Done') : reply.text;
}
