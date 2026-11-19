import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/playlist_profile.dart';
import '../../services/app_preferences.dart';
import '../../services/dispatcharr.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/playlist_manager.dart';
import '../../services/tuliprox.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/phone_pair_panel.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'add_playlist_screen.dart';

/// Settings > Playlists & sources > Tuliprox ([Tuliprox]): sign in to a
/// Tuliprox Web UI once. The player's Sources then lists the providers a
/// failover group merged into the playing channel and switches between them
/// on the server. Only a token is kept, never the password.
class TuliproxScreen extends StatefulWidget {
  const TuliproxScreen({super.key});

  @override
  State<TuliproxScreen> createState() => _TuliproxScreenState();
}

class _TuliproxScreenState extends State<TuliproxScreen> {
  final _address = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _addressFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _connectFocus = FocusNode();
  final _disconnectFocus = FocusNode();
  bool _busy = false;

  TuliproxStatus? _status;
  String? _problem;

  Tuliprox get _t => Tuliprox.instance;

  late final _order = [
    _addressFocus,
    _userFocus,
    _passwordFocus,
    _connectFocus
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_escapeField);
    final l = _t.login.value;
    if (l != null) {
      _address.text = l.base;
      _user.text = l.username;
      _check(l);
    }
    if (context.read<AppPreferences>().isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_t.login.value == null ? _addressFocus : _disconnectFocus)
            .requestFocus();
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_escapeField);
    for (final c in [_address, _user, _password]) {
      c.dispose();
    }
    for (final f in [..._order, _disconnectFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Up/Down between the fields (they keep the arrow keys).
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

  Future<void> _check(TuliproxLogin l) async {
    try {
      final status = await _t.api.status(l);
      if (!mounted) return;
      setState(() {
        _status = status;
        _problem = null;
      });
    } on TuliproxForbiddenException {
      if (mounted) setState(() => _problem = _notAdmin);
    } on TuliproxLoginException {
      if (mounted) {
        setState(() => _problem =
            tr('Tuliprox refused the saved sign-in. Sign in again.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _problem = tr("Tuliprox doesn't answer right now."));
      }
    }
  }

  static String get _notAdmin => tr(
      "This login can't see the server's streams. Sign in with an admin login to list a channel's sources.");

  Future<void> _connect() async {
    if (_busy) return;
    final base = TuliproxApi.normalizeUrl(_address.text);
    final user = _user.text.trim();
    if (_address.text.trim().isEmpty || user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              tr('Enter the Web UI address, your user name and password.'))));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? error;
    TuliproxLogin? login;
    try {
      login = await _t.api.signIn(base, user, _password.text);
      await _t.save(login);
    } on TuliproxLoginException catch (e) {
      debugPrint('Tuliprox: password refused (HTTP ${e.status})');
      error = tr('Wrong user name or password.');
    } on TuliproxException catch (e) {
      debugPrint('Tuliprox: sign-in failed ($e, HTTP ${e.status})');
      error = e.status == 429
          ? tr('Too many tries. Wait a minute, then connect again.')
          : e.status == null || e.status == 404 || e.status == 405
              ? tr(
                  "Couldn't find a Tuliprox Web UI at that address. Add its path, for example /admin.")
              : tr('Tuliprox refused the sign-in (HTTP {code}).',
                  {'code': '${e.status}'});
    } catch (e) {
      debugPrint('Tuliprox: sign-in failed ($e)');
      error = tr(
          "Couldn't find a Tuliprox Web UI at that address. Add its path, for example /admin.");
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (login != null) {
        _problem = null;
        _password.clear();
      }
    });
    if (error != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade900));
      return;
    }
    debugPrint('Tuliprox: connected to ${Tuliprox.hostOf(base)}, playlists on '
        'it: ${_linked(context.read<PlaylistManager>(), base).length}');
    await _check(login!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _disconnectFocus.requestFocus();
    });
  }

  /// "From phone" (owner, 2026-11-19): the phone fills in the address,
  /// user and password; they land in the fields here, Connect focused.
  Future<void> _fromPhone() async {
    final r = await Navigator.of(context).push<PairingResult>(
        MaterialPageRoute(builder: (_) => const _PhoneTuliproxScreen()));
    if (r == null || !mounted) return;
    _address.text = r.server;
    _user.text = r.username;
    _password.text = r.password;
    _connectFocus.requestFocus();
  }

  /// The server's playlist users, or null after telling why not.
  Future<TuliproxUsers?> _loadUsers() async {
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    try {
      final l = await _t.fresh();
      if (l == null) return null;
      return await _t.api.users(l);
    } on TuliproxForbiddenException {
      error = tr("This login can't manage the server's users.");
    } on TuliproxLoginException {
      error = tr('Tuliprox refused the saved sign-in. Sign in again.');
    } catch (e) {
      debugPrint('Tuliprox: user list failed ($e)');
      error = tr("Tuliprox doesn't answer right now.");
    }
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return null;
  }

  /// Add Playlist, filled in with [username] on [server] (Xtream); an empty
  /// [password] is typed there.
  Future<void> _openAddPlaylist(
      String server, String username, String password, String target) async {
    final manager = context.read<PlaylistManager>();
    final profile = PlaylistProfile(
      id: 'prefill',
      name: target,
      mode: 'xtream',
      xtreamServer: server,
      xtreamUsername: username,
      xtreamPassword: password,
      sortOrder: manager.profiles.length,
      syncFrequencyDays: AppConstants.defaultSyncFrequencyDays,
      createdAt: DateTime.now(),
    );
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddPlaylistScreen(prefill: profile)));
    if (mounted) setState(() {});
  }

  /// "Use an existing user" (owner, 2026-11-19): Tuliprox never hands out
  /// passwords, so the user is picked here and its password typed in Add
  /// Playlist.
  Future<void> _useExisting() async {
    final all = await _loadUsers();
    if (all == null || !mounted) return;
    final picked = await showGlassMenu<TuliproxUser>(
      context: context,
      builder: (dialog) => GlassMenuDialog(
        title: Text(tr('Pick a user')),
        children: [
          for (final u in all.users)
            TvMenuTile(
              icon: Icons.person_outline,
              title: u.username,
              subtitle:
                  [u.target, if (u.status.isNotEmpty) u.status].join(' · '),
              onTap: () => Navigator.pop(dialog, u),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final address = all.addressOf(picked);
    if (address == null) return;
    await _openAddPlaylist(address, picked.username, '', picked.target);
  }

  /// "Create a user for this TV" (owner, 2026-11-19): a new playlist user on
  /// the picked playlist (1 connection, active, no Web UI, a password
  /// VesperTV picks), then Add Playlist filled in with it.
  Future<void> _createUser() async {
    final all = await _loadUsers();
    if (all == null || !mounted) return;
    final target = await showGlassMenu<String>(
      context: context,
      builder: (dialog) => GlassMenuDialog(
        title: Text(tr('Which playlist?')),
        children: [
          for (final t in all.targets)
            TvMenuTile(
              icon: Icons.playlist_play,
              title: t,
              onTap: () => Navigator.pop(dialog, t),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final creds = newTuliproxCredentials();
    final ok = await showGlassMenu<bool>(
      context: context,
      builder: (dialog) => GlassMenuDialog(
        title: Text(tr('Create {user} on {playlist}?',
            {'user': creds.username, 'playlist': target})),
        children: [
          TvMenuTile(
            autofocus: true,
            icon: Icons.person_add_alt_1,
            title: tr('Create'),
            subtitle: tr(
                '1 connection, a password VesperTV picks. You can delete the user in the Tuliprox Web UI.'),
            onTap: () => Navigator.pop(dialog, true),
          ),
          TvMenuTile(
            icon: Icons.close,
            title: tr('Cancel'),
            onTap: () => Navigator.pop(dialog, false),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final server = all.serverNameFor(target) ?? '';
    final address = all.servers[server] ?? all.servers.values.firstOrNull;
    if (address == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? error;
    try {
      final l = await _t.fresh();
      if (l == null) return;
      await _t.api.createUser(l, target,
          username: creds.username,
          password: creds.password,
          server: server,
          comment: 'Created by VesperTV');
      debugPrint('Tuliprox: created a user on $target');
    } on TuliproxForbiddenException {
      error = tr("This login can't manage the server's users.");
    } on TuliproxException catch (e) {
      debugPrint('Tuliprox: user creation refused ($e)');
      error = tr("Tuliprox didn't create the user (HTTP {code}).",
          {'code': '${e.status ?? '?'}'});
    } catch (e) {
      debugPrint('Tuliprox: user creation failed ($e)');
      error = tr("Tuliprox doesn't answer right now.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (error != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade900));
      return;
    }
    if (!mounted) return;
    await _openAddPlaylist(address, creds.username, creds.password, target);
  }

  static String _sourcesLabel(DispatcharrSources m) => switch (m) {
        DispatcharrSources.first => tr("Tuliprox's first"),
        DispatcharrSources.only => tr("Only Tuliprox's"),
        DispatcharrSources.vesper => tr("Only VesperTV's"),
      };

  static String _sourcesHelp(DispatcharrSources m) => switch (m) {
        DispatcharrSources.first => tr(
            "Then VesperTV's matches: quality copies, fallbacks, other playlists"),
        DispatcharrSources.only =>
          tr('The channel and the providers Tuliprox merged into it'),
        DispatcharrSources.vesper => tr(
            'Quality copies, fallbacks and other playlists, as without Tuliprox'),
      };

  /// Sources in the player: one setting with Dispatcharr's ([Dispatcharr
  /// .sources]), server sources first / only / VesperTV's only.
  Future<void> _pickSources() async {
    final current = Dispatcharr.instance.sources;
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
    await Dispatcharr.instance.setSources(picked);
    if (mounted) setState(() {});
  }

  Future<void> _disconnect() async {
    await _t.save(null);
    if (!mounted) return;
    setState(() {
      _status = null;
      _problem = null;
    });
    _addressFocus.requestFocus();
  }

  /// The playlists that stream from this server (same host).
  List<PlaylistProfile> _linked(PlaylistManager manager, String base) {
    final b = Uri.tryParse(base);
    if (b == null || b.host.isEmpty) return const [];
    return [
      for (final p in manager.profiles)
        if (Uri.tryParse((p.isXtream ? p.xtreamServer : p.m3uUrl)?.trim() ?? '')
                ?.host
                .toLowerCase() ==
            b.host.toLowerCase())
          p,
    ];
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

  Widget _connected(TuliproxLogin l) {
    final manager = context.watch<PlaylistManager>();
    final linked = _linked(manager, l.base);
    final status = _status;
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
              tr('Connected to {server} as {user}',
                  {'server': l.base, 'user': l.username}),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text(
                'Tuliprox ${status.version} · '
                '${tr('Watching now: {n}', {'n': status.activeUsers})}',
                style: dim),
          ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child:
                Text(_problem!, style: const TextStyle(color: Colors.orange)),
          ),
        if (status != null && status.providerConnections.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Provider connections in use'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final e in status.providerConnections.entries)
            Text('${e.key}: ${e.value}', style: dim),
        ],
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
          tr("In the player, Sources lists the providers Tuliprox merged into the channel and the one on air. Picking one switches the stream on the server, for everyone watching that channel."),
          style: dim,
        ),
        const SizedBox(height: 12),
        SettingRow(
          icon: Icons.low_priority,
          title: tr('Sources in the player'),
          subtitle: tr('Which streams Sources lists for a Tuliprox channel'),
          trailing:
              SettingValue(text: _sourcesLabel(Dispatcharr.instance.sources)),
          onTap: _pickSources,
        ),
        const SizedBox(height: 16),
        Text(tr('Add a playlist from this server'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SettingRow(
          icon: Icons.person_search,
          title: tr('Use an existing user'),
          subtitle: tr('Pick a user, then type its password'),
          enabled: !_busy,
          onTap: _useExisting,
        ),
        SettingRow(
          icon: Icons.person_add_alt_1,
          title: tr('Create a user for this TV'),
          subtitle:
              tr('A new user with 1 connection and a password VesperTV picks'),
          enabled: !_busy,
          onTap: _createUser,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          focusNode: _disconnectFocus,
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off),
          label: Text(tr('Disconnect')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Tuliprox',
      body: ValueListenableBuilder<TuliproxLogin?>(
        valueListenable: _t.login,
        builder: (context, login, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(
                "Tuliprox can merge the same channel from several providers into one and switch between them on the server. Sign in with your Tuliprox Web UI login to see and switch those sources from the player's Sources.")),
            const SizedBox(height: 16),
            if (login != null)
              _connected(login)
            else ...[
              _field(
                controller: _address,
                focus: _addressFocus,
                next: _userFocus,
                label: tr('Web UI address'),
                hint: 'https://tv.example.com/admin',
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
                next: _connectFocus,
                label: tr('Password'),
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
                tr('Your password is only sent to your server, once. VesperTV keeps a sign-in token, not the password.'),
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
class _PhoneTuliproxScreen extends StatefulWidget {
  const _PhoneTuliproxScreen();

  @override
  State<_PhoneTuliproxScreen> createState() => _PhoneTuliproxScreenState();
}

class _PhoneTuliproxScreenState extends State<_PhoneTuliproxScreen> {
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
        title: 'Tuliprox',
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PhonePairPanel(
            kind: PairingKind.tuliprox,
            toggleFocusNode: _toggleFocus,
            onResult: (r) {
              if (mounted) Navigator.of(context).pop(r);
            },
          ),
        ),
      );
}
