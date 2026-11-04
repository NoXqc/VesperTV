import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/cloud_transfer.dart';
import '../../services/device_transfer.dart';
import '../../services/parental_pin.dart';
import '../../utils/time_format.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'transfer_screen.dart' show TransferCodeKey;

String _syncError(TransferException error) => switch (error.kind) {
      TransferError.tooBig => tr(
          'This setup is too big to upload. Use the same-Wi-Fi transfer instead.'),
      TransferError.notFound || TransferError.closed => tr(
          'Nothing was found for that code. Check it — the upload may also have expired or been deleted.'),
      TransferError.wrongCode ||
      TransferError.invalid =>
        tr('That code isn\'t right. Check it on the other device.'),
      _ => tr(
          'Couldn\'t reach the VesperTV transfer server. Check this device\'s internet connection and try again.'),
    };

/// Settings > Device & data > Sync. The app owns lifecycle and live apply;
/// this route only observes the service and performs explicit user actions.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _nodes = <String, FocusNode>{};
  final _back = FocusNode();
  bool _busy = false;
  String? _error;
  SyncStatus? _shown;

  FocusNode _node(String id) => _nodes.putIfAbsent(id, FocusNode.new);

  void _focus(String id) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node(id).requestFocus();
      });

  Future<void> _run(String returnTo, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on TransferException catch (e) {
      if (mounted) setState(() => _error = _syncError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        final status = context.read<CloudSyncService>().status;
        _focus(status == SyncStatus.on ? returnTo : 'setup');
      }
    }
  }

  Future<bool> _unlock() async {
    if (!context.read<ParentalPin>().isSet) return true;
    return promptForPin(context);
  }

  Future<void> _showCode(String code, {bool first = false}) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _SyncCodeScreen(recovery: code, first: first)));
  }

  Future<bool> _confirm(String title, String detail) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => _SyncConfirmScreen(title: title, detail: detail))) ??
      false;

  Widget _tile(String id, IconData icon, String title, VoidCallback tap) =>
      TvMenuTile(
        key: ValueKey('sync-$id'),
        focusNode: _node(id),
        icon: icon,
        title: title,
        onTap: () {
          if (!_busy) tap();
        },
      );

  @override
  void dispose() {
    _back.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncService>();
    final on = sync.status == SyncStatus.on;
    final ids =
        on ? ['now', 'link', 'recovery', 'reset', 'stop'] : ['setup', 'join'];
    if (_shown != sync.status) {
      _shown = sync.status;
      _focus(ids.first);
    }
    return withTvThemeIfNeeded(
      context,
      (context) => _SyncNavigation(
        nodes: [_back, for (final id in ids) _node(id)],
        child: SettingsScaffold(
          title: tr('Sync'),
          backFocusNode: _back,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      tr('Keep your setup and watch progress together across devices. No account needed.'),
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Text(
                      tr('Some changes appear after you restart VesperTV. Profile photos and imported M3U files do not sync.'),
                      style: const TextStyle(color: Colors.white54)),
                  if (sync.status == SyncStatus.revoked) ...[
                    const SizedBox(height: 16),
                    Text(tr(
                        'The sync code was reset on another device. Link this device again.')),
                  ],
                  const SizedBox(height: 16),
                  if (on) ...[
                    Text(sync.lastSync == null
                        ? tr('Not synced yet')
                        : tr('Last sync: {time}', {
                            'time':
                                TimeFormat.dateTime(sync.lastSync!.toLocal())
                          })),
                    _tile(
                        'now',
                        Icons.sync,
                        tr('Sync now'),
                        () => _run('now', () async {
                              if (!sync.syncing) await sync.syncNow();
                            })),
                    _tile(
                        'link',
                        Icons.add_to_queue,
                        tr('Link a device'),
                        () => _run('link', () async {
                              final link = await sync.createLinkCode();
                              if (!context.mounted || link == null) return;
                              await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          _SyncCodeScreen(link: link)));
                            })),
                    _tile(
                        'recovery',
                        Icons.key,
                        tr('Show recovery code'),
                        () => _run('recovery', () async {
                              if (!await _unlock() || !mounted) {
                                return;
                              }
                              final code = await sync.recoveryCode();
                              if (code != null) await _showCode(code);
                            })),
                    _tile(
                        'reset',
                        Icons.lock_reset,
                        tr('Reset sync code'),
                        () => _run('reset', () async {
                              if (!await _unlock() || !mounted) {
                                return;
                              }
                              if (!await _confirm(tr('Reset sync code'),
                                  tr('Other devices will stop syncing until you link them again. Save the new recovery code.'))) {
                                return;
                              }
                              if (!mounted) return;
                              await _showCode(await sync.resetCode(),
                                  first: true);
                            })),
                    _tile(
                        'stop',
                        Icons.sync_disabled,
                        tr('Stop syncing on this device'),
                        () => _run('stop', () async {
                              if (!await _confirm(
                                  tr('Stop syncing on this device'),
                                  tr('Your data stays on this device. Other devices keep syncing.'))) {
                                return;
                              }
                              if (mounted) await sync.stop();
                            })),
                  ] else ...[
                    _tile(
                        'setup',
                        Icons.sync,
                        tr('Set up sync'),
                        () => _run('now', () async {
                              await sync.setUp();
                              final code = await sync.recoveryCode();
                              if (code != null) {
                                await _showCode(code, first: true);
                              }
                            })),
                    _tile(
                        'join',
                        Icons.input,
                        tr('I have a code'),
                        () => _run('now', () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => const _SyncJoinScreen()));
                            })),
                  ],
                  if (_busy || sync.syncing) const LinearProgressIndicator(),
                  if (_error != null || sync.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error ?? _syncError(sync.lastError!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Explicit traversal also includes the header Back button. Non-lazy content
/// keeps every destination mounted; ensureVisible uses an immediate jump.
class _SyncNavigation extends StatelessWidget {
  const _SyncNavigation({required this.nodes, required this.child});
  final List<FocusNode> nodes;
  final Widget child;

  void _move(int step) {
    final available =
        nodes.where((n) => n.context != null && n.canRequestFocus).toList();
    if (available.isEmpty) return;
    final current = available.indexWhere((n) => n.hasFocus);
    final next = (current + step).clamp(0, available.length - 1);
    final node = available[next];
    node.requestFocus();
    final ctx = node.context;
    if (ctx != null) Scrollable.ensureVisible(ctx);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: child,
      );
}

class _SyncConfirmScreen extends StatefulWidget {
  const _SyncConfirmScreen({required this.title, required this.detail});
  final String title, detail;
  @override
  State<_SyncConfirmScreen> createState() => _SyncConfirmScreenState();
}

class _SyncConfirmScreenState extends State<_SyncConfirmScreen> {
  final _cancel = FocusNode();
  final _confirm = FocusNode();
  final _back = FocusNode();

  @override
  void dispose() {
    _cancel.dispose();
    _confirm.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SyncNavigation(
        nodes: [_back, _cancel, _confirm],
        child: SettingsScaffold(
          title: widget.title,
          backFocusNode: _back,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.detail),
                  TvMenuTile(
                      focusNode: _cancel,
                      autofocus: true,
                      icon: Icons.close,
                      title: tr('Cancel'),
                      onTap: () => Navigator.of(context).pop(false)),
                  TvMenuTile(
                      focusNode: _confirm,
                      icon: Icons.check,
                      title: widget.title,
                      onTap: () => Navigator.of(context).pop(true)),
                ]),
          ),
        ),
      );
}

