import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';
import 'vesper_tools.dart';

/// Claude with the viewer's own Anthropic API key (console.anthropic.com).
///
/// Raw HTTP on `POST /v1/messages`: there is no official Anthropic SDK for
/// Dart. The conversation is append-only — each response's `content` goes
/// back unchanged (thinking blocks included), tool results all in one user
/// message per round.
class AnthropicProvider extends AiProvider {
  AnthropicProvider(
      {required this.apiKey, required this.model, http.Client? client})
      : _client = client ?? http.Client();

  static const defaultModel = 'claude-opus-5-5';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _version = '2026-10-21';

  /// The models a viewer can pick from in Settings (any other id works too).
  static const suggestedModels = [
    'claude-opus-5-5',
    'claude-sonnet-5-5',
    'claude-haiku-5-5',
  ];

  final String apiKey;
  final String model;
  final http.Client _client;
  final List<Map<String, Object?>> _messages = [];

  @override
  String get id => 'anthropic';

  @override
  void reset() => _messages.clear();

  /// `output_config.effort` exists on these families; a voice request wants
  /// a quick, short answer, so `low`.
  bool get _hasEffort =>
      RegExp(r'^claude-(opus|sonnet|haiku|fable|mythos)-(5|4-[678])')
          .hasMatch(model);

  /// Server-side refusal fallback (`fallbacks: "default"`): on a safety
  /// decline the API re-runs the request on a fallback model in the same
  /// call. Only the families that accept it.
  bool get _hasFallbacks =>
      RegExp(r'^claude-(opus-5|fable-5-1|sonnet-5-5)').hasMatch(model);

  @override
  Future<String> send(String text,
      {required String system,
      required List<VesperTool> tools,
      required VesperToolRunner runTool,
      int maxRounds = 8}) async {
    _messages.add({'role': 'user', 'content': text});
    try {
      for (var round = 0; round < maxRounds; round++) {
        final response = await _post(system, tools);
        final content = (response['content'] as List?) ?? const [];
        _messages.add({'role': 'assistant', 'content': content});
        final stop = response['stop_reason'];
        if (stop == 'refusal') {
          return 'Claude declined that request.';
        }
        final calls = [
          for (final b in content)
            if (b is Map && b['type'] == 'tool_use') b
        ];
        if (stop != 'tool_use' || calls.isEmpty) {
          final words = _text(content);
          if (words.isNotEmpty) return words;
          return stop == 'max_tokens' ? 'That answer was too long.' : 'Done.';
        }
        final results = <Map<String, Object?>>[];
        for (final call in calls) {
          final input = call['input'];
          final result = await runTool(call['name'] as String? ?? '',
              input is Map ? input.cast<String, Object?>() : const {});
          results.add({
            'type': 'tool_result',
            'tool_use_id': call['id'],
            'content': toolResultText(result),
            if (result.containsKey('error')) 'is_error': true,
          });
        }
        _messages.add({'role': 'user', 'content': results});
      }
      // Out of rounds while still calling tools: the history now ends with
      // tool results, so the next request would continue that; start over.
      reset();
      return 'That took too many steps.';
    } catch (e) {
      // A failed request can leave a tool call without its result.
      reset();
      rethrow;
    }
  }

  Future<Map<String, Object?>> _post(
      String system, List<VesperTool> tools) async {
    final body = <String, Object?>{
      'model': model,
      'max_tokens': 16000,
      'system': system,
      'tools': [
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'input_schema': t.schema,
          }
      ],
      'messages': _messages,
      // Tools + system stay the same: cached after the first request.
      'cache_control': {'type': 'ephemeral'},
      if (_hasEffort) 'output_config': {'effort': 'low'},
      if (_hasFallbacks) 'fallbacks': 'default',
    };
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse(_endpoint),
              headers: {
                'content-type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': _version,
                if (_hasFallbacks)
                  'anthropic-beta': 'server-side-fallback-2026-07-01',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw AiProviderError('Claude took too long to answer.');
    } catch (_) {
      throw AiProviderError('Could not reach Claude (check the internet).');
    }
    if (res.statusCode != 200) throw httpError('Claude', res);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map) throw AiProviderError('Claude sent an empty answer.');
    return json.cast<String, Object?>();
  }

  static String _text(List content) => [
        for (final b in content)
          if (b is Map && b['type'] == 'text' && b['text'] is String)
            (b['text'] as String).trim()
      ].where((t) => t.isNotEmpty).join('\n');
}
