import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/addon_import.dart';
import '../../services/addon_service.dart';
import '../../services/archive_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';

/// The summary shown after an import ([AddonImportResult]), one line per
/// outcome that happened.
String addonImportSummary(AddonImportResult r) => [
      if (r.added.isNotEmpty)
        tr('Added to the Media Hub: {names}', {'names': r.added.join(', ')}),
      if (r.subtitles.isNotEmpty)
        tr('Added to subtitle add-ons: {names}',
            {'names': r.subtitles.join(', ')}),
      if (r.alreadyThere.isNotEmpty)
        tr('Already added: {names}', {'names': r.alreadyThere.join(', ')}),
      if (r.unusable.isNotEmpty)
        tr('Not usable in VesperTV: {names}', {'names': r.unusable.join(', ')}),
      if (r.unreachable.isNotEmpty)
        tr("Couldn't reach: {names}", {'names': r.unreachable.join(', ')}),
    ].join('\n\n');

/// Settings > Media Hub sources > Import from Stremio: sign in to Stremio
/// on a phone with the code shown here, pick from the account's add-ons,
/// and they're added like pasted links ([AddonImporter]). The session is
/// signed out again right after reading the list.
class StremioImportScreen extends StatefulWidget {
  const StremioImportScreen({super.key});

  @override
  State<StremioImportScreen> createState() => _StremioImportScreenState();
}

enum _Step { code, list, importing, done, failed }

class _StremioImportScreenState extends State<StremioImportScreen> {
  final _account = StremioAccount();
  final _mainFocus = FocusNode();
  var _step = _Step.code;
  ({String code, String link})? _code;
  Timer? _poll;
  DateTime? _codeSince;
  List<StremioAddon> _addons = const [];
  final Set<String> _picked = {};
  AddonImportResult? _result;
  String? _error;

  static const _pollEvery = Duration(seconds: 3);
  static const _codeLife = Duration(minutes: 10);
  static const _unsupportedAddonHosts = {
    'v3-channels.strem.io',
    'watchhub.strem.io',
  };

  bool _isUnsupportedAddon(String url) =>
      _unsupportedAddonHosts.contains(Uri.tryParse(url)?.host.toLowerCase());

  @override
  void initState() {
    super.initState();
    _newCode();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _mainFocus.dispose();
    super.dispose();
  }

  void _focusMain() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocus.requestFocus();
      });

  Future<void> _newCode() async {
    _poll?.cancel();
    setState(() {
      _step = _Step.code;
      _code = null;
      _error = null;
    });
    try {
      final code = await _account.createCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _codeSince = DateTime.now();
      });
      _poll = Timer.periodic(_pollEvery, (_) => _check());
    } catch (e) {
      _fail(tr("Couldn't reach Stremio. Check your internet connection."));
    }
    _focusMain();
  }

  bool _checking = false;

  Future<void> _check() async {
    final code = _code;
    if (code == null || _checking) return;
    if (DateTime.now().difference(_codeSince!) > _codeLife) {
      return _newCode();
    }
    _checking = true;
    try {
      final key = await _account.sessionFor(code.code);
      if (key == null || !mounted) return;
      _poll?.cancel();
      final addons = await _account.addons(key);
      unawaited(_account.signOut(key));
      if (!mounted) return;
      final service = context.read<ArchiveService>();
      setState(() {
        _addons = addons;
        _picked
          ..clear()
          ..addAll(addons
              .map((a) => a.url)
              .where((u) => !service.hasSource(u) && !_isUnsupportedAddon(u)));
        _step = _Step.list;
      });
      _focusMain();
    } catch (e) {
      debugPrint('StremioImport: $e');
      // Waiting is the normal case; a real failure after sign-in:
      if (_step == _Step.code && _poll?.isActive == false) {
        _fail(tr("Couldn't read your Stremio add-ons. Try again."));
      }
    } finally {
      _checking = false;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _poll?.cancel();
    setState(() {
      _step = _Step.failed;
      _error = message;
    });
    _focusMain();
  }

  Future<void> _import() async {
    if (_picked.isEmpty) return;
    setState(() => _step = _Step.importing);
    final importer = AddonImporter(context.read<ArchiveService>(),
        AddonService(context.read<StorageService>()));
    final picked = [
      for (final a in _addons)
        if (_picked.contains(a.url)) a
    ];
    final result = await importer.importLinks([for (final a in picked) a.url],
        names: {for (final a in picked) a.url: a.name});
    if (!mounted) return;
    setState(() {
      _result = result;
      _step = _Step.done;
    });
    _focusMain();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Import from Stremio'),
      body: switch (_step) {
        _Step.code => _codeView(),
        _Step.list => _listView(),
        _Step.importing => const Center(child: CircularProgressIndicator()),
        _Step.done => _message(addonImportSummary(_result!), tr('Done'),
            () => Navigator.of(context).pop()),
        _Step.failed => _message(_error ?? '', tr('Try again'), _newCode),
      },
    );
  }

  Widget _codeView() {
    final code = _code;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(tr(
            'Copy the add-ons from your Stremio account. Nothing is changed on your Stremio account.')),
        const SizedBox(height: 20),
        if (code == null)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 28,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: code.link, size: 170),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('On your phone, scan the code or open')),
                  const SizedBox(height: 4),
                  SelectableText(code.link.replaceFirst('https://', ''),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(tr('Code')),
                  Text(code.code,
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text(
                      tr('Then sign in to Stremio there. This page continues on its own.'),
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            focusNode: _mainFocus,
            onPressed: _newCode,
            icon: const Icon(Icons.refresh),
            label: Text(tr('New code')),
          ),
        ),
      ],
    );
  }

  Widget _listView() {
    final service = context.read<ArchiveService>();
    if (_addons.isEmpty) {
      return _message(
          tr('Your Stremio account has no add-ons VesperTV can copy.'),
          tr('Done'),
          () => Navigator.of(context).pop());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('Your Stremio add-ons. Untick any you don\'t want.')),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            focusNode: _mainFocus,
            onPressed: _picked.isEmpty ? null : _import,
            icon: const Icon(Icons.download_done),
            label: Text(tr('Add {n} add-ons', {'n': _picked.length})),
          ),
        ),
        const SizedBox(height: 8),
        for (final a in _addons)
          CheckboxListTile(
            value: _picked.contains(a.url),
            title: Text(a.name),
            subtitle: _isUnsupportedAddon(a.url)
                ? Text(tr("Can't play in VesperTV"))
                : service.hasSource(a.url)
                    ? Text(tr('Already added'))
                    : Text(Uri.parse(a.url).host,
                        style: const TextStyle(color: Colors.white54)),
            onChanged: (v) => setState(
                () => v == true ? _picked.add(a.url) : _picked.remove(a.url)),
          ),
      ],
    );
  }

  Widget _message(String text, String button, VoidCallback onPressed) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(text),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            focusNode: _mainFocus,
            onPressed: onPressed,
            child: Text(button),
          ),
        ),
      ],
    );
  }
}
