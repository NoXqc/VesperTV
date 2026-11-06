import 'dart:convert';

import 'package:http/http.dart' as http;

import 'anthropic_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';
import 'vesper_tools.dart';

/// Runs one tool for the model and returns what to hand back to it.
typedef VesperToolRunner = Future<Map<String, Object?>> Function(
    String name, Map<String, Object?> args);

/// A failure the viewer should read (wrong key, quota, offline).
class AiProviderError implements Exception {
  AiProviderError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The viewer's own AI (Settings > Vesper AI > Your AI). Each provider keeps
/// its conversation in its own wire format, append-only, and runs the tool
/// loop itself: [send] returns the final words to show / say.
abstract class AiProvider {
  /// 'anthropic', 'openai' or 'gemini'.
  String get id;

  /// Sends the viewer's [text]; tools are run through [runTool] as the
  /// model asks for them (at most [maxRounds] rounds).
  Future<String> send(String text,
      {required String system,
      required List<VesperTool> tools,
      required VesperToolRunner runTool,
      int maxRounds = 8});

  /// Forgets the conversation (a new one starts with the next [send]).
  void reset();

  static AiProvider? fromSettings(
      {required String? provider,
      required String? model,
      required String? apiKey,
      required String? baseUrl,
      http.Client? client}) {
    final key = apiKey?.trim() ?? '';
    final m = model?.trim() ?? '';
    switch (provider) {
      case 'anthropic':
        if (key.isEmpty) return null;
        return AnthropicProvider(
            apiKey: key,
            model: m.isEmpty ? AnthropicProvider.defaultModel : m,
            client: client);
      case 'openai':
        final base = (baseUrl?.trim().isNotEmpty ?? false)
            ? baseUrl!.trim()
            : OpenAiProvider.defaultBaseUrl;
        // A local server (Ollama, LM Studio) needs no key; OpenAI does.
        if (m.isEmpty ||
            (key.isEmpty && base == OpenAiProvider.defaultBaseUrl)) {
          return null;
        }
        return OpenAiProvider(
            apiKey: key, model: m, baseUrl: base, client: client);
      case 'gemini':
        if (key.isEmpty) return null;
        return GeminiProvider(
            apiKey: key,
            model: m.isEmpty ? GeminiProvider.defaultModel : m,
            client: client);
    }
    return null;
  }
}

/// A tool result as the text a model reads.
String toolResultText(Map<String, Object?> result) => jsonEncode(result);

/// Plain words for an HTTP failure; never includes the key or the body.
AiProviderError httpError(String provider, http.Response res) {
  final code = res.statusCode;
  String detail = '';
  try {
    final body = jsonDecode(res.body);
    final err = body is Map ? body['error'] : null;
    final msg = err is Map ? err['message'] : (err is String ? err : null);
    if (msg is String) {
      detail = msg.length > 160 ? '${msg.substring(0, 160)}…' : msg;
    }
  } catch (_) {}
  final words = switch (code) {
    400 => 'The AI could not read the request',
    401 || 403 => 'The AI key was refused',
    404 => 'The AI model was not found (check its name)',
    429 => 'The AI is busy or out of credit, try again later',
    >= 500 => 'The AI service is having trouble, try again later',
    _ => 'The AI answered with an error',
  };
  return AiProviderError(
      '$words ($provider HTTP $code${detail.isEmpty ? '' : ': $detail'}).');
}
