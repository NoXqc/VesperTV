import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../models/archive_models.dart';
import '../../services/app_preferences.dart';
import '../../services/archive_service.dart';
import '../../services/playlist_manager.dart';
import '../../services/storage_service.dart';
import '../../services/tracker_api.dart';
import '../../services/tracker_sync.dart';
import '../../services/viewer_profile_service.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/hold_to_activate.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/source_profiles.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';

/// Settings > Trakt & Simkl: connect a watch tracker. Signing in is a
/// code on the TV the viewer approves on their phone (nothing typed on the
/// remote). A connected account adds its lists to the Media Hub and gets
/// the Media Hub's plays reported (`WatchTracker`); disconnecting removes
/// both. Accounts are Media Hub sources, so they also travel with Transfer.
///
/// Each profile can have its own account of each kind (Discord, 2026-11-26:
/// "Can Trakt / Simkl be scoped per profile?"): the tiles show the profile
/// in use's account; with several profiles, OK on one opens Profiles / Use
/// another account on this profile / Disconnect, and connecting asks which
/// profiles get it (`ArchiveService.addTracker`).
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key});

  /// More than one profile: accounts can differ between them.
  static bool _several(BuildContext context) {
    final viewers = context.read<ViewerProfileService?>();
    return viewers != null && SourceProfiles.shown(viewers);
  }

  static String _user(ArchiveSource account) =>
      account.tracker!.userName.isEmpty
          ? account.tracker!.kind.label
          : account.tracker!.userName;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final viewers = context.watch<ViewerProfileService?>();
    final several = viewers != null && SourceProfiles.shown(viewers);
    Widget tile(TrackerKind kind, String blurb, {bool autofocus = false}) {
      final account = service.trackerSource(kind);
      final configured = TrackerApi.isConfigured(kind);
      return TvMenuTile(
        autofocus: autofocus,
        icon: account != null ? Icons.check_circle : Icons.link,
        title: kind.label,
        subtitle: account == null
            ? configured
                ? blurb
                : tr('Not available in this build yet')
            : several
                ? tr(
                    'Connected as {name} ({profiles}) — press OK for options', {
                    'name': _user(account),
                    'profiles': SourceProfiles.label(
                        viewers, service.profilesWith(account)),
                  })
                : tr('Connected as {name} — press OK to disconnect',
                    {'name': _user(account)}),
        trailing: const SizedBox.shrink(),
        enabled: account != null || configured,
        onTap: () => account == null
            ? _connect(context, kind)
            : several
                ? _options(context, account)
                : _disconnect(context, account),
      );
    }

    return SettingsScaffold(
      title: tr('Trakt & Simkl'),
      body: ListView(
        // Sized to its rows: a floating panel hugs them.
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Connect a watch tracker: what you watch in the Media Hub is marked as watched on your account, and your lists show up as Media Hub rows. Nothing is sent unless you connect an account.')),
          if (several) ...[
            const SizedBox(height: 8),
            Text(tr(
                'Each profile can have its own account: connect it while that profile is in use.')),
          ],
          const SizedBox(height: 16),
          tile(TrackerKind.trakt, tr('Watchlist and trending rows, scrobbling'),
              autofocus: true),
          tile(TrackerKind.simkl,
              tr('Watching and plan-to-watch rows, scrobbling')),
          const SizedBox(height: 16),
          Text(
            tr('Titles from your lists play through your stream add-ons (Media Hub sources), by IMDb id. Only titles with an IMDb id are reported.'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Text(
            '${tr('Powered by Trakt (trakt.tv) and Simkl (simkl.com).')} '
            '${tr('VesperTV is not affiliated with or endorsed by Trakt or Simkl.')}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Signs in to [kind] for this profile. With several profiles: another
  /// profile's account can be used here without signing in, and a new one
  /// asks which profiles get it ([onlyHere]: this profile, no question).
  Future<void> _connect(BuildContext context, TrackerKind kind,
      {bool onlyHere = false}) async {
    final service = context.read<ArchiveService>();
    final storage = context.read<StorageService>();
    final playlist = context.read<PlaylistManager>();
    final viewers = context.read<ViewerProfileService?>();
    final messenger = ScaffoldMessenger.of(context);
    final several = _several(context);
    final active = viewers?.active.id;
    if (several && !onlyHere && active != null) {
      final others = service.trackerAccounts(kind);
      if (others.isNotEmpty) {
        final picked = await _pickAccount(context, kind, others);
        if (picked == null || !context.mounted) return;
        if (picked != _signIn) {
          final account = others.firstWhere((s) => s.manifestUrl == picked);
          await service.setSourceProfiles(
              [picked], {...service.profilesWith(account), active});
          TrackerSync.instance.invalidate();
          unawaited(TrackerSync.instance.syncCatalog(storage, playlist));
          messenger.showSnackBar(SnackBar(
              content: Text(tr('{name} connected.', {'name': kind.label}))));
          return;
        }
      }
    }
    final login = await showDialog<TrackerLogin>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrackerSignInDialog(kind: kind),
    );
    if (login == null) return;
    Set<String>? profileIds;
    if (several && viewers != null && active != null) {
      final same = service.sameTrackerUser(login);
      final start = onlyHere
          ? {active}
          : same != null
              ? {...service.profilesWith(same), active}
              : service.trackerAccounts(kind).isEmpty
                  ? SourceProfiles.usual(viewers)
                  : {active};
      // Cancelled: the sign-in still counts, with the usual choice.
      profileIds = onlyHere || !context.mounted
          ? start
          : await SourceProfiles.pick(context, start) ?? start;
    }
    await service.addTracker(login, profileIds: profileIds);
    // Bring this account's history in now, not at the next launch.
    TrackerSync.instance.invalidate();
    unawaited(TrackerSync.instance.syncCatalog(storage, playlist));
    messenger.showSnackBar(
        SnackBar(content: Text(tr('{name} connected.', {'name': kind.label}))));
  }

  static const _signIn = 'sign-in';

  /// Another profile's account(s) of [kind], or a new sign-in: the chosen
  /// account's address, [_signIn], or null (Back).
  Future<String?> _pickAccount(
      BuildContext context, TrackerKind kind, List<ArchiveSource> others) {
    final viewers = context.read<ViewerProfileService>();
    final service = context.read<ArchiveService>();
    return showGlassMenu<String>(
      context: context,
      builder: (ctx) => SwallowHeldActivate(
          child: GlassMenuDialog(
        title: Text(tr('Connect {name}', {'name': kind.label})),
        children: [
          for (final (i, account) in others.indexed)
            TvDialogOption(
              autofocus: i == 0,
              onPressed: () => Navigator.pop(ctx, account.manifestUrl),
              child: Text(tr('Use {name} ({profiles})', {
                'name': _user(account),
                'profiles': SourceProfiles.label(
                    viewers, service.profilesWith(account)),
              })),
            ),
          TvDialogOption(
            onPressed: () => Navigator.pop(ctx, _signIn),
            child: Text(tr('Sign in with another account')),
          ),
        ],
      )),
    );
  }

  /// Several profiles: which profiles use [account], another account for
  /// this profile, or disconnect it.
  Future<void> _options(BuildContext context, ArchiveSource account) async {
    final service = context.read<ArchiveService>();
    final viewers = context.read<ViewerProfileService>();
    final kind = account.tracker!.kind;
    final ids = service.profilesWith(account);
    final choice = await showGlassMenu<String>(
      context: context,
      builder: (ctx) => SwallowHeldActivate(
          child: GlassMenuDialog(
        title: Text('${kind.label} · ${_user(account)}'),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, 'profiles'),
            child: Text(tr('Profiles: {profiles}',
                {'profiles': SourceProfiles.label(viewers, ids)})),
          ),
          TvDialogOption(
            onPressed: () => Navigator.pop(ctx, 'another'),
            child: Text(tr('Use another account on this profile')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.pop(ctx, 'disconnect'),
            child: Text(tr('Disconnect')),
          ),
        ],
      )),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'profiles':
        final picked = await SourceProfiles.pick(context, ids);
        if (picked == null) return;
        await service.setSourceProfiles([account.manifestUrl], picked);
        TrackerSync.instance.invalidate();
      case 'another':
        await _connect(context, kind, onlyHere: true);
      case 'disconnect':
        await _disconnect(context, account);
    }
  }

  Future<void> _disconnect(BuildContext context, ArchiveSource account) async {
    final service = context.read<ArchiveService>();
    final viewers = context.read<ViewerProfileService?>();
    final ids = service.profilesWith(account);
    final shared = viewers != null &&
        SourceProfiles.shown(viewers) &&
        ids.any((id) => id != viewers.active.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Disconnect {name}?', {'name': account.name})),
        content: Text([
          tr('Its rows leave the Media Hub and plays are no longer reported. Your account itself is untouched.'),
          if (shared)
            tr('Every profile that uses it is disconnected: {profiles}.',
                {'profiles': SourceProfiles.label(viewers, ids)}),
        ].join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Disconnect')),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.removeSource(account);
      TrackerSync.instance.invalidate();
    }
  }
}

/// "Go to … and enter CODE" with a QR code of the page, polling until the
/// viewer approves on their phone. Pops the login, or null (cancel/expired).
class TrackerSignInDialog extends StatefulWidget {
  const TrackerSignInDialog({super.key, required this.kind, this.api});
  final TrackerKind kind;

  /// Tests: answers instead of the services.
  @visibleForTesting
  final TrackerApi? api;

  @override
  State<TrackerSignInDialog> createState() => _TrackerSignInDialogState();
}

class _TrackerSignInDialogState extends State<TrackerSignInDialog> {
  late final _api = widget.api ?? TrackerApi();
  TrackerDeviceCode? _code;
  String? _error;
  Timer? _timer;
  DateTime? _deadline;
  bool _polling = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _code = null;
    });
    try {
      final code = await _api.startSignIn(widget.kind);
      if (!mounted) return;
      setState(() {
        _code = code;
        _deadline = DateTime.now().add(code.expiresIn);
      });
      _timer = Timer.periodic(code.interval, (_) => _poll());
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr(
            "Couldn't reach {name}. Check the connection.",
            {'name': widget.kind.label}));
      }
    }
  }

  Future<void> _poll() async {
    final code = _code;
    if (code == null || _polling) return;
    if (DateTime.now().isAfter(_deadline!)) {
      _timer?.cancel();
      setState(() => _error = tr('The code expired. Try again.'));
      return;
    }
    _polling = true;
    try {
      final login = await _api.pollSignIn(code);
      if (login != null && mounted) {
        _timer?.cancel();
        Navigator.of(context).pop(login);
      }
    } on TrackerAuthException {
      _timer?.cancel();
      if (mounted) {
        setState(() => _error = tr('Sign-in was not completed. Try again.'));
      }
    } catch (_) {
      // Network hiccup: the next tick tries again.
    } finally {
      _polling = false;
    }
  }

  /// The page to open: with the code filled in when the service has one.
  Future<void> _open(TrackerDeviceCode code) =>
      launchUrl(Uri.parse(code.qrUrl ?? code.verificationUrl),
          mode: LaunchMode.externalApplication);

  Future<void> _copy(TrackerDeviceCode code) async {
    await Clipboard.setData(ClipboardData(text: code.userCode));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final scheme = Theme.of(context).colorScheme;
    // Discord (cillfog, 2026-11-26): on a phone the steps beside the QR
    // code got ~60 px, so the code ran down one letter per line past the
    // window. Narrow screens stack them; phones and computers also get
    // Open / Copy code (a phone can't scan its own screen).
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final tv = context.read<AppPreferences?>()?.isTelevision ?? false;
    final align = narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = narrow ? TextAlign.center : TextAlign.start;
    Widget qr(TrackerDeviceCode code) => Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: QrImageView(
              data: code.qrUrl ?? code.verificationUrl,
              size: narrow ? 130 : 150),
        );
    Widget steps(TrackerDeviceCode code) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            Text(tr('On your phone or computer, open'), textAlign: textAlign),
            const SizedBox(height: 4),
            SelectableText(code.verificationUrl,
                textAlign: textAlign,
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(tr('and enter this code:'), textAlign: textAlign),
            const SizedBox(height: 4),
            // One line, smaller when it doesn't fit.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(code.userCode,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4)),
            ),
            if (!tv) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () => _open(code),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(tr('Open in browser')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copy(code),
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(_copied ? tr('Copied') : tr('Copy code')),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(tr('Waiting for you to approve…'),
                textAlign: textAlign,
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        );
    return AlertDialog(
      title: Text(tr('Connect {name}', {'name': widget.kind.label})),
      // Scrolls inside the fixed width: AlertDialog's own scrolling asks
      // the QR code's intrinsic height, which its LayoutBuilder can't give.
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
            child: _error != null
                ? Text(_error!)
                : code == null
                    ? const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()))
                    : narrow
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              steps(code),
                              const SizedBox(height: 16),
                              qr(code),
                            ],
                          )
                        : Row(
                            children: [
                              qr(code),
                              const SizedBox(width: 20),
                              Expanded(child: steps(code)),
                            ],
                          )),
      ),
      actions: [
        if (_error != null)
          TextButton(onPressed: _start, child: Text(tr('Try again'))),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
      ],
    );
  }
}
