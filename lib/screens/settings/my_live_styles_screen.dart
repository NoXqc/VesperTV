import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/app_preferences.dart';
import '../../services/live_group_styles.dart';
import '../../services/my_live_styles.dart';
import '../../services/phone_pairing_service.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/live_style_picker.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'phone_link_screen.dart';

/// Where a viewer brings in live styles of their own (`MyLiveStyles`;
/// owner, 2026-11-27): a link to a style file or the style text, typed,
/// pasted (computers) or sent from the phone; their styles listed below,
/// OK = remove. Opened from the gallery (Colour… > Live styles… > Your own
/// styles…) and Settings > Appearance > Look > Your live styles.
class MyLiveStylesScreen extends StatefulWidget {
  const MyLiveStylesScreen({super.key});

  /// The format and a starter file, on the site.
  static const howToUrl = 'vespertv.app/styles/make.html';

  /// Small on purpose (owner: "not too big ... TV only"): a TV can't open a
  /// link, a phone or computer can.
  static const qrSize = 96.0;

  static Future<void> open(BuildContext context) =>
      openSettingsPage<void>(context, (_) => const MyLiveStylesScreen());

  @override
  State<MyLiveStylesScreen> createState() => _MyLiveStylesScreenState();
}

class _MyLiveStylesScreenState extends State<MyLiveStylesScreen> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _importFocus = FocusNode();
  bool _busy = false;

  MyLiveStyles get _mine => MyLiveStyles.instance;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_downFromField);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_downFromField);
    _controller.dispose();
    _fieldFocus.dispose();
    _importFocus.dispose();
    super.dispose();
  }

  /// Down out of the field to Import (see `StreamBadgesScreen`).
  bool _downFromField(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return false;
    if (FocusManager.instance.primaryFocus != _fieldFocus) return false;
    if (TvTextFieldGate.isEditing(_fieldFocus)) return false;
    _importFocus.requestFocus();
    return true;
  }

  Future<void> _fromPhone() async {
    final text = await PhoneLinkScreen.open(
      context,
      title: tr('Your live styles'),
      kind: PairingKind.styles,
    );
    if (text == null || !mounted) return;
    _controller.text = text;
    _importFocus.requestFocus();
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _fieldFocus.requestFocus();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await _mine.import(text);
      if (!mounted) return;
      _controller.clear();
      messenger.showSnackBar(SnackBar(
        content: Text([
          result.ids.length == 1
              ? tr(
                  '1 style imported. Hold OK on a group > Colour… > Live styles… to use it.')
              : tr(
                  '{n} styles imported. Hold OK on a group > Colour… > Live styles… to use them.',
                  {'n': '${result.ids.length}'}),
          if (result.skipped > 0)
            tr('{n} left out: nothing this version can draw.',
                {'n': '${result.skipped}'}),
        ].join(' ')),
      ));
    } on MyStylesError catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade900,
        content: Text(switch (e.problem) {
          MyStylesProblem.download => tr(
              'Could not download the style file ({error}).',
              {'error': e.detail ?? ''}),
          MyStylesProblem.tooBig => tr('This is too big for a style file.'),
          MyStylesProblem.nothingUsable => tr(
              'No style in it can be drawn: check the shapes and motions it uses.'),
          MyStylesProblem.notStyles => tr(
              'This is not a live style. Paste a link to a style file or the style itself.'),
        }),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(LiveGroupStyle style) async {
    final link = _mine.linkOf(style.id);
    final count = link == null ? 1 : _mine.countFrom(link);
    final ok = await showGlassMenu<bool>(
      context: context,
      builder: (context) => GlassMenuDialog(
        maxWidth: 380,
        title: Text(tr('Remove {name}?', {'name': style.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (link != null && count > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Text(
                  tr('It came from a link with {n} styles: they all go (the link would bring it back).',
                      {'n': '$count'}),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            TvDialogOption(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Remove')),
            ),
            TvDialogOption(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('Cancel')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _mine.remove(style.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.white60, fontSize: 12);
    return SettingsScaffold(
      title: tr('Your live styles'),
      body: ValueListenableBuilder<List<LiveGroupStyle>>(
        valueListenable: LiveGroupStyles.instance.styles,
        builder: (context, all, _) {
          final mine = [
            for (final s in all)
              if (s.isMine) s
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tr(
                  'Make your own moving backgrounds for groups and bring them in here: a link to a style file, or the style itself.')),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      tr('How to make one, with a starter file: {address}. An AI app connected to VesperTV can also make one for you.',
                          {'address': MyLiveStylesScreen.howToUrl}),
                      style: muted,
                    ),
                  ),
                  // TV only: scan the how-to page with the phone.
                  if (context.read<AppPreferences>().isTelevision) ...[
                    const SizedBox(width: 12),
                    Container(
                      key: const ValueKey('how-to-qr'),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: QrImageView(
                        data: 'https://${MyLiveStylesScreen.howToUrl}',
                        size: MyLiveStylesScreen.qrSize,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TvTextFieldGate(
                focusNode: _fieldFocus,
                builder: (context, readOnly) => TextField(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  readOnly: readOnly,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onSubmitted: (_) => _importFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: tr('Link or style'),
                    hintText: 'https://…/my-styles.json',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    focusNode: _importFocus,
                    onPressed: _busy ? null : _import,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(tr('Import')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _fromPhone,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(tr('From phone')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (mine.isEmpty)
                Text(tr('No styles of your own yet.'), style: muted)
              else ...[
                Text(
                  tr('Your styles'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(tr('OK on a style removes it.'), style: muted),
                const SizedBox(height: 6),
                for (final style in mine)
                  TvDialogOption(
                    key: ValueKey('my-style-${style.id}'),
                    padding: const EdgeInsets.all(3),
                    onPressed: () => _remove(style),
                    child: LiveStylePreview(
                      style: style,
                      subtitle: _mine.linkOf(style.id) == null
                          ? null
                          : Uri.tryParse(_mine.linkOf(style.id)!)?.host,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
