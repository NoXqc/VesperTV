import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/storage_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

/// Small behaviour switches that don't belong to one feature's own screen —
/// a home for future ones too (planned candidates: start-on tab, default
/// picture fit, preferred audio language, 12/24 h time, confirm on exit).
/// Android only: Windows always resumes the last channel and has its own
/// Multiview without the tip (SettingsMenuScreen hides the entry there).
///
/// No custom D-pad handling — see SettingsMenuScreen's doc comment.
class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  late final StorageService _storage = context.read<StorageService>();
  late bool _resumeAtStartup = _storage.getResumeLastChannelAtStartup();
  late bool _showMultiviewTip = !_storage.getMultiviewHideTips();

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: 'General',
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionLabel('Startup'),
                  const SizedBox(height: 4),
                  TvSwitchListTile(
                    title: const Text('Resume last channel at startup'),
                    subtitle: const Text(
                        'Opens the last live channel full screen after the '
                        'splash. Off: a "Hold > to resume" reminder instead.'),
                    value: _resumeAtStartup,
                    onChanged: (v) {
                      setState(() => _resumeAtStartup = v);
                      _storage.setResumeLastChannelAtStartup(v);
                    },
                  ),
                  const Divider(height: 32),
                  const SectionLabel('Multiview'),
                  const SizedBox(height: 4),
                  TvSwitchListTile(
                    title: const Text('Show the Multiview tip'),
                    subtitle: const Text(
                        'The connections reminder shown when opening '
                        'Multiview.'),
                    value: _showMultiviewTip,
                    onChanged: (v) {
                      setState(() => _showMultiviewTip = v);
                      _storage.setMultiviewHideTips(!v);
                    },
                  ),
                ],
              ),
            ));
  }
}
