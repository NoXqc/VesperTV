import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/playlist_profile.dart';
import '../services/playlist_manager.dart';
import '../services/storage_service.dart';
import '../utils/refined_finish.dart';
import 'popup_surface.dart';

/// Days before the provider's expiry date the reminder starts.
const providerExpiryWarnDays = 7;

/// The enabled playlists whose provider account ends within
/// [providerExpiryWarnDays] days or ended in the last 30, soonest first,
/// with the whole days left (0 = today, negative = ended). Only Xtream
/// accounts say when they end ([PlaylistProfile.expiresAt]).
List<(PlaylistProfile, int)> expiringPlaylists(
    Iterable<PlaylistProfile> playlists, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <(PlaylistProfile, int)>[];
  for (final p in playlists) {
    final at = p.expiresAt;
    if (!p.enabled || at == null) continue;
    final local = at.toLocal();
    final days =
        DateTime(local.year, local.month, local.day).difference(today).inDays;
    if (days <= providerExpiryWarnDays && days >= -30) out.add((p, days));
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// "Provider expires in 5 days" (Kal-el23, Discord 2026-11-18, from another
/// app): once a day, a few seconds after the app opens or comes back, a card
/// at the bottom right like the reminders (no focus taken, nothing stops),
/// listing the playlists whose subscription ends within a week or has
/// ended. Device-wide: the day it last showed is kept on this device.
class ProviderExpiryOverlay extends StatefulWidget {
  const ProviderExpiryOverlay({super.key});

  @override
  State<ProviderExpiryOverlay> createState() => _ProviderExpiryOverlayState();
}

class _ProviderExpiryOverlayState extends State<ProviderExpiryOverlay>
    with WidgetsBindingObserver {
  List<(PlaylistProfile, int)>? _shown;
  Timer? _check, _hide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule(const Duration(seconds: 20));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule(const Duration(seconds: 8));
    } else {
      _check?.cancel();
    }
  }

  /// After the splash / a warm return has settled (playlists loaded).
  void _schedule(Duration after) {
    _check?.cancel();
    _check = Timer(after, _maybeShow);
  }

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    final now = DateTime.now();
    final today = _day(now);
    if (storage.getProviderExpiryNoticeDay() == today) return;
    final list =
        expiringPlaylists(context.read<PlaylistManager>().profiles, now);
    if (list.isEmpty) return;
    await storage.setProviderExpiryNoticeDay(today);
    if (!mounted) return;
    debugPrint('ProviderExpiry: ${list.length} playlist(s), soonest '
        '${list.first.$2} day(s)');
    setState(() => _shown = list);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  void dispose() {
    _check?.cancel();
    _hide?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static String _when(int days) => days < 0
      ? tr('Subscription ended')
      : days == 0
          ? tr('Subscription ends today')
          : days == 1
              ? tr('Subscription ends tomorrow')
              : tr('Subscription ends in {days} days', {'days': days});

  @override
  Widget build(BuildContext context) {
    final list = _shown;
    if (list == null) return const SizedBox.shrink();
    final first = list.first.$2;
    const warn = Color(0xFFFFB74D);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: IgnorePointer(
              child: Material(
                color: transparentPopups(context)
                    ? Colors.transparent
                    : RefinedFinish.surface(context, const Color(0xFA15171C)),
                elevation: transparentPopups(context) ? 0 : 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: transparentPopups(context)
                      ? BorderSide.none
                      : const BorderSide(color: warn),
                ),
                child: PopupTextShadow(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: warn, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_when(first),
                                  style: const TextStyle(
                                      color: warn,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                              const SizedBox(height: 6),
                              for (final (p, days) in list.take(4))
                                Text(
                                    list.length == 1
                                        ? p.name
                                        : '${p.name} · ${_when(days)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  tr('Renew with your provider so it keeps playing.'),
                                  style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
