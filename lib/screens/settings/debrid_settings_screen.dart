import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/debrid_api.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'archive_sources_screen.dart';

/// Optional Real-Debrid / TorBox keys (bring-your-own, like TMDB's): with
/// one, a Media Hub title that first played as a "being downloaded" clip
/// gets its "Ready" tag as soon as the account has it (`ArchiveReadyWatch`).
/// Many users took this page for the place to add their debrid add-ons
/// (owner, 2026-11-23): it first says it adds nothing to watch and opens
/// Media Hub sources, where content is added.
class DebridSettingsScreen extends StatefulWidget {
  const DebridSettingsScreen({super.key});

  @override
  State<DebridSettingsScreen> createState() => _DebridSettingsScreenState();
}

class _DebridSettingsScreenState extends State<DebridSettingsScreen> {
  late final TextEditingController _realDebrid;
  late final TextEditingController _torBox;
  bool _validating = false;

  final _realDebridFocus = FocusNode();
  final _torBoxFocus = FocusNode();
  final _saveFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _realDebrid =
        TextEditingController(text: storage.getRealDebridToken() ?? '');
    _torBox = TextEditingController(text: storage.getTorBoxKey() ?? '');
    HardwareKeyboard.instance.addHandler(_handleFieldEscapeKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleFieldEscapeKey);
    _realDebridFocus.dispose();
    _torBoxFocus.dispose();
    _saveFocus.dispose();
    _realDebrid.dispose();
    _torBox.dispose();
    super.dispose();
  }

  /// Down out of a focused field — `EditableText` keeps arrow keys for
  /// itself (same fix as `TmdbSettingsScreen._handleApiKeyFieldEscapeKey`).
  bool _handleFieldEscapeKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == _realDebridFocus) {
      _torBoxFocus.requestFocus();
      return true;
    }
    if (focus == _torBoxFocus) {
      _saveFocus.requestFocus();
      return true;
    }
    return false;
  }

  /// Saves both at once (a key is never lost to a failed check), then asks
  /// each service whether its key works.
  Future<void> _save() async {
    final storage = context.read<StorageService>();
    final rd = _realDebrid.text.trim();
    final tb = _torBox.text.trim();
    await storage.setRealDebridToken(rd);
    await storage.setTorBoxKey(tb);
    if (!mounted) return;
    if (rd.isEmpty && tb.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Cleared'))));
      return;
    }
    setState(() => _validating = true);
    final api = DebridApi(storage);
    final rejected = [
      if (rd.isNotEmpty && !await api.checkRealDebrid(rd)) 'Real-Debrid',
      if (tb.isNotEmpty && !await api.checkTorBox(tb)) 'TorBox',
    ];
    if (!mounted) return;
    setState(() => _validating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(rejected.isEmpty
          ? tr('Saved — key verified ✓')
          : tr('Saved, but {service} rejected the key — double-check it',
              {'service': rejected.join(', ')})),
      backgroundColor: rejected.isEmpty ? null : Colors.red.shade900,
    ));
  }

  void _openSources() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ArchiveSourcesScreen()));

  Widget _field(TextEditingController controller, FocusNode focus,
      FocusNode next, String label) {
    return TvTextFieldGate(
      focusNode: focus,
      builder: (context, readOnly) => TextField(
        controller: controller,
        focusNode: focus,
        readOnly: readOnly,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => next.requestFocus(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Debrid accounts'),
      body: ListView(
        // Sized to its rows: a floating panel hugs them.
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          _NotForContent(onOpen: _openSources),
          const SizedBox(height: 20),
          Text(tr('What these keys do'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(tr(
              'Optional. Some debrid sources answer Play with a short "being downloaded" video while your account fetches the title. With your key here, VesperTV asks your account directly and puts a "Ready" tag on the poster as soon as the title is there. Without a key it still works: VesperTV asks the source again every minute.')),
          const SizedBox(height: 12),
          Text(
            tr('Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Kept in VesperTV and only used to read your downloads list.'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _field(_realDebrid, _realDebridFocus, _torBoxFocus,
              tr('Real-Debrid API token')),
          const SizedBox(height: 12),
          _field(_torBox, _torBoxFocus, _saveFocus, tr('TorBox API key')),
          const SizedBox(height: 16),
          OutlinedButton(
            focusNode: _saveFocus,
            onPressed: _validating ? null : _save,
            child: _validating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('Save')),
          ),
        ],
      ),
    );
  }
}

/// The page's first lines: this is not where movies and shows come from.
class _NotForContent extends StatelessWidget {
  const _NotForContent({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr("This page doesn't add movies or shows"),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(tr(
              'To watch with your Real-Debrid or TorBox account, add a Media Hub source that uses it, such as Torrentio or AIOStreams set up with your debrid key. Its movies and shows then appear in the Media Hub.')),
          const SizedBox(height: 12),
          FilledButton.icon(
            autofocus: true,
            onPressed: onOpen,
            icon: const Icon(Icons.add_link),
            label: Text(tr('Open Media Hub sources')),
          ),
        ],
      ),
    );
  }
}
