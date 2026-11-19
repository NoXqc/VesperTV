import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/playlist_profile.dart';
import '../../services/app_preferences.dart';
import '../../services/dispatcharr.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/playlist_manager.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/phone_pair_panel.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'add_playlist_screen.dart';

/// Settings > Playlists & sources > Dispatcharr ([Dispatcharr]): sign in to
/// a Dispatcharr server once. The player's Sources then lists every stream
/// Dispatcharr has behind the playing channel. Only the API key is kept.
class DispatcharrScreen extends StatefulWidget {
  const DispatcharrScreen({super.key});

  @override
  State<DispatcharrScreen> createState() => _DispatcharrScreenState();
}

class _DispatcharrScreenState extends State<DispatcharrScreen> {
  final _address = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _key = TextEditingController();
  final _addressFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _keyFocus = FocusNode();
  final _connectFocus = FocusNode();
  final _addFocus = FocusNode();
  bool _busy = false;

  /// From the last check of the saved key (null until it answers).
  DispatcharrAccount? _account;
  String? _version;
  String? _problem;

  Dispatcharr get _d => Dispatcharr.instance;

  late final _order = [
    _addressFocus,
    _userFocus,
    _passwordFocus,
    _keyFocus,
    _connectFocus
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_escapeField);
    final l = _d.login.value;
    if (l != null) {
      _address.text = l.server;
      _user.text = l.username;
      _check(l);
    }
    if (context.read<AppPreferences>().isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_d.login.value == null ? _addressFocus : _addFocus).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_escapeField);
    for (final c in [_address, _user, _password, _key]) {
      c.dispose();
    }
    for (final f in [..._order, _addFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Up/Down between the fields (they keep the arrow keys), as
  /// MediaServerScreen does.
  bool _escapeField(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final i = _order.indexWhere((f) => f.hasFocus);
    if (i < 0 || i == _order.length - 1) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _order[i + 1].requestFocus();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && i > 0) {
      _order[i - 1].requestFocus();
      return true;
    }
    return false;
  }

  Future<void> _check(DispatcharrLogin l) async {
    try {
      final version = await _d.api.version(l.server);
      final account = await _d.api.check(l);
      if (!mounted) return;
      setState(() {
        _version = version;
        _account = account;
        _problem = null;
      });
    } on DispatcharrLoginException {
      if (mounted) {
        setState(() => _problem =
            tr('Dispatcharr refused the saved sign-in. Sign in again.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _problem = tr("Dispatcharr doesn't answer right now."));
      }
    }
  }

  Future<void> _connect() async {
    if (_busy) return;
    final server = DispatcharrApi.normalizeUrl(_address.text);
    final user = _user.text.trim();
    // A pasted API key (Dispatcharr > your user > API key) replaces the
    // user name and password (owner, 2026-11-18).
    final key = _key.text.trim();
    if (_address.text.trim().isEmpty || (user.isEmpty && key.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              'Enter the server address, then your user name and password or your API key.'))));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? error;
    DispatcharrAccount? account;
    try {
      account = key.isNotEmpty
          ? await _d.api.withKey(server, key)
          : await _d.api.signIn(server, user, _password.text);
      await _d.save(account.login);
    } on DispatcharrLoginException {
      debugPrint('Dispatcharr: ${key.isNotEmpty ? 'API key' : 'password'} '
          'refused (HTTP 401)');
      error = key.isNotEmpty
          ? tr('Dispatcharr refused this API key.')
          : tr('Wrong user name or password.');
    } on DispatcharrKeyLookupException catch (e) {
      debugPrint('Dispatcharr: password OK, API key lookup refused '
          '(HTTP ${e.status ?? '?'})');
      error = tr(
          'Your password works, but your server refused to hand over your API key (HTTP {code}). Paste your API key instead.',
          {'code': '${e.status ?? '?'}'});
    } on DispatcharrNetworkException {
      debugPrint('Dispatcharr: password sign-in refused by the '
          'server network rules (HTTP 403)');
      error = tr(
          'Your Dispatcharr only allows the password sign-in from some networks. Use your API key instead.');
    } on DispatcharrNotFoundException catch (e) {
      debugPrint('Dispatcharr: not found ($e, HTTP ${e.status})');
      error = tr("Couldn't find a Dispatcharr server at that address.");
    } on DispatcharrException catch (e) {
      debugPrint('Dispatcharr: sign-in failed ($e)');
      // Dispatcharr throttles sign-ins (429 after a few quick tries).
      error = e.status == 429
          ? tr('Too many tries. Wait a minute, then connect again.')
          : tr('Dispatcharr refused the sign-in (HTTP {code}).',
              {'code': '${e.status ?? '?'}'});
    } catch (e) {
      debugPrint('Dispatcharr: sign-in failed ($e)');
      error = tr("Couldn't find a Dispatcharr server at that address.");
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (account != null) {
        _account = account;
        _problem = null;
        _password.clear();
        _key.clear();
      }
    });
    if (error != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade900));
      return;
    }
    final manager = context.read<PlaylistManager>();
    final linked = _linked(manager, server).length;
    // "xcLogin", not "XC password=": Send log's redaction hides any
    // `password=` value, true/false included (roman's LOG-G67D3G).
    debugPrint('Dispatcharr: connected to ${Dispatcharr.hostOf(server)} '
        '(${key.isNotEmpty ? 'API key' : 'password'}), '
        'admin=${account!.admin}, '
        'xcLogin=${account.xcPassword != null ? 'yes' : 'no'}, '
        'playlists on it: $linked');
    _check(account.login);
    // Connect loads the channels too (roman, 2026-11-19: "I see the
    // connection, but no playlist/content/groups"): with no playlist from
    // this server yet, its playlist is added at once through Add Playlist
    // (same checks, download question and guide as a manual add).
    if (linked == 0) {
      debugPrint('Dispatcharr: adding its playlist '
          '(${account.xcPassword != null ? 'Xtream' : 'M3U'})');
      await _addPlaylist(manager, autoSave: true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addFocus.requestFocus();
    });
  }

  /// "From phone" (owner, 2026-11-18): the phone fills in the address, user
  /// and password; they land in the fields here to check, Connect focused.
  Future<void> _fromPhone() async {
    final r = await Navigator.of(context).push<PairingResult>(
        MaterialPageRoute(builder: (_) => const _PhoneDispatcharrScreen()));
    if (r == null || !mounted) return;
    _address.text = r.server;
    _user.text = r.username;
    _password.text = r.password;
    _key.text = r.apiKey;
    _connectFocus.requestFocus();
  }

  Future<void> _disconnect() async {
    await _d.save(null);
    if (!mounted) return;
    setState(() {
      _account = null;
      _version = null;
      _problem = null;
    });
    _addressFocus.requestFocus();
  }

  /// The playlists that load from this server.
  List<PlaylistProfile> _linked(PlaylistManager manager, String server) => [
        for (final p in manager.profiles)
          if (_usesServer(server, p)) p,
      ];

  static bool _usesServer(String server, PlaylistProfile p) {
    final base = Uri.tryParse(server);
    final url =
        Uri.tryParse((p.isXtream ? p.xtreamServer : p.m3uUrl)?.trim() ?? '');
    if (base == null || url == null || base.host.isEmpty) return false;
    return url.host.toLowerCase() == base.host.toLowerCase() &&
        (!base.hasPort || !url.hasPort || base.port == url.port);
  }

  /// Opens Add Playlist with this account's Xtream login (the user's
  /// Dispatcharr XC password), else the server's M3U + guide links.
  /// [autoSave] (Connect): saved straight away, no second press.
  Future<void> _addPlaylist(PlaylistManager manager,
      {bool autoSave = false}) async {
    final l = _d.login.value;
    if (l == null) return;
    final xc = _account?.xcPassword;
    final profile = PlaylistProfile(
      id: 'prefill',
      name: 'Dispatcharr',
      mode: xc != null ? 'xtream' : 'm3u',
      xtreamServer: xc != null ? l.server : null,
      xtreamUsername: xc != null ? l.username : null,
      xtreamPassword: xc,
      m3uUrl: xc == null ? '${l.server}/output/m3u' : null,
      epgUrl: xc == null ? '${l.server}/output/epg' : null,
      sortOrder: manager.profiles.length,
      syncFrequencyDays: AppConstants.defaultSyncFrequencyDays,
      createdAt: DateTime.now(),
    );
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AddPlaylistScreen(prefill: profile, autoSave: autoSave)));
    if (mounted) setState(() {});
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required FocusNode next,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    VoidCallback? onDone,
  }) =>
      TvTextFieldGate(
        focusNode: focus,
        builder: (context, readOnly) => TextField(
          controller: controller,
          focusNode: focus,
          readOnly: readOnly,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: keyboard,
          textInputAction:
              onDone == null ? TextInputAction.next : TextInputAction.done,
          // Next/Done only moves focus (CLAUDE.md §10, Fire OS Back).
          onSubmitted: (_) {
            next.requestFocus();
            onDone?.call();
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  static String _sourcesLabel(DispatcharrSources m) => switch (m) {
        DispatcharrSources.first => tr("Dispatcharr's first"),
        DispatcharrSources.only => tr("Only Dispatcharr's"),
        DispatcharrSources.vesper => tr("Only VesperTV's"),
      };

  static String _sourcesHelp(DispatcharrSources m) => switch (m) {
        DispatcharrSources.first => tr(
            "Then VesperTV's matches: quality copies, fallbacks, other playlists"),
        DispatcharrSources.only =>
          tr('The channel and the streams you assigned to it in Dispatcharr'),
        DispatcharrSources.vesper => tr(
            'Quality copies, fallbacks and other playlists, as without Dispatcharr'),
      };

  /// Sources in the player ([DispatcharrSources]; AMD, 2026-11-18).
  Future<void> _pickSources() async {
    final current = _d.sources;
    final picked = await showGlassMenu<DispatcharrSources>(
      context: context,
      builder: (dialog) => GlassMenuDialog(
        title: Text(tr('Sources in the player')),
        children: [
          for (final m in DispatcharrSources.values)
            TvMenuTile(
              autofocus: m == current,
              icon: m == current ? Icons.check : Icons.circle_outlined,
              title: _sourcesLabel(m),
              subtitle: _sourcesHelp(m),
              onTap: () => Navigator.pop(dialog, m),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await _d.setSources(picked);
    if (mounted) setState(() {});
  }

  Widget _connected(DispatcharrLogin l) {
    final manager = context.watch<PlaylistManager>();
    final linked = _linked(manager, l.server);
    final account = _account;
    const dim = TextStyle(color: Colors.white70);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(_problem == null ? Icons.check_circle : Icons.error_outline,
              color: _problem == null ? Colors.greenAccent : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('Connected to {server} as {user}', {
                'server': l.server,
                'user': account?.login.username ?? l.username
              }),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        if (_version != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text('Dispatcharr $_version', style: dim),
          ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child:
                Text(_problem!, style: const TextStyle(color: Colors.orange)),
          ),
        const SizedBox(height: 16),
        Text(
          linked.isEmpty
              ? tr('No playlist loads from this server yet.')
              : tr('Playlists on this server: {names}', {
                  'names': linked.map((p) => p.name).join(', '),
                }),
          style: dim,
        ),
        const SizedBox(height: 8),
        Text(
          tr('In the player, Sources lists every stream Dispatcharr has for the channel. Picking one plays it for you only: other viewers keep theirs.'),
          style: dim,
        ),
        const SizedBox(height: 12),
        SettingRow(
          icon: Icons.low_priority,
          title: tr('Sources in the player'),
          subtitle: tr('Which streams Sources lists for a Dispatcharr channel'),
          trailing: SettingValue(text: _sourcesLabel(_d.sources)),
          onTap: _pickSources,
        ),
        if (account != null && account.xcPassword == null) ...[
          const SizedBox(height: 8),
          // Without one, Add as a playlist can only use the M3U output.
          Text(
            tr('This Dispatcharr user has no XC password, so it would be added as an M3U playlist. For an Xtream playlist (steadier, with catch-up, movies and shows), give the user an XC password in Dispatcharr (Users > Edit), then come back here.'),
            style: const TextStyle(color: Colors.amber),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          OutlinedButton.icon(
            focusNode: _addFocus,
            onPressed: () => _addPlaylist(manager),
            icon: const Icon(Icons.playlist_add),
            label: Text(linked.isEmpty
                ? tr('Add as a playlist')
                : tr('Add another playlist from it')),
          ),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: Text(tr('Disconnect')),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Dispatcharr',
      body: ValueListenableBuilder<DispatcharrLogin?>(
        valueListenable: _d.login,
        builder: (context, login, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(
                'Dispatcharr merges several provider streams into each channel. Sign in to load its channels and to pick those streams from the player\'s Sources.')),
            const SizedBox(height: 16),
            if (login != null)
              _connected(login)
            else ...[
              _field(
                controller: _address,
                focus: _addressFocus,
                next: _userFocus,
                label: tr('Server address'),
                hint: 'http://192.168.1.10:9191',
                keyboard: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _user,
                focus: _userFocus,
                next: _passwordFocus,
                label: tr('User name'),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _password,
                focus: _passwordFocus,
                next: _keyFocus,
                label: tr('Password'),
                obscure: true,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _key,
                focus: _keyFocus,
                next: _connectFocus,
                label: tr('Or your API key'),
                hint: tr('Instead of the user name and password'),
                obscure: true,
                onDone: _connect,
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                OutlinedButton.icon(
                  focusNode: _connectFocus,
                  onPressed: _busy ? null : _connect,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: Text(tr('Connect')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _fromPhone,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(tr('From phone')),
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                tr('Your password is only sent to your server, once. VesperTV keeps your Dispatcharr API key (an existing one is reused, never replaced), not the password.'),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The QR page behind "From phone"; pops with what the phone sent.
class _PhoneDispatcharrScreen extends StatefulWidget {
  const _PhoneDispatcharrScreen();

  @override
  State<_PhoneDispatcharrScreen> createState() =>
      _PhoneDispatcharrScreenState();
}

class _PhoneDispatcharrScreenState extends State<_PhoneDispatcharrScreen> {
  final _toggleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The panel's only focusable control (CLAUDE.md §10: a focus target).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toggleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: 'Dispatcharr',
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PhonePairPanel(
            kind: PairingKind.dispatcharr,
            toggleFocusNode: _toggleFocus,
            onResult: (r) {
              if (mounted) Navigator.of(context).pop(r);
            },
          ),
        ),
      );
}
