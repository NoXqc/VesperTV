import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/storage_service.dart';
import '../../services/stream_badges.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/stream_badge_row.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'phone_link_screen.dart';
import 'settings_catalog.dart' show SettingsCategory;
import 'settings_menu_screen.dart' show SettingsPaneHeader;

/// Settings > Playback > Stream badges: the address of a Nuvio / Fusion
/// badge pack ([StreamBadges]). Same field/Save layout as Custom posters.
class StreamBadgesScreen extends StatefulWidget {
  const StreamBadgesScreen({super.key});

  @override
  State<StreamBadgesScreen> createState() => _StreamBadgesScreenState();
}

class _StreamBadgesScreenState extends State<StreamBadgesScreen> {
  late final TextEditingController _controller;
  final _fieldFocus = FocusNode();
  final _saveFocus = FocusNode();
  bool _busy = false;

  StreamBadges get _badges => StreamBadges.instance;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<StorageService>().getStreamBadgesUrl(),
    );
    HardwareKeyboard.instance.addHandler(_handleFieldEscapeKey);
    _badges.ensureLoaded(switchedOff: true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleFieldEscapeKey);
    _fieldFocus.dispose();
    _saveFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Down out of the field (EditableText keeps arrow keys); see
  /// `TmdbSettingsScreen._handleApiKeyFieldEscapeKey`.
  bool _handleFieldEscapeKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return false;
    if (FocusManager.instance.primaryFocus != _fieldFocus) return false;
    _saveFocus.requestFocus();
    return true;
  }

  /// "From phone": a pack address is long; it lands in the field, Save
  /// focused.
  Future<void> _fromPhone() async {
    final link = await PhoneLinkScreen.open(
      context,
      title: tr('Stream badges'),
      kind: PairingKind.badges,
    );
    if (link == null || !mounted) return;
    _controller.text = link;
    _saveFocus.requestFocus();
  }

  Future<void> _save(String value) async {
    final address = value.trim();
    if (address.isEmpty) return _remove();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final (pack, body) = await _badges.fetch(address);
      await _badges.use(address, pack, body);
      if (!mounted) return;
      _controller.text = _badges.url;
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Saved. Media Hub sources now show these badges.')),
        ),
      );
    } on StreamBadgeError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.detail == null
                ? tr('This address is not a badge pack.')
                : tr('Could not download the badge pack ({error}).', {
                    'error': e.detail!,
                  }),
          ),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    await _badges.remove();
    if (!mounted) return;
    _controller.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr("Badge pack removed: sources show VesperTV's own tags."),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Stream badges'),
      body: ListenableBuilder(
        listenable: Listenable.merge([_badges.pack, _badges.matched]),
        builder: (context, _) {
          final saved = _badges.url.isNotEmpty;
          final pack = _badges.pack.value;
          return ListView(
            // Sized to its rows: a floating panel hugs them.
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tr(
                  'Show picture badges such as 4K, Dolby Vision or Atmos on Media Hub sources. Paste the address of a badge pack made for Nuvio or Fusion (their badge URL).',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  "Without a pack, sources show VesperTV's own tags. Leave empty to turn it off.",
                ),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              if (saved) ...[
                StreamBadgesSwitch(badges: _badges),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              TvTextFieldGate(
                focusNode: _fieldFocus,
                builder: (context, readOnly) => TextField(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  readOnly: readOnly,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _save,
                  decoration: InputDecoration(
                    labelText: tr('Badge pack address'),
                    hintText: 'https://…/badges.json',
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
                    focusNode: _saveFocus,
                    onPressed: _busy ? null : () => _save(_controller.text),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(tr('Save')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _fromPhone,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(tr('From phone')),
                  ),
                  if (saved)
                    OutlinedButton(
                      onPressed: _busy ? null : _remove,
                      child: Text(tr('Remove')),
                    ),
                ],
              ),
              if (saved && pack != null) StreamBadgePreview(pack),
            ],
          );
        },
      ),
    );
  }
}

