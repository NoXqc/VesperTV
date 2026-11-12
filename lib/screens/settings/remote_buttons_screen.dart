import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/remote_buttons.dart';
import '../../utils/constants.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';

/// Settings > Backup & devices > Remote buttons ([RemoteButtons]): learn a
/// remote button (press it), then pick what a short press and a hold do.
/// Per viewer, on this device only. The full-screen player's arrows are
/// rows in the Settings list itself ([playerArrowLabel]).
class RemoteButtonsScreen extends StatefulWidget {
  const RemoteButtonsScreen({super.key});

  @override
  State<RemoteButtonsScreen> createState() => _RemoteButtonsScreenState();
}

/// A button's name, translated where it has one.
String remoteButtonName(int keyId) {
  final (name, fallback) = RemoteButtons.describe(keyId);
  return name == null ? tr('Button {key}', {'key': fallback}) : tr(name);
}

/// An action's name, translated (Sports Trak is a brand).
String remoteActionLabel(String? id) {
  final action = RemoteAction.byId(id);
  if (action == null) return tr('Nothing');
  return action.id == 'sports' ? action.label : tr(action.label);
}

class _RemoteButtonsScreenState extends State<RemoteButtonsScreen> {
  final _buttons = RemoteButtons.instance;
  final _learnFocus = FocusNode();
  bool _learning = false;
  Timer? _learnTimeout;

  @override
  void initState() {
    super.initState();
    _buttons.changes.addListener(_changed);
  }

  @override
  void dispose() {
    _buttons.changes.removeListener(_changed);
    _stopLearning();
    _learnFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _stopLearning() {
    _learnTimeout?.cancel();
    _learnTimeout = null;
    _buttons.learning = null;
    _learning = false;
  }

  void _toggleLearn() {
    if (_learning) {
      setState(_stopLearning);
      return;
    }
    setState(() => _learning = true);
    _buttons.learning = _learned;
    // Nothing in 15 s: that button never reaches the app.
    _learnTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(_stopLearning);
      _say(tr(
          'Nothing arrived. If you pressed a button, your device keeps it for itself.'));
    });
  }

  void _learned(KeyDownEvent event) {
    final keyId = event.logicalKey.keyId;
    setState(_stopLearning);
    // Next frame: the key's release is still on its way.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final existing = _buttons.bindingFor(keyId);
      if (existing != null) {
        await _edit(existing);
        return;
      }
      final action = await _pickAction(
          tr('{button}: short press', {'button': remoteButtonName(keyId)}),
          null);
      if (action == null || action.isEmpty) {
        _learnFocus.requestFocus();
        return;
      }
      await _buttons.saveBinding(RemoteBinding(keyId: keyId, short: action));
      _say(tr('{button} set. Hold it too? Open the button below.',
          {'button': remoteButtonName(keyId)}));
      _learnFocus.requestFocus();
    });
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Picks an action: its id, '' for Nothing, null on Back.
  Future<String?> _pickAction(String title, String? current) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final accent = Theme.of(context).colorScheme.primary;
        Widget option(String id, String label, IconData icon) => TvDialogOption(
              autofocus: id == (current ?? ''),
              onPressed: () => Navigator.of(context).pop(id),
              child: Row(children: [
                Icon(icon,
                    size: 20, color: id == (current ?? '') ? accent : null),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
                if (id == (current ?? ''))
                  Icon(Icons.check, size: 18, color: accent),
              ]),
            );
        return SimpleDialog(
          title: Text(title),
          children: [
            option('', tr('Nothing'), Icons.block),
            for (final group in RemoteActionGroup.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(tr(group.label),
                    style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              for (final a in RemoteAction.all.where((a) => a.group == group))
                option(a.id, remoteActionLabel(a.id), a.icon),
            ],
          ],
        );
      },
    );
  }

  /// A learned button: change its short press / hold, or forget it.
  Future<void> _edit(RemoteBinding binding) async {
    final name = remoteButtonName(binding.keyId);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(name),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop('short'),
            child: Text(tr('Short press: {action}',
                {'action': remoteActionLabel(binding.short)})),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('hold'),
            child: Text(tr(
                'Hold: {action}', {'action': remoteActionLabel(binding.hold)})),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('forget'),
            child: Text(tr('Forget this button')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'forget':
        await _buttons.forget(binding.keyId);
      case 'short' || 'hold':
        final hold = choice == 'hold';
        final picked = await _pickAction(
            tr(hold ? '{button}: hold' : '{button}: short press',
                {'button': name}),
            hold ? binding.hold : binding.short);
        if (picked == null) return;
        final next = hold
            ? binding.copyWith(hold: picked, clearHold: picked.isEmpty)
            : binding.copyWith(short: picked, clearShort: picked.isEmpty);
        await _buttons.saveBinding(next);
        if (next.isEmpty) _learnFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bindings = _buttons.bindings;
    return SettingsScaffold(
      title: tr('Remote buttons'),
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Give your remote\'s spare buttons a job in {app}: a short press and a hold each. They work while {app} is open, for this profile on this device.',
              {'app': AppConstants.appName})),
          const SizedBox(height: 12),
          TvMenuTile(
            icon: _learning ? Icons.hourglass_top : Icons.add,
            title: _learning
                ? tr('Press the button on your remote now...')
                : tr('Add a button'),
            subtitle:
                _learning ? tr('OK cancels') : tr('Then choose what it does'),
            autofocus: true,
            focusNode: _learnFocus,
            onTap: _toggleLearn,
          ),
          for (final b in bindings)
            TvMenuTile(
              icon: Icons.settings_remote_outlined,
              title: remoteButtonName(b.keyId),
              subtitle: [
                if (b.short != null)
                  tr('Press: {action}', {'action': remoteActionLabel(b.short)}),
                if (b.hold != null)
                  tr('Hold: {action}', {'action': remoteActionLabel(b.hold)}),
              ].join(' · '),
              onTap: () => _edit(b),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
                tr('OK, Back and the arrows keep their jobs. A button set here only does what you set: a hold you leave on Nothing does nothing.'),
                style: const TextStyle(fontSize: 13, color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}

/// "Side drawer", "Last channel"... for a [PlayerArrow] action id.
String playerArrowLabel(String id) => tr(PlayerArrow.actions
    .firstWhere((a) => a.$1 == id, orElse: () => PlayerArrow.actions.last)
    .$2);