class _SyncCodeScreen extends StatefulWidget {
  const _SyncCodeScreen({this.recovery, this.link, this.first = false});
  final String? recovery;
  final CloudTransfer? link;
  final bool first;

  @override
  State<_SyncCodeScreen> createState() => _SyncCodeScreenState();
}

class _SyncCodeScreenState extends State<_SyncCodeScreen> {
  Timer? _timer;
  final _done = FocusNode();
  final _back = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.link != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _done.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final remaining = link?.expires.difference(DateTime.now()).inSeconds ?? 0;
    final active = link == null || remaining > 0;
    final code = widget.recovery ?? link!.code;
    return _SyncNavigation(
      nodes: [_back, _done],
      child: SettingsScaffold(
        title: link == null ? tr('Recovery code') : tr('Link a device'),
        backFocusNode: _back,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(link == null
                ? tr(
                    'Save this code. It\'s the only way back in if you lose all your devices. We can\'t recover it.')
                : tr(
                    'On the other device, open Settings > Device & data > Sync > I have a code.')),
            const SizedBox(height: 20),
            if (active) ...[
              // Plain text QR: codes stay on screen, never in a web URL.
              ExcludeFocus(
                  child: SelectableText(
                link == null ? code : formatCloudCode(code),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              )),
              const SizedBox(height: 16),
              ColoredBox(
                  color: Colors.white,
                  child: QrImageView(data: code, size: 180)),
              if (link != null) ...[
                const SizedBox(height: 12),
                Text(tr('Expires in {time}', {
                  'time':
                      '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                })),
              ],
            ] else
              Text(tr('This code has expired. Go back and start again.')),
            const SizedBox(height: 16),
            TvMenuTile(
                focusNode: _done,
                autofocus: true,
                icon: Icons.check,
                title:
                    widget.first ? tr('I saved my recovery code') : tr('Done'),
                onTap: () => Navigator.of(context).pop()),
          ]),
        ),
      ),
    );
  }
}