/// The pack's on/off switch: off keeps the pack (sources show VesperTV's
/// own tags until it's back on); Remove forgets it.
class StreamBadgesSwitch extends StatelessWidget {
  const StreamBadgesSwitch(
      {super.key, required this.badges, this.autofocus = false});

  final StreamBadges badges;
  final bool autofocus;

  /// The pack file's name (`GOLD-NONAMES.json`), else its address.
  static String packName(String url) {
    final path = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty);
    if (path == null || path.isEmpty) return url;
    return Uri.decodeComponent(path.last);
  }

  @override
  Widget build(BuildContext context) {
    final on = badges.on;
    final pack = badges.pack.value;
    return SettingRow(
      autofocus: autofocus,
      icon: Icons.power_settings_new,
      title: tr('Show stream badges'),
      subtitle: [
        packName(badges.url),
        if (pack != null)
          tr('{n} badges in this pack', {'n': '${pack.badges.length}'}),
      ].join(' · '),
      toggled: on,
      trailing: GlassSwitch(value: on),
      onTap: () async {
        await badges.setOn(!on);
        if (!on) badges.ensureLoaded();
      },
    );
  }
}

/// Media Hub sources > Stream badges (a pack pasted in Add a source lands
/// here): the switch, change or remove the pack, and its badges.
class StreamBadgesPane extends StatefulWidget {
  const StreamBadgesPane({super.key, this.header = true});

  /// The pane's title block (the sources rail); a phone page has its own.
  final bool header;

  @override
  State<StreamBadgesPane> createState() => _StreamBadgesPaneState();
}

class _StreamBadgesPaneState extends State<StreamBadgesPane> {
  StreamBadges get _badges => StreamBadges.instance;

  @override
  void initState() {
    super.initState();
    _badges.ensureLoaded(switchedOff: true);
  }

  Future<void> _change() => openSettingsPage<void>(
        context,
        (_) => const StreamBadgesScreen(),
        floating: true,
      );

  Future<void> _remove() async {
    await _badges.remove();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr("Badge pack removed: sources show VesperTV's own tags."),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_badges.pack, _badges.matched]),
        builder: (context, _) {
          final saved = _badges.url.isNotEmpty;
          final pack = _badges.pack.value;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header)
                  SettingsPaneHeader(
                    category: SettingsCategory(
                      id: 'stream_badges',
                      icon: Icons.local_offer_outlined,
                      title: tr('Stream badges'),
                      description: tr(
                        'Show picture badges such as 4K, Dolby Vision or Atmos on Media Hub sources. Paste the address of a badge pack made for Nuvio or Fusion (their badge URL).',
                      ),
                      sections: const [],
                    ),
                  ),
                if (saved) StreamBadgesSwitch(badges: _badges),
                SettingRow(
                  icon: Icons.link,
                  title:
                      saved ? tr('Change badge pack') : tr('Add a badge pack'),
                  subtitle: tr('Its address, typed or from your phone'),
                  trailing: const SettingValue(),
                  onTap: _change,
                ),
                if (saved)
                  SettingRow(
                    icon: Icons.delete_outline,
                    title: tr('Remove badge pack'),
                    subtitle: tr("Sources show VesperTV's own tags"),
                    onTap: _remove,
                  ),
                if (saved && pack != null) StreamBadgePreview(pack),
              ],
            ),
          );
        },
      );
}

/// Every badge of the pack in use, so the viewer sees what it looks like.
/// Focusable as a whole: Down from the buttons scrolls it into view.
class StreamBadgePreview extends StatelessWidget {
  const StreamBadgePreview(this.pack, {super.key});
  final StreamBadgePack pack;

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (focused) {
          if (focused) Scrollable.ensureVisible(context);
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('{n} badges in this pack',
                        {'n': '${pack.badges.length}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (pack.skipped > 0)
                    Text(
                      tr('{n} could not be read and are left out.', {
                        'n': '${pack.skipped}',
                      }),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final badge in pack.badges)
                        StreamBadgeChip(badge: badge, height: 22),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
}
