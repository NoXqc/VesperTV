import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/addon_import.dart';

/// Settings > Media Hub sources: many links pasted at once, and Import
/// from Stremio (sign-in code, then the account's add-on list).
void main() {
  group('linksIn', () {
    test('one per line, spaces, stremio:// and duplicates', () {
      expect(AddonImporter.linksIn('''
https://a.org/x/manifest.json
  stremio://b.org/cfg/manifest.json https://a.org/x/manifest.json
not a link'''), [
        'https://a.org/x/manifest.json',
        'https://b.org/cfg/manifest.json',
      ]);
    });

    test('links run together (line breaks dropped by a one-line field)', () {
      expect(
          AddonImporter.linksIn(
              'https://a.org/1/manifest.jsonhttps://c.org/abc%3D/manifest.json'),
          [
            'https://a.org/1/manifest.json',
            'https://c.org/abc%3D/manifest.json'
          ]);
    });
  });

  group('StremioAccount', () {
    var signedIn = false;
    final client = MockClient((req) async {
      if (req.url.host == 'link.stremio.com' &&
          req.url.path.endsWith('/create')) {
        return http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'code': 'AB12',
                'link': 'https://link.stremio.com/AB12'
              }
            }),
            200);
      }
      if (req.url.path.endsWith('/read')) {
        return http.Response(
            jsonEncode(signedIn
                ? {
                    'result': {'authKey': 'k1'}
                  }
                : {
                    'error': {
                      'code': 101,
                      'message': 'Invalid or expired token'
                    }
                  }),
            200);
      }
      if (req.url.path.endsWith('/addonCollectionGet')) {
        expect(jsonDecode(req.body)['authKey'], 'k1');
        return http.Response(
            jsonEncode({
              'result': {
                'addons': [
                  {
                    'transportUrl':
                        'https://v3-cinemeta.strem.io/manifest.json',
                    'manifest': {'name': 'Cinemeta'},
                    'flags': {'official': true, 'protected': true},
                  },
                  {
                    'transportUrl':
                        'http://127.0.0.1:11470/local-addon/manifest.json',
                    'manifest': {'name': 'Local Files'},
                  },
                  {
                    'transportUrl':
                        'https://torrentio.strem.fun/cfg/manifest.json',
                    'manifest': {'name': 'Torrentio'},
                  },
                  {
                    'transportUrl':
                        'https://opensubtitles-v3.strem.io/manifest.json',
                    'manifest': {'name': 'OpenSubtitles v3'},
                    'flags': {'official': true},
                  },
                ]
              }
            }),
            200);
      }
      return http.Response('not found', 404);
    });
    final account = StremioAccount(client: client);

    test('a code, then nothing until someone signs in', () async {
      final code = await account.createCode();
      expect(code.code, 'AB12');
      expect(code.link, 'https://link.stremio.com/AB12');
      expect(await account.sessionFor('AB12'), isNull);
      signedIn = true;
      expect(await account.sessionFor('AB12'), 'k1');
    });

    test('the add-on list skips Stremio built-ins and local links', () async {
      final addons = await account.addons('k1');
      expect(addons.map((a) => a.name), ['Torrentio', 'OpenSubtitles v3']);
      expect(addons.first.url, 'https://torrentio.strem.fun/cfg/manifest.json');
    });
  });
}
