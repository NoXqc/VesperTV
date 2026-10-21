import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../services/app_preferences.dart';
import '../../widgets/settings_scaffold.dart';

/// Settings > General > Remote tips: a QR code to the site's cheat sheet
/// (`docs/remote.html`) of every hold menu and hidden remote move — a TV
/// can't open a link, a phone held next to it can (users asked for a
/// how-to, 2026-10-21).
class RemoteTipsScreen extends StatelessWidget {
  const RemoteTipsScreen({super.key});

  static const url = 'https://vespertv.app/remote.html';

  @override
  Widget build(BuildContext context) {
    final tv = context.read<AppPreferences>().isTelevision;
    return SettingsScaffold(
      title: tr('Remote tips'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Every hold menu and remote shortcut, on one page: hold OK on channels, groups and posters, the side panel on ← in full screen, Multiview, Sports Trak and more.')),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: url, size: 170),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Scan with your phone, or open')),
                  const SizedBox(height: 4),
                  const SelectableText('vespertv.app/remote.html',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if (!tv) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      autofocus: true,
                      onPressed: () => launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(tr('Open')),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            tr('The basics: hold OK (about half a second) opens a menu almost everywhere. Back always steps out one level. OK twice on a channel = full screen.'),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
