import 'smart_add_parser.dart';

/// Builds the XMLTV EPG URL for an Xtream Codes ("XC API") panel from a
/// server address, username, and password.
///
/// The playlist itself goes through the real `player_api.php` API
/// ([XtreamApiService]) rather than the `get.php` M3U export — many panels
/// disable that shortcut (it's a common anti-sharing measure) while
/// leaving `player_api.php` and `xmltv.php` active. EPG has no such
/// per-category API equivalent, so `xmltv.php` is still used there.
class XtreamHelper {
  static String buildEpgUrl({
    required String server,
    required String username,
    required String password,
  }) {
    final base = normalizeServer(server);
    final user = Uri.encodeQueryComponent(username);
    final pass = Uri.encodeQueryComponent(password);
    return '$base/xmltv.php?username=$user&password=$pass';
  }

  /// The Xtream login inside a panel's M3U export link
  /// (`http://host:port/get.php?username=U&password=P&type=m3u_plus`), as
  /// Smart add reads it: the same catalog, which the Xtream API serves a
  /// category / show at a time instead of one 300+ MB list. Null for any
  /// other link.
  static ({String server, String username, String password})? fromM3uUrl(
      String url) {
    if (!RegExp(r'^https?://[^?#]+/get\.php(?:[?#]|$)', caseSensitive: false)
        .hasMatch(url.trim())) {
      return null;
    }
    final parsed = parseSmartAddText(url);
    if (parsed.serverCandidates.isEmpty ||
        parsed.username.isEmpty ||
        parsed.password.isEmpty) {
      return null;
    }
    return (
      server: parsed.serverCandidates.first,
      username: parsed.username,
      password: parsed.password,
    );
  }

  /// Trims trailing slashes and adds `http://` when the user typed only
  /// the host (`vpn.example.online`, `host:8080`): without a scheme
  /// `Uri.parse` sees no host and every request failed with "No host
  /// specified in URI" (LOG-BP8TW5; other apps accept the bare host).
  static String normalizeServer(String server) {
    var s = server.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isNotEmpty &&
        !RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(s)) {
      s = 'http://$s';
    }
    return s;
  }
}
