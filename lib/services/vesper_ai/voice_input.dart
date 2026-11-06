import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

/// One thing the recognizer reported ([VoiceInput.listen]).
class VoiceEvent {
  const VoiceEvent(this.type, {this.text = '', this.level = 0, this.code});

  /// 'ready', 'partial', 'final', 'level', 'error' or 'end'.
  final String type;
  final String text;
  final double level;

  /// For 'error': nomatch, network, permission, audio, busy, unavailable.
  final String? code;
}

/// Android's speech recognizer and text-to-speech (VoiceBridge.kt). On Fire
/// TV and Windows there is none: the viewer types or talks from the phone.
class VoiceInput {
  VoiceInput._();
  static final instance = VoiceInput._();

  static const _channel = MethodChannel('vespertv/voice');
  static const _events = EventChannel('vespertv/voice/events');

  Stream<VoiceEvent>? _stream;
  bool? _available;

  /// Settings > Vesper AI > Read replies aloud (set by the app).
  bool Function() speakReplies = () => false;

  /// The assistant launch ([VoiceBridge.onIntent]): called while running.
  VoidCallback? onAssist;

  bool _handlerSet = false;
  void _ensureHandler() {
    if (_handlerSet || !Platform.isAndroid) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'assist' && await takeAssist()) onAssist?.call();
      return null;
    });
  }

  /// True once when VesperTV was started / brought up as the assistant.
  Future<bool> takeAssist() async {
    if (!Platform.isAndroid) return false;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<bool>('takeAssist') ?? false;
    } catch (_) {
      return false;
    }
  }

  void start() => _ensureHandler();

  Future<bool> get available async {
    if (!Platform.isAndroid) return false;
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return false;
    try {
      if (await _channel.invokeMethod<bool>('hasPermission') ?? false) {
        return true;
      }
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The recognizer's language: the app's ("fr"), as a recognizer reads it.
  static String get language => switch (L10n.code) {
        'fr' => 'fr-CA',
        'es' => 'es-ES',
        'it' => 'it-IT',
        'de' => 'de-DE',
        'el' => 'el-GR',
        _ => 'en-US',
      };

  /// Listens once (until a pause, or [stop]); events end with 'end'.
  Stream<VoiceEvent> listen() {
    final controller = StreamController<VoiceEvent>();
    StreamSubscription<dynamic>? sub;
    controller.onListen = () {
      _stream ??= _events.receiveBroadcastStream().map((raw) {
        final m = raw is Map ? raw : const {};
        return VoiceEvent('${m['type'] ?? ''}',
            text: '${m['text'] ?? ''}',
            level: (m['value'] as num?)?.toDouble() ?? 0,
            code: m['code'] as String?);
      }).asBroadcastStream();
      sub = _stream!.listen((e) {
        if (controller.isClosed) return;
        controller.add(e);
        if (e.type == 'end') {
          sub?.cancel();
          controller.close();
        }
      });
      _channel.invokeMethod<void>('start', {'lang': language}).catchError((_) {
        if (!controller.isClosed) {
          controller.add(const VoiceEvent('error', code: 'unavailable'));
          controller.add(const VoiceEvent('end'));
          controller.close();
        }
      });
    };
    controller.onCancel = () {
      sub?.cancel();
      unawaited(cancel());
    };
    return controller.stream;
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!Platform.isAndroid || text.trim().isEmpty) return;
    try {
      await _channel
          .invokeMethod<void>('speak', {'text': text, 'lang': language});
    } catch (e) {
      debugPrint('VoiceInput: speak failed: $e');
    }
  }

  Future<void> speakIfWanted(String text) async {
    if (speakReplies()) await speak(text);
  }

  Future<void> stopSpeaking() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopSpeaking');
    } catch (_) {}
  }
}
