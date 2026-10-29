import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/archive_service.dart';
import '../../services/media_server_api.dart';
import '../../services/plex_api.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

class PlexConnectScreen extends StatefulWidget {
  const PlexConnectScreen({super.key});

  @override
  State<PlexConnectScreen> createState() => _PlexConnectScreenState();
}

class _PlexConnectScreenState extends State<PlexConnectScreen> {
  final _client = http.Client();
  late final _api = PlexApi(_client);
  Timer? _timer;
  PlexPin? _pin;
  List<PlexServer>? _servers;
  String? _error;
  String _deviceId = '';
  bool _busy = false;
  int _generation = 0;
  late final StorageService _storage;
  late final int _viewer;
  bool get _current => mounted && _storage.viewerGeneration == _viewer;

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _start();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    _timer?.cancel();
    setState(() {
      _error = null;
      _servers = null;
      _pin = null;
      _busy = true;
    });
    try {
      final saved = _storage.getArchiveOptionsJson('plex_client');
      if (saved != null) {
        try {
          final value = jsonDecode(saved);
          if (value is Map && value['id'] is String) _deviceId = value['id'];
        } catch (_) {}
      }
      if (_deviceId.isEmpty) {
        final random = Random.secure();
        _deviceId = List.generate(16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        await _storage.setArchiveOptionsJson(
            'plex_client', jsonEncode({'id': _deviceId}));
      }
      if (!_current || generation != _generation) return;
      final pin = await _api.createPin(_deviceId);
      if (!_current || generation != _generation) return;
      setState(() {
        _pin = pin;
        _busy = false;
      });
      _schedule(generation);
    } catch (_) {
      if (_current && generation == _generation) {
        setState(() {
          _busy = false;
          _error = tr('Could not connect to Plex. Try again.');
        });
      }
    }
  }

  void _schedule(int generation) {
    _timer = Timer(const Duration(seconds: 2), () => _poll(generation));
  }

  Future<void> _poll(int generation) async {
    if (!_current || generation != _generation) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _schedule(generation);
      return;
    }
    final pin = _pin!;
    if (DateTime.now().isAfter(pin.expiresAt)) {
      setState(() => _error = tr('Plex sign-in expired. Try again.'));
      return;
    }
    try {
      final token = await _api.pollPin(_deviceId, pin);
      if (!_current || generation != _generation) return;
      if (token == null) {
        _schedule(generation);
        return;
      }
      setState(() => _busy = true);
      final servers = await _api.servers(_deviceId, token);
      if (!_current || generation != _generation) return;
      setState(() {
        _servers = servers;
        _busy = false;
      });
    } catch (_) {
      if (_current && generation == _generation) {
        setState(() {
          _busy = false;
          _error = tr('Could not connect to Plex. Try again.');
        });
      }
    }
  }

  Future<void> _connect(PlexServer server) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final hub = context.read<ArchiveService>();
    try {
      await hub.addPlexServer(server, _deviceId);
      if (!mounted || !_current) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('{name} added.', {'name': server.name}))));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!_current) return;
      setState(() {
        _busy = false;
        _error = error is MediaServerNoLibraryException
            ? tr('This account has no movie or TV library.')
            : error is MediaServerLoginException
                ? tr('Plex access was denied. Sign in again.')
                : tr(
                    'Could not reach this Plex server. Check that it is online and accessible from this device.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
      title: tr('Connect Plex'),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(
                'Sign in with Plex on your phone, then choose a server. Your movie and TV libraries appear in the Media Hub. Files play directly, without transcoding.')),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 12),
              TvMenuTile(
                  autofocus: true,
                  icon: Icons.refresh,
                  title: tr('Try again'),
                  enabled: !_busy,
                  onTap: _start),
            ] else if (_servers case final servers?) ...[
              Text(tr('Choose a Plex server')),
              if (servers.isEmpty)
                Text(tr('No Plex servers are available on this account.')),
              for (var i = 0; i < servers.length; i++)
                TvMenuTile(
                    autofocus: i == 0,
                    icon: Icons.dns_outlined,
                    title: servers[i].name,
                    enabled: !_busy,
                    onTap: () => _connect(servers[i])),
              TvMenuTile(
                  autofocus: servers.isEmpty,
                  icon: Icons.account_circle,
                  title: tr('Sign in again'),
                  enabled: !_busy,
                  onTap: _start),
            ] else if (_pin case final pin?) ...[
              Text(tr('Scan the QR code or visit {url} and enter this code:',
                  {'url': 'plex.tv/link'})),
              const SizedBox(height: 12),
              SelectableText(pin.code,
                  style: const TextStyle(fontSize: 32, letterSpacing: 5)),
              const SizedBox(height: 12),
              QrImageView(
                  data: pin.verificationUrl.toString(),
                  size: 200,
                  backgroundColor: Colors.white),
              const SizedBox(height: 12),
              TvMenuTile(
                  autofocus: true,
                  icon: Icons.close,
                  title: tr('Cancel'),
                  onTap: () => Navigator.of(context).pop()),
            ],
          ])));
}
