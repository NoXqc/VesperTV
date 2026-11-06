import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';
import 'vesper_tools.dart';

/// Any OpenAI-compatible chat API with the viewer's own key: OpenAI itself,
/// or another base URL (OpenRouter, Groq, Mistral, a local Ollama or LM
/// Studio on the home network). `POST {base}/chat/completions` with
/// function tools.
class OpenAiProvider extends AiProvider {
  OpenAiProvider(
      {required this.apiKey,
      required this.model,
      required String baseUrl,
      http.Client? client})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = client ?? http.Client();

  static const defaultBaseUrl = 'https://api.openai.com/v1';

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;
  final List<Map<String, Object?>> _messages = [];

  @override
  String get id => 'openai';

  @override
  void reset() => _messages.clear();

  @override
  Future<String> send(String text,
      {required String system,
      required List<VesperTool> tools,
      required VesperToolRunner runTool,
      int maxRounds = 8}) async {
    _messages.add({'role': 'user', 'content': text});
    try {
      for (var round = 0; round < maxRounds; round++) {
        final message = await _post(system, tools);
        _messages.add(message);
        final calls = (message['tool_calls'] as List?) ?? const [];
        if (calls.isEmpty) {
          final words = '${message['content'] ?? ''}'.trim();
          return words.isEmpty ? 'Done.' : words;
        }
        for (final call in calls) {
          if (call is! Map) continue;
          final fn = call['function'];
          final name = fn is Map ? '${fn['name'] ?? ''}' : '';
          Map<String, Object?> args = const {};
          try {
            final raw = fn is Map ? fn['arguments'] : null;
            final decoded =
                raw is String && raw.trim().isNotEmpty ? jsonDecode(raw) : raw;
            if (decoded is Map) args = decoded.cast<String, Object?>();
          } catch (_) {
            args = const {};
          }
          final result = await runTool(name, args);
          _messages.add({
            'role': 'tool',
            'tool_call_id': call['id'],
            'content': toolResultText(result),
          });
        }
      }
      reset();
      return 'That took too many steps.';
    } catch (e) {
      reset();
      rethrow;
    }
  }

  Future<Map<String, Object?>> _post(
      String system, List<VesperTool> tools) async {
    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        ..._messages,
      ],
      'tools': [
        for (final t in tools)
          {
            'type': 'function',
            'function': {
              'name': t.name,
              'description': t.description,
              'parameters': t.schema,
            },
          }
      ],
    };
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$baseUrl/chat/completions'),
              headers: {
                'content-type': 'application/json',
                if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw AiProviderError('The AI took too long to answer.');
    } catch (_) {
      throw AiProviderError('Could not reach the AI (check the address).');
    }
    if (res.statusCode != 200) throw httpError('AI', res);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    final choices = json is Map ? json['choices'] : null;
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map ? first['message'] : null;
    if (message is! Map) throw AiProviderError('The AI sent an empty answer.');
    // Kept as sent (content null with tool calls is valid to send back).
    return {
      'role': 'assistant',
      'content': message['content'],
      if (message['tool_calls'] is List) 'tool_calls': message['tool_calls'],
    };
  }
}