class _SyncJoinScreen extends StatefulWidget {
  const _SyncJoinScreen();
  @override
  State<_SyncJoinScreen> createState() => _SyncJoinScreenState();
}

class _SyncJoinScreenState extends State<_SyncJoinScreen> {
  final _controller = TextEditingController();
  final _field = FocusNode();
  final _mode = FocusNode();
  final _join = FocusNode();
  final _back = FocusNode();
  final _keys = List.generate(12, (_) => FocusNode());
  bool _recovery = false, _busy = false;
  String? _error;

  String get _clean => _controller.text.replaceAll(RegExp(r'[\s-]'), '');
  bool get _valid =>
      _recovery ? _clean.length == 26 : RegExp(r'^\d{16}$').hasMatch(_clean);

  Future<void> _submit() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final sync = context.read<CloudSyncService>();
    try {
      if (_recovery) {
        if (!await sync.joinWithRecoveryCode(_controller.text)) {
          throw const TransferException(TransferError.wrongCode);
        }
      } else {
        await sync.joinWithLinkCode(_clean);
      }
      if (!mounted) return;
      // A join can return normally with a network error: keep the code here
      // so the user can retry, rather than presenting success.
      if (sync.lastError != null) throw sync.lastError!;
      if (sync.status != SyncStatus.on) {
        throw const TransferException(TransferError.invalid);
      }
      Navigator.of(context).pop();
    } on TransferException catch (e) {
      if (mounted) setState(() => _error = _syncError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _join.requestFocus();
      }
    }
  }

  void _type(String value) {
    if (_busy) return;
    if (value == 'ok') {
      unawaited(_submit());
      return;
    }
    final old = _clean;
    if (value == 'back') {
      _controller.text = old.isEmpty ? '' : old.substring(0, old.length - 1);
    } else if (old.length < 16) {
      _controller.text = old + value;
    }
    setState(() => _error = null);
  }

  void _moveKey(int index, int dr, int dc) {
    final row = (index ~/ 3 + dr).clamp(0, 3);
    if (index < 3 && dr < 0) {
      _field.requestFocus();
      return;
    }
    if (index >= 9 && dr > 0) {
      _join.requestFocus();
      return;
    }
    _keys[row * 3 + (index % 3 + dc).clamp(0, 2)].requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final node in [_field, _mode, _join, _back, ..._keys]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = [_back, _mode, _field, if (!_recovery) ..._keys, _join];
    const labels = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'back',
      '0',
      'ok'
    ];
    return _SyncNavigation(
      nodes: order,
      child: SettingsScaffold(
        title: tr('I have a code'),
        backFocusNode: _back,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_recovery
                ? tr('Enter your 26-character recovery code')
                : tr('Enter the 16-digit link code shown on the other device')),
            TvMenuTile(
                focusNode: _mode,
                icon: Icons.swap_horiz,
                title: _recovery
                    ? tr('Use a link code')
                    : tr('Use a recovery code'),
                onTap: () {
                  if (_busy) return;
                  setState(() {
                    _recovery = !_recovery;
                    _controller.clear();
                    _error = null;
                  });
                  _field.requestFocus();
                }),
            TvTextFieldGate(
                focusNode: _field,
                builder: (context, readOnly) => TextField(
                      key: const ValueKey('sync-code-entry'),
                      controller: _controller,
                      focusNode: _field,
                      autofocus: true,
                      readOnly: readOnly || _busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType:
                          _recovery ? TextInputType.text : TextInputType.number,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: _recovery
                          ? [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9\s-]')),
                              LengthLimitingTextInputFormatter(40)
                            ]
                          : [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16)
                            ],
                      decoration: InputDecoration(
                          labelText: _recovery
                              ? tr('Recovery code')
                              : tr('Link code')),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _join.requestFocus(),
                    )),
            if (!_recovery) ...[
              const SizedBox(height: 12),
              Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var row = 0; row < 4; row++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var col = 0; col < 3; col++)
                      Builder(builder: (context) {
                        final i = row * 3 + col;
                        return CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.arrowUp):
                                  () => _moveKey(i, -1, 0),
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowDown):
                                  () => _moveKey(i, 1, 0),
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowLeft):
                                  () => _moveKey(i, 0, -1),
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowRight):
                                  () => _moveKey(i, 0, 1),
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: TransferCodeKey(
                                    focusNode: _keys[i],
                                    label: labels[i],
                                    enabled:
                                        !_busy && (labels[i] != 'ok' || _valid),
                                    onPressed: () => _type(labels[i]))));
                      }),
                  ]),
              ])),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TvMenuTile(
                focusNode: _join,
                icon: Icons.sync,
                title: tr('Join sync'),
                onTap: _submit),
          ]),
        ),
      ),
    );
  }
}
