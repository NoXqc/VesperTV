import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/app_preferences.dart';
import '../../services/archive_service.dart';
import '../../services/media_server_errors.dart';
import '../../services/silo_api.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_text_field_gate.dart';

enum _Step { address, code, password, profile, pin }

/// Settings > Connect a media server > Connect Silo: the server's address,
/// then the TV code (approved on the server's `/activate` page or with the
/// QR code, as Silo's own TV apps do) or a password, then a household
/// profile (its PIN when it has one). The libraries become Media Hub rows
/// (`SiloApi`). Pops `true` when the server was added.
class SiloConnectScreen extends StatefulWidget {
  const SiloConnectScreen({super.key});

  @override
  State<SiloConnectScreen> createState() => _SiloConnectScreenState();
}

class _SiloConnectScreenState extends State<SiloConnectScreen> {
  final _client = http.Client();
  late final _api = SiloApi(_client);
  late final StorageService _storage;

  final _address = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _addressFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _goFocus = FocusNode();

  _Step _step = _Step.address;
  bool _busy = false;
  String? _error;
  String? _base;
  String _deviceId = '';
  SiloDeviceCode? _code;
  SiloSignIn? _signIn;
  List<SiloProfile> _profiles = const [];
  SiloProfile? _pinFor;
  Timer? _timer;
  int _generation = 0;

  static const _optionsKey = 'silo_client';

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _loadClient();
    HardwareKeyboard.instance.addHandler(_escapeField);
    if (context.read<AppPreferences>().isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addressFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _cancelCode();
    HardwareKeyboard.instance.removeHandler(_escapeField);
    for (final c in [_address, _user, _password, _pin]) {
      c.dispose();
    }
    for (final f in [
      _addressFocus,
      _userFocus,
      _passwordFocus,
      _pinFocus,
      _goFocus,
    ]) {
      f.dispose();
    }
    _client.close();
    super.dispose();
  }

  /// This install's device id for Silo (its sessions list shows it) and
  /// the last address, so signing in again starts filled in.
  void _loadClient() {
    final saved = _storage.getArchiveOptionsJson(_optionsKey);
    try {
      final v = saved == null ? null : jsonDecode(saved);
      if (v is Map) {
        if (v['id'] is String) _deviceId = v['id'];
        if (v['address'] is String) _address.text = v['address'];
      }
    } catch (_) {}
    if (_deviceId.isEmpty) {
      final r = Random.secure();
      _deviceId =
          'vespertv-${List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    }
  }

  Future<void> _saveClient() => _storage.setArchiveOptionsJson(
    _optionsKey,
    jsonEncode({'id': _deviceId, 'address': _address.text.trim()}),
  );

  /// Up/Down between a step's fields and its button (fields keep the
  /// arrow keys; same fix as MediaServerScreen).
  List<FocusNode> get _order => switch (_step) {
    _Step.address => [_addressFocus, _goFocus],
    _Step.password => [_userFocus, _passwordFocus, _goFocus],
    _Step.pin => [_pinFocus, _goFocus],
    _ => const [],
  };

  bool _escapeField(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final order = _order;
    final i = order.indexWhere((f) => f.hasFocus);
    if (i < 0 || i == order.length - 1) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      order[i + 1].requestFocus();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && i > 0) {
      order[i - 1].requestFocus();
      return true;
    }
    return false;
  }

