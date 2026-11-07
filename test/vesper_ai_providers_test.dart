import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/vesper_ai/ai_provider.dart';
import 'package:nox_iptv/services/vesper_ai/anthropic_provider.dart';
import 'package:nox_iptv/services/vesper_ai/gemini_provider.dart';
import 'package:nox_iptv/services/vesper_ai/openai_provider.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_ai.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_commands.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';

final _tools = vesperTools.where((t) => t.name == 'search').toList();

void main() {
  group('Claude (Messages API)', () {
    test('runs the tool loop, results in one user message, history verbatim',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final headers = <Map<String, String>>[];
      var round = 0;
      final client = MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        headers.add(req.headers);
        round++;
        if (round == 1) {
          return http.Response(
              jsonEncode({
                'stop_reason': 'tool_use',
                'content': [
                  {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
                  {
                    'type': 'tool_use',
                    'id': 'toolu_1',
                    'name': 'search',
                    'input': {'query': 'tsn'}
                  },
                  {
                    'type': 'tool_use',
                    'id': 'toolu_2',
                    'name': 'search',
                    'input': {'query': 'rds'}
                  },
                ]
              }),
              200);
        }
        return http.Response(
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'text', 'text': 'Playing TSN 1.'}
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final ai = AnthropicProvider(
          apiKey: 'k', model: 'claude-opus-5-5', client: client);
      final calls = <String>[];
      final words = await ai.send('put on tsn', system: 'sys', tools: _tools,
          runTool: (name, args) async {
        calls.add('$name ${args['query']}');
        return {'live': []};
      });
      expect(words, 'Playing TSN 1.');
      expect(calls, ['search tsn', 'search rds']);
      final first = bodies.first;
      expect(first['model'], 'claude-opus-5-5');
      expect(first['system'], 'sys');
      expect(first['output_config'], {'effort': 'low'});
      expect(first['fallbacks'], 'default');
      expect(first['tools'][0]['input_schema']['type'], 'object');
      expect(first.containsKey('temperature'), isFalse);
      expect(first.containsKey('thinking'), isFalse);
      expect(headers.first['x-api-key'], 'k');
      expect(headers.first['anthropic-version'], '2026-10-21');
      expect(
          headers.first['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final second = bodies[1]['messages'] as List;
      expect(second, hasLength(3));
      // The assistant turn goes back unchanged (thinking block included).
      expect(second[1]['content'][0]['type'], 'thinking');
      final results = second[2]['content'] as List;
      expect(results.map((r) => r['tool_use_id']), ['toolu_1', 'toolu_2']);
    });

    test('refusal and HTTP errors read plainly', () async {
      final refusing = AnthropicProvider(
          apiKey: 'k',
          model: 'claude-haiku-5-5',
          client: MockClient((req) async {
            final body = jsonDecode(req.body) as Map;
            expect(body.containsKey('fallbacks'), isFalse);
            return http.Response(
                jsonEncode({'stop_reason': 'refusal', 'content': []}), 200);
          }));
      expect(
          await refusing.send('x',
              system: '', tools: _tools, runTool: (_, __) async => {}),
          'Claude declined that request.');
      final bad = AnthropicProvider(
          apiKey: 'k',
          model: 'claude-opus-5-5',
          client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'message': 'invalid x-api-key'}
              }),
              401)));
      await expectLater(
          bad.send('x',
              system: '', tools: _tools, runTool: (_, __) async => {}),
          throwsA(isA<AiProviderError>().having(
              (e) => e.message, 'message', contains('key was refused'))));
    });
  });

  test('OpenAI-compatible: tool calls and tool messages', () async {
    final bodies = <Map<String, dynamic>>[];
    var round = 0;
    final ai = OpenAiProvider(
        apiKey: '',
        model: 'llama3',
        baseUrl: 'http://192.168.1.5:11434/v1/',
        client: MockClient((req) async {
          expect(req.url.toString(),
              'http://192.168.1.5:11434/v1/chat/completions');
          expect(req.headers.containsKey('authorization'), isFalse);
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          round++;
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': round == 1
                        ? {
                            'role': 'assistant',
                            'content': null,
                            'tool_calls': [
                              {
                                'id': 'c1',
                                'type': 'function',
                                'function': {
                                  'name': 'search',
                                  'arguments': '{"query":"dune"}'
                                }
                              }
                            ]
                          }
                        : {'role': 'assistant', 'content': 'Found Dune.'}
                  }
                ]
              }),
              200);
        }));
    final words = await ai.send('dune',
        system: 's',
        tools: _tools,
        runTool: (name, args) async => {'q': args['query']});
    expect(words, 'Found Dune.');
    final msgs = bodies[1]['messages'] as List;
    expect(msgs.first['role'], 'system');
    expect(msgs.last['role'], 'tool');
    expect(msgs.last['tool_call_id'], 'c1');
    expect(
        bodies.first['tools'][0]['function']['parameters']['type'], 'object');
  });

  test('Gemini: function calls, upper-case schema, model turn kept', () async {
    final bodies = <Map<String, dynamic>>[];
    var round = 0;
    final ai = GeminiProvider(
        apiKey: 'g',
        model: 'gemini-2.5-flash',
        client: MockClient((req) async {
          expect(req.headers['x-goog-api-key'], 'g');
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          round++;
          return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': round == 1
                          ? [
                              {
                                'functionCall': {
                                  'name': 'search',
                                  'args': {'query': 'tsn'}
                                },
                                'thoughtSignature': 'abc'
                              }
                            ]
                          : [
                              {'text': 'Done, playing.'}
                            ]
                    }
                  }
                ]
              }),
              200);
        }));
    final words = await ai.send('tsn',
        system: 's', tools: _tools, runTool: (_, __) async => {'ok': true});
    expect(words, 'Done, playing.');
    final decl = bodies.first['tools'][0]['functionDeclarations'][0];
    expect(decl['parameters']['type'], 'OBJECT');
    expect(decl['parameters']['properties']['query']['type'], 'STRING');
    final contents = bodies[1]['contents'] as List;
    expect(contents[1]['parts'][0]['thoughtSignature'], 'abc');
    expect(contents[2]['parts'][0]['functionResponse']['name'], 'search');
  });

  test('provider settings: what is needed for each', () {
    AiProvider? make(String? p,
            {String model = '', String key = '', String url = ''}) =>
        AiProvider.fromSettings(
            provider: p, model: model, apiKey: key, baseUrl: url);
    expect(make(null, key: 'x'), isNull);
    expect(make('anthropic'), isNull);
    expect((make('anthropic', key: 'k') as AnthropicProvider).model,
        AnthropicProvider.defaultModel);
    expect(make('openai', key: 'k'), isNull, reason: 'model needed');
    expect(make('openai', model: 'm'), isNull, reason: 'OpenAI needs a key');
    expect(
        make('openai', model: 'm', url: 'http://10.0.0.2:1234/v1'), isNotNull);
    expect(make('gemini', key: 'k'), isA<GeminiProvider>());
  });

  test('built-in results read as short sentences', () {
    VesperReply r(String tool, Map<String, Object?> args,
            Map<String, Object?> result) =>
        VesperAi.describeResult(VesperCommand(tool, args), result);
    expect(
        r('play', {'name': 'tsn'}, {'playing': 'TSN 1'}).text, 'Playing TSN 1');
    expect(r('play', {'name': 'tsn'}, {'playing': 'TSN 1'}).acted, isTrue);
    expect(r('play', {'name': 'zzz'}, {'error': 'x'}).text,
        'I could not find "zzz" in your playlists.');
    expect(r('player', {'action': 'pause'}, {'done': 'paused'}).text, 'Paused');
    expect(
        r('player', {'action': 'seek'},
            {'error': 'This live channel cannot be rewound.'}).text,
        'This channel cannot be rewound.');
    expect(
        r('now_playing', const {}, {
          'title': 'TSN 1',
          'on_now': {'title': 'SportsCentre'},
          'next': {'title': 'NHL', 'start': '19:00'},
        }).text,
        'TSN 1 · now: SportsCentre · next: NHL at 19:00');
    expect(r('now_playing', const {}, {'playing': null}).text,
        'Nothing is playing.');
  });

  test('every tool schema is an object with known types', () {
    const allowed = {
      'string',
      'integer',
      'boolean',
      'number',
      'array',
      'object'
    };
    for (final t in vesperTools) {
      expect(t.schema['type'], 'object', reason: t.name);
      final props = (t.schema['properties'] as Map?) ?? const {};
      for (final e in props.entries) {
        expect(allowed, contains((e.value as Map)['type']),
            reason: '${t.name}.${e.key}');
      }
      for (final r in (t.schema['required'] as List?) ?? const []) {
        expect(props.containsKey(r), isTrue, reason: '${t.name} requires $r');
      }
      expect(RegExp(r'^[a-z_]{1,64}$').hasMatch(t.name), isTrue);
    }
    expect(
        vesperTools.map((t) => t.name).toSet(), hasLength(vesperTools.length));
  });

  test('rankByName: exact (provider tag ignored), whole words, then shorter',
      () {
    final names = ['TSN 1 HD', 'CA: TSN 1', 'TSN 1', 'TSN 10', 'RDS'];
    // "TSN 10" is a different channel: last (2026-11-06 voice report).
    expect(rankByName(names, 'tsn 1', (s) => s),
        ['TSN 1', 'CA: TSN 1', 'TSN 1 HD', 'TSN 10']);
    expect(rankByName(names, '', (s) => s), isEmpty);
  });
}
