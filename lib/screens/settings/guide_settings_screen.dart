import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/app_preferences.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/mode_button.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../l10n/l10n.dart';

/// Settings > Interface > Guide: the Live TV guide's layout (Live or
/// Timeline, full-screen video/transparency, Expand, Compact). Was part of Theme.
///
/// No custom D-pad handling, same as ThemeScreen.
class GuideSettingsScreen extends StatelessWidget {
  const GuideSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();

    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: tr('Guide'),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    tr('Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final option in const [
                        ('live', 'Live'),
                        ('timeline', 'Timeline')
                      ]) ...[
                        Expanded(
                          child: ModeButton(
                            label: tr(option.$2),
                            selected: prefs.guideViewMode == option.$1,
                            onTap: () => prefs.setGuideViewMode(option.$1),
                          ),
                        ),
                        if (option.$1 != 'timeline') const SizedBox(width: 12),
                      ],
                    ],
                  ),
                  if (prefs.guideViewMode == 'timeline') ...[
                    const SizedBox(height: 8),
                    TvSwitchListTile(
                      title: Text(tr('Compact guide')),
                      subtitle: Text(tr(
                          'Shorter Timeline rows so more channels fit in the same space.')),
                      value: prefs.guideCompact,
                      onChanged: prefs.setGuideCompact,
                    ),
                  ],
                  // Android only for now — Windows' preview runs on its
                  // own media_kit player and isn't wired for this yet.
                  if (prefs.guideViewMode == 'timeline' &&
                      defaultTargetPlatform != TargetPlatform.windows) ...[
                    const SizedBox(height: 8),
                    TvSwitchListTile(
                      title: Text(tr('Full-screen video behind the guide')),
                      subtitle: Text(tr(prefs.guideExpanded
                          ? 'The live channel fills the screen behind a see-through guide'
                          : 'The live channel fills the screen behind a see-through guide showing 3 rows')),
                      value: prefs.guideFullVideo,
                      onChanged: prefs.setGuideFullVideo,
                    ),
                    if (prefs.guideFullVideo) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: Text(tr('Guide transparency'))),
                              Text(tr('{percent}%', {
                                'percent': '${prefs.guideTransparency}',
                              })),
                            ]),
                            _RemoteSlider(
                              value: prefs.guideTransparency,
                              onChanged: prefs.setGuideTransparency,
                              child: Slider(
                                value: prefs.guideTransparency.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: tr('{percent}%', {
                                  'percent': '${prefs.guideTransparency}',
                                }),
                                semanticFormatterCallback: (value) => tr(
                                    '{percent}%',
                                    {'percent': '${value.round()}'}),
                                onChanged: (value) =>
                                    prefs.setGuideTransparency(value.round()),
                              ),
                            ),
                            Text(
                              tr('0% is solid; 100% is clear.'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TvSwitchListTile(
                        title: Text(tr('Expand')),
                        subtitle:
                            Text(tr('Fill the screen with the Timeline guide')),
                        value: prefs.guideExpanded,
                        onChanged: prefs.setGuideExpanded,
                      ),
                    ],
                  ],
                ],
              ),
            ));
  }
}

/// The remote's way onto a 0-100 slider: Left/Right change it by 5, Up/Down
/// move on to the next setting. Flutter's Slider took Up/Down as +/- on TV,
/// so the remote was stuck on it (owner, 1.0.57). The Slider itself stays
/// out of D-pad focus and keeps working for touch and mouse.
class _RemoteSlider extends StatefulWidget {
  const _RemoteSlider(
      {required this.value, required this.onChanged, required this.child});

  final int value;
  final ValueChanged<int> onChanged;
  final Widget child;

  @override
  State<_RemoteSlider> createState() => _RemoteSliderState();
}

class _RemoteSliderState extends State<_RemoteSlider> {
  final _focus = FocusNode(debugLabel: 'remote-slider');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final step = key == LogicalKeyboardKey.arrowRight
        ? 5
        : key == LogicalKeyboardKey.arrowLeft
            ? -5
            : 0;
    if (step == 0) return KeyEventResult.ignored;
    widget.onChanged((widget.value + step).clamp(0, 100));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      onFocusChange: (_) => setState(() {}),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: focused
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2),
        ),
        child: ExcludeFocus(child: widget.child),
      ),
    );
  }
}
