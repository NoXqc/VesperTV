import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';
import 'vesper_tools.dart';

/// Google Gemini with the viewer's own key (aistudio.google.com):
/// `generateContent` with function declarations. Each model turn goes back
/// unchanged (its thought signatures included).
class GeminiProvider extends AiProvider {
  GeminiProvider(
      {required this.apiKey, required this.model, http.Client? client})
      : _client = client ?? http.Client();

  static const defaultModel = 'gemini-2.5-flash';
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  final String apiKey;
  final String model;
  final http.Client _client;
  final List<Map<String, Object?>> _contents = [];

  @override
  String get id => 'gemini';

  @override
  void reset() => _contents.clear();

  @override
  Future<String> send(String text,
      {required String system,
      required List<VesperTool> tools,
      required VesperToolRunner runTool,
      int maxRounds = 8}) async {
    _contents.add({
      'role': 'user',
      'parts': [
        {'text': text}
      ],
    });
    try {
      for (var round = 0; round < maxRounds; round++) {
        final content = await _post(system, tools);
        _contents.add(content);
        final parts = (content['parts'] as List?) ?? const [];
        final calls = [
          for (final p in parts)
            if (p is Map && p['functionCall'] is Map) p['functionCall'] as Map
        ];
        if (calls.isEmpty) {
          final words = [
            for (final p in parts)
              if (p is Map && p['text'] is String && p['thought'] != true)
                (p['text'] as String).trim()
          ].where((t) => t.isNotEmpty).join('\n');
          return words.isEmpty ? 'Done.' : words;
        }
        final responses = <Map<String, Object?>>[];
        for (final call in calls) {
          final name = '${call['name'] ?? ''}';
          final args = call['args'];
          final result = await runTool(
              name, args is Map ? args.cast<String, Object?>() : const {});
          responses.add({
            'functionResponse': {
              'name': name,
              'response': result,
            }
          });
        }
        _contents.add({'role': 'user', 'parts': responses});
      }
      reset();
      return 'That took too many steps.';
    } catch (e) {
      reset();
      rethrow;
    }
  }

  /// Gemini reads an OpenAPI subset: upper-case types, no empty objects.
  static Map<String, Object?> _schema(Map<String, Object?> s) {
    final out = <String, Object?>{};
    s.forEach((k, v) {
      if (k == 'type' && v is String) {
        out[k] = v.toUpperCase();
      } else if (k == 'properties' && v is Map) {
        out[k] = {
          for (final e in v.entries)
            e.key: _schema((e.value as Map).cast<String, Object?>())
        };
      } else if (k == 'description' || k == 'enum' || k == 'required') {
        out[k] = v;
      }
    });
    return out;
  }

  Future<Map<String, Object?>> _post(
      String system, List<VesperTool> tools) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': _contents,
      'tools': [
        {
          'functionDeclarations': [
            for (final t in tools)
              {
                'name': t.name,
                'description': t.description,
                if (((t.schema['properties'] as Map?) ?? const {}).isNotEmpty)
                  'parameters': _schema(t.schema),
              }
          ]
        }
      ],
    };
    final http.Response res;
    try {
      res = await _client
          .post(
              Uri.parse(
                  '$_base/models/${Uri.encodeComponent(model)}:generateContent'),
              headers: {
                'content-type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw AiProviderError('Gemini took too long to answer.');
    } catch (_) {
      throw AiProviderError('Could not reach Gemini (check the internet).');
    }
    if (res.statusCode != 200) throw httpError('Gemini', res);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    final candidates = json is Map ? json['candidates'] : null;
    final first =
        candidates is List && candidates.isNotEmpty ? candidates.first : null;
    final content = first is Map ? first['content'] : null;
    if (content is! Map) {
      final reason = first is Map ? first['finishReason'] : null;
      throw AiProviderError(reason == 'SAFETY'
          ? 'Gemini declined that request.'
          : 'Gemini sent an empty answer.');
    }
    return {
      'role': 'model',
      'parts': content['parts'] ?? const [],
    };
  }
}
