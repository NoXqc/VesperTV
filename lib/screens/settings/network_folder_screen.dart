import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/recording_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/phone_pair_panel.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_text_field_gate.dart';

/// Settings > Recordings > Network folder: a Windows / NAS shared folder
/// (SMB) for recordings and downloads, so a Fire Stick's few GB aren't the
/// limit. Test connects and writes a small file; Save keeps the login on
/// this device only and sends recordings and downloads there. From phone
/// (focused first: typing with a remote is the hard part) fills the fields
/// from the phone, same Wi-Fi only.
class NetworkFolderScreen extends StatefulWidget {
  const NetworkFolderScreen({super.key});

  @override
  State<NetworkFolderScreen> createState() => _NetworkFolderScreenState();
}

class _NetworkFolderScreenState extends State<NetworkFolderScreen> {
  final _service = RecordingService.instance;
  late final TextEditingController _address;
  late final TextEditingController _folder;
  late final TextEditingController _user;
  late final TextEditingController _password;

  final _addressFocus = FocusNode();
  final _folderFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _testFocus = FocusNode();
  final _saveFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _busy = false;
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final c = _service.settings.network;
    _address = TextEditingController(
        text: c == null ? '' : '\\\\${c.host}\\${c.share}');
    _folder = TextEditingController(text: c?.folder ?? 'VesperTV');
    _user = TextEditingController(text: c?.user ?? '');
    _password = TextEditingController(text: c?.password ?? '');
    HardwareKeyboard.instance.addHandler(_handleFieldEscapeKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleFieldEscapeKey);
    for (final n in [
      _addressFocus,
      _folderFocus,
      _userFocus,
      _passwordFocus,
      _testFocus,
      _saveFocus,
      _phoneFocus
    ]) {
      n.dispose();
    }
    for (final c in [_address, _folder, _user, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Down out of a focused field (EditableText keeps arrow keys, see
  /// DebridSettingsScreen).
  bool _handleFieldEscapeKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return false;
    final order = [
      _addressFocus,
      _folderFocus,
      _userFocus,
      _passwordFocus,
      _testFocus
    ];
    final i = order.indexOf(FocusManager.instance.primaryFocus ?? _testFocus);
    if (i < 0 || i >= order.length - 1) return false;
    order[i + 1].requestFocus();
    return true;
  }

  /// The fields as a config, or null with [_result] saying what's missing.
  NetworkFolderConfig? _config() {
    final a = NetworkFolderConfig.parseAddress(_address.text);
    if (a == null || a.share.isEmpty) {
      setState(() {
        _ok = false;
        _result = tr(
            'Type the shared folder as \\\\computer\\folder, for example \\\\192.168.1.20\\Media');
      });
      return null;
    }
    final inside = [
      if (a.folder.isNotEmpty) a.folder,
      if (_folder.text.trim().isNotEmpty)
        _folder.text.trim().replaceAll('\\', '/'),
    ].join('/');
    return NetworkFolderConfig(
      host: a.host,
      share: a.share,
      folder: inside.replaceAll(RegExp(r'^/+|/+$'), ''),
      user: _user.text.trim(),
      password: _password.text,
    );
  }

  static String _gb(int bytes) =>
      '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  Future<bool> _test(NetworkFolderConfig config) async {
    setState(() {
      _busy = true;
      _result = tr('Connecting…');
    });
    final r = await _service.testNetworkFolder(config);
    if (!mounted) return false;
    setState(() {
      _busy = false;
      _ok = r.error == null;
      _result = r.error == null
          ? (r.free != null
              ? tr('Connected. {free} free.', {'free': _gb(r.free!)})
              : tr('Connected.'))
          : tr("Couldn't use this folder: {reason}", {'reason': tr(r.error!)});
    });
    return r.error == null;
  }

  Future<void> _save() async {
    final config = _config();
    if (config == null) return;
    if (!await _test(config)) return;
    final s = _service.settings;
    await _service
        .updateSettings(s.copyWith(network: config, folder: config.base));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            tr('Saved. Recordings and downloads go to the network folder.'))));
    Navigator.of(context).maybePop();
  }

  /// The phone sends the four fields; they land here, are tested at once,
  /// and Save and use it is focused.
  Future<void> _fromPhone() async {
    final r = await Navigator.of(context).push<PairingResult>(
        MaterialPageRoute(builder: (_) => const _PhoneFolderScreen()));
    if (r == null || !mounted) return;
    _address.text = r.server;
    if (r.name.isNotEmpty) _folder.text = r.name;
    _user.text = r.username;
    _password.text = r.password;
    _saveFocus.requestFocus();
    final config = _config();
    if (config != null) await _test(config);
  }

  Future<void> _remove() async {
    final s = _service.settings;
    final base = s.network?.base;
    await _service.updateSettings(s.copyWith(
        clearNetwork: true, clearFolder: base != null && s.folder == base));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Widget _field(TextEditingController controller, FocusNode focus,
      FocusNode next, String label,
      {String? hint, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvTextFieldGate(
        focusNode: focus,
        builder: (context, readOnly) => TextField(
          controller: controller,
          focusNode: focus,
          readOnly: readOnly,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => next.requestFocus(),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _service.settings.network != null;
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Network folder'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(
                'Record and download to a shared folder on a computer or NAS on your network, instead of this device. On Windows: right-click a folder > Properties > Sharing.')),
            const SizedBox(height: 6),
            Text(
              tr('The user name and password stay on this device. Wi-Fi carries the video twice (in, then to the folder), so a wired connection or overnight downloads work best.'),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                autofocus: true,
                focusNode: _phoneFocus,
                onPressed: _busy ? null : _fromPhone,
                icon: const Icon(Icons.qr_code_2),
                label: Text(tr('From phone')),
              ),
            ),
            const SizedBox(height: 16),
            _field(_address, _addressFocus, _folderFocus, tr('Shared folder'),
                hint: '\\\\192.168.1.20\\Media'),
            _field(_folder, _folderFocus, _userFocus,
                tr('Folder inside it (made if missing)'),
                hint: 'VesperTV'),
            _field(_user, _userFocus, _passwordFocus,
                tr('User name (empty for a guest share)')),
            _field(_password, _passwordFocus, _testFocus, tr('Password'),
                obscure: true),
            Wrap(spacing: 12, runSpacing: 8, children: [
              OutlinedButton(
                focusNode: _testFocus,
                onPressed: _busy
                    ? null
                    : () {
                        final c = _config();
                        if (c != null) _test(c);
                      },
                child: Text(tr('Test')),
              ),
              FilledButton(
                focusNode: _saveFocus,
                onPressed: _busy ? null : _save,
                child: Text(tr('Save and use it')),
              ),
              if (saved)
                TextButton(
                  onPressed: _busy ? null : _remove,
                  child: Text(tr('Remove')),
                ),
            ]),
            if (_result != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                if (_busy)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(_ok ? Icons.check_circle : Icons.error_outline,
                      size: 18,
                      color: _ok ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(_result!)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// The QR page behind From phone; pops with what the phone sent.
class _PhoneFolderScreen extends StatefulWidget {
  const _PhoneFolderScreen();

  @override
  State<_PhoneFolderScreen> createState() => _PhoneFolderScreenState();
}

class _PhoneFolderScreenState extends State<_PhoneFolderScreen> {
  final _toggleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The panel's only focusable control (CLAUDE.md §10).
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
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Network folder'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: PhonePairPanel(
          kind: PairingKind.networkFolder,
          toggleFocusNode: _toggleFocus,
          onResult: (r) {
            if (mounted) Navigator.of(context).pop(r);
          },
        ),
      ),
    );
  }
}