  void _go(_Step step, {String? error}) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _busy = false;
      _error = error;
    });
    final focus = switch (step) {
      _Step.address => _addressFocus,
      _Step.password => _userFocus,
      _Step.pin => _pinFocus,
      _ => null,
    };
    if (focus != null && context.read<AppPreferences>().isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  String _messageFor(Object error) => switch (error) {
    MediaServerLoginException() => tr('Wrong user name or password.'),
    SiloRateLimitedException() => tr(
      'Too many tries. Try again in a few minutes.',
    ),
    MediaServerNoLibraryException() => tr(
      'This account has no movie or TV library.',
    ),
    _ => tr('Could not connect to Silo. Try again.'),
  };

  // ---- Address ----------------------------------------------------------------

  Future<void> _findServer() async {
    if (_busy || _address.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _base = await _api.discover(_address.text);
    } catch (_) {
      _fail(tr("Couldn't find a Silo server at that address."));
      return;
    }
    await _saveClient();
    await _startCode();
  }

  // ---- Code ---------------------------------------------------------------------

  Future<void> _startCode() async {
    final generation = ++_generation;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await _api.startDeviceLogin(_base!, _deviceId);
      if (!mounted || generation != _generation) return;
      _code = code;
      _go(_Step.code);
      _schedule(generation, code.interval);
    } catch (error) {
      if (mounted && generation == _generation) {
        _go(_Step.code, error: _messageFor(error));
      }
    }
  }

  void _schedule(int generation, Duration after) {
    _timer = Timer(after, () => _poll(generation));
  }

  Future<void> _poll(int generation) async {
    final code = _code;
    if (!mounted || generation != _generation || code == null) return;
    if (DateTime.now().isAfter(code.expiresAt)) {
      _code = null;
      _fail(tr('The code expired. Try again.'));
      return;
    }
    try {
      final signIn = await _api.pollDeviceLogin(_base!, _deviceId, code);
      if (!mounted || generation != _generation) return;
      if (signIn == null) {
        _schedule(generation, code.interval);
        return;
      }
      _code = null;
      await _signedIn(signIn);
    } on SiloSignInEndedException catch (e) {
      _code = null;
      if (generation == _generation) {
        _fail(
          e.status == 'denied'
              ? tr('Sign-in was refused on the server.')
              : tr('The code expired. Try again.'),
        );
      }
    } catch (_) {
      // A dropped connection: keep asking until the code runs out.
      if (mounted && generation == _generation) {
        _schedule(generation, code.interval);
      }
    }
  }

  /// The screen was left with a code nobody approved: withdraw it.
  void _cancelCode() {
    final code = _code;
    final base = _base;
    _code = null;
    if (code != null && base != null) {
      unawaited(_api.cancelDeviceLogin(base, _deviceId, code));
    }
  }

  void _usePassword() {
    _generation++;
    _timer?.cancel();
    _cancelCode();
    _go(_Step.password);
  }

  // ---- Password -----------------------------------------------------------------

  Future<void> _signInWithPassword() async {
    if (_busy || _user.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signIn = await _api.login(
        _base!,
        _deviceId,
        _user.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      _password.clear();
      await _signedIn(signIn);
    } catch (error) {
      _fail(_messageFor(error));
    }
  }

  // ---- Profile ------------------------------------------------------------------

  Future<void> _signedIn(SiloSignIn signIn) async {
    _signIn = signIn;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profiles = await _api.profiles(signIn);
      if (!mounted) return;
      _profiles = profiles;
      // Picked (and unlocked) on the server's page already, or the only one.
      final picked = profiles
          .where((p) => p.id == signIn.profileId)
          .firstOrNull;
      if (picked != null && (!picked.hasPin || signIn.profileToken != null)) {
        return await _connect(picked, signIn.profileToken);
      }
      if (profiles.length == 1 && !profiles.single.hasPin) {
        return await _connect(profiles.single, null);
      }
      _go(
        _Step.profile,
        error: profiles.isEmpty
            ? tr('Could not connect to Silo. Try again.')
            : null,
      );
    } catch (error) {
      _fail(_messageFor(error));
    }
  }

  void _pickProfile(SiloProfile profile) {
    if (_busy) return;
    if (!profile.hasPin) {
      _connect(profile, null);
      return;
    }
    _pinFor = profile;
    _pin.clear();
    _go(_Step.pin);
  }

  Future<void> _checkPin() async {
    final profile = _pinFor;
    if (_busy || profile == null || _pin.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await _api.verifyPin(_signIn!, profile.id, _pin.text);
      if (!mounted) return;
      _pin.clear();
      if (token == null) {
        _fail(tr('Wrong PIN.'));
        return;
      }
      await _connect(profile, token);
    } catch (error) {
      _pin.clear();
      _fail(_messageFor(error));
    }
  }

  Future<void> _connect(SiloProfile profile, String? profileToken) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final hub = context.read<ArchiveService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final source = await _api.connect(
        _signIn!,
        profile,
        profileToken: profileToken,
      );
      await hub.addSiloServer(source);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('{name} added.', {'name': source.name}))),
      );
      navigator.pop(true);
    } catch (error) {
      _fail(_messageFor(error));
    }
  }

  // ---- UI -------------------------------------------------------------------------

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required FocusNode next,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    VoidCallback? onDone,
  }) => TvTextFieldGate(
    focusNode: focus,
    builder: (context, readOnly) => TextField(
      controller: controller,
      focusNode: focus,
      readOnly: readOnly,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboard,
      textInputAction: onDone == null
          ? TextInputAction.next
          : TextInputAction.done,
      // Next/Done only moves focus (Fire OS sends it for Back too):
      // the next field's keyboard opens on OK (CLAUDE.md §10).
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

  Widget _button(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    FocusNode? focus,
    bool autofocus = false,
  }) => OutlinedButton.icon(
    focusNode: focus,
    autofocus: autofocus,
    onPressed: _busy ? null : onPressed,
    icon: _busy && focus != null
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    label: Text(label),
  );

  List<Widget> _stepBody() => switch (_step) {
    _Step.address => [
      Text(
        tr(
          'Sign in to your Silo server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server.',
        ),
      ),
      const SizedBox(height: 16),
      _field(
        controller: _address,
        focus: _addressFocus,
        next: _goFocus,
        label: tr('Server address'),
        hint: 'http://192.168.1.20:8090',
        keyboard: TextInputType.url,
        onDone: _findServer,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _button(
            tr('Continue'),
            Icons.arrow_forward,
            _findServer,
            focus: _goFocus,
          ),
        ],
      ),
    ],
    _Step.code => [
      if (_code case final code?) ...[
        Text(
          tr(
            'On your phone, scan the QR code, or open {url} and enter this code:',
            {'url': code.verificationUrl},
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          code.userCode,
          style: const TextStyle(fontSize: 32, letterSpacing: 5),
        ),
        const SizedBox(height: 12),
        QrImageView(
          data: code.verificationUrlComplete,
          size: 200,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 12),
      ] else if (_error != null)
        TvMenuTile(
          autofocus: true,
          icon: Icons.refresh,
          title: tr('Try again'),
          enabled: !_busy,
          onTap: _startCode,
        ),
      TvMenuTile(
        autofocus: _code != null,
        icon: Icons.password,
        title: tr('Sign in with a password instead'),
        enabled: !_busy,
        onTap: _usePassword,
      ),
    ],
    _Step.password => [
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
        next: _goFocus,
        label: tr('Password'),
        obscure: true,
        onDone: _signInWithPassword,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _button(
            tr('Sign in'),
            Icons.login,
            _signInWithPassword,
            focus: _goFocus,
          ),
          _button(
            tr('Sign in with a code instead'),
            Icons.qr_code_2,
            _startCode,
          ),
        ],
      ),
    ],
    _Step.profile => [
      Text(tr('Choose a profile')),
      const SizedBox(height: 8),
      for (var i = 0; i < _profiles.length; i++)
        TvMenuTile(
          autofocus: i == 0,
          icon: _profiles[i].hasPin
              ? Icons.lock_outline
              : Icons.account_circle_outlined,
          title: _profiles[i].name,
          enabled: !_busy,
          onTap: () => _pickProfile(_profiles[i]),
        ),
    ],
    _Step.pin => [
      _field(
        controller: _pin,
        focus: _pinFocus,
        next: _goFocus,
        label: tr('PIN for {name}', {'name': _pinFor?.name ?? ''}),
        obscure: true,
        keyboard: TextInputType.number,
        onDone: _checkPin,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _button(tr('Continue'), Icons.lock_open, _checkPin, focus: _goFocus),
          _button(
            tr('Choose a profile'),
            Icons.people_outline,
            () => _go(_Step.profile),
          ),
        ],
      ),
    ],
  };

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: tr('Connect Silo'),
    body: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(24),
      children: [
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          const SizedBox(height: 12),
        ],
        ..._stepBody(),
      ],
    ),
  );
}
