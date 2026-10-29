import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/archive_posters.dart';
import '../../services/archive_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_text_field_gate.dart';

/// Settings > Media Hub > Custom posters: the [ArchivePosters] URL pattern.
/// Same field/Save layout as `TmdbSettingsScreen`.
class ArchivePostersScreen extends StatefulWidget {
  const ArchivePostersScreen({super.key});

  @override
  State<ArchivePostersScreen> createState() => _ArchivePostersScreenState();
}

class _ArchivePostersScreenState extends State<ArchivePostersScreen> {
  static const _example =
      'https://images.metahub.space/poster/medium/{imdb_id}/img';
  late final TextEditingController _controller;
  final _fieldFocus = FocusNode();
  final _saveFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: context.read<StorageService>().getArchivePosterPattern());
    HardwareKeyboard.instance.addHandler(_handleFieldEscapeKey);
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

  Future<void> _save(String value) async {
    final pattern = value.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (pattern.isNotEmpty &&
        !ArchivePosters.placeholders.any(pattern.contains)) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Add {imdb_id} or {tmdb_id} where the title goes.')),
          backgroundColor: Colors.red.shade900));
      return;
    }
    await context.read<StorageService>().setArchivePosterPattern(pattern);
    ArchivePosters.pattern = pattern;
    if (!mounted) return;
    context.read<ArchiveService>().postersChanged();
    _controller.text = pattern;
    messenger.showSnackBar(SnackBar(
        content: Text(pattern.isEmpty
            ? tr('Custom posters off: Media Hub shows the sources\' posters.')
            : tr('Saved. Media Hub posters now come from this address.'))));
  }

  @override
  Widget build(BuildContext context) {
    final on = context.watch<StorageService>().getArchivePosterPattern();
    return SettingsScaffold(
      title: tr('Custom posters'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Show Media Hub posters from a poster service of your choice, for example one that adds ratings. Paste its poster address with {imdb_id} (or {tmdb_id}) where the title goes; include your own key if the service needs one.')),
          const SizedBox(height: 12),
          Text(
              tr('When a title has no matching ID, its normal poster is shown. Leave empty to turn it off.'),
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 12),
          SelectableText(tr('Example: {url}', {'url': _example}),
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 20),
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
                labelText: tr('Poster address'),
                hintText: _example,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            OutlinedButton(
                focusNode: _saveFocus,
                onPressed: () => _save(_controller.text),
                child: Text(tr('Save'))),
            if (on.isNotEmpty)
              OutlinedButton(
                  onPressed: () => _save(''), child: Text(tr('Turn off'))),
          ]),
        ],
      ),
    );
  }
}
