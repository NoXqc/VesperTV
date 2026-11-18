part of 'vesper_tools.dart';

// Settings > Recordings > Network folder from an AI app (owner,
// 2026-11-18: his share got disconnected and the connector couldn't set it
// again). Same steps as the page: the folder is tested first (connect,
// write and remove a small file), then saved. The password is never sent
// back; it stays on this device like the page's (never Transfer / Backup /
// cloud sync).

final _networkFolderTool = VesperTool(
  name: 'network_folder',
  description: "The TV's network folder (a Windows / NAS shared folder over "
      'SMB) for recordings and downloads. action get: the folder saved now '
      '(never its password). action set: address '
      r'("\\192.168.1.20\Media" or "smb://192.168.1.20/Media"), folder '
      'inside it (default VesperTV), '
      'user, password; the TV tests it first and saves only when it works. '
      'use false = only browse it (the TV keeps saving to itself). action '
      'clear: forget it. set and clear need one OK on the TV. Android only.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['get', 'set', 'clear'],
      },
      'address': {
        'type': 'string',
        'description': r'For set: \\computer\share (a folder may follow).',
      },
      'folder': {
        'type': 'string',
        'description': 'For set: the folder inside the share (VesperTV '
            'when left out and the address names none).',
      },
      'user': {'type': 'string', 'description': 'For set.'},
      'password': {'type': 'string', 'description': 'For set.'},
      'domain': {
        'type': 'string',
        'description': 'For set, rarely needed (a company domain).',
      },
      'use': {
        'type': 'boolean',
        'description': 'For set: recordings and downloads go there '
            '(default true).',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    if (!RecordingService.supported) {
      throw VesperToolError('The network folder is on Android TVs only.');
    }
    final service = RecordingService.instance;
    final s = service.settings;
    final saved = s.network;
    final inUse = saved != null && s.folder == saved.base;
    switch ('${args['action'] ?? ''}') {
      case 'get':
        if (saved == null) return {'network_folder': null};
        return {
          'network_folder': {
            'address': saved.display,
            'user': saved.user,
            if (saved.domain.isNotEmpty) 'domain': saved.domain,
            'has_password': saved.password.isNotEmpty,
            'in_use': inUse,
          },
        };
      case 'set':
        final a = NetworkFolderConfig.parseAddress('${args['address'] ?? ''}');
        if (a == null || a.share.isEmpty) {
          throw VesperToolError(r'Give the address as \\computer\share, for '
              r'example \\192.168.1.20\Media.');
        }
        final extra = '${args['folder'] ?? ''}'.trim().replaceAll('\\', '/');
        var inside = [
          if (a.folder.isNotEmpty) a.folder,
          if (extra.isNotEmpty) extra,
        ].join('/').replaceAll(RegExp(r'^/+|/+$'), '');
        if (inside.isEmpty && args['folder'] == null) inside = 'VesperTV';
        final config = NetworkFolderConfig(
          host: a.host,
          share: a.share,
          folder: inside,
          user: '${args['user'] ?? ''}'.trim(),
          password: '${args['password'] ?? ''}',
          domain: '${args['domain'] ?? ''}'.trim(),
        );
        final use = args['use'] != false;
        await _confirmRemote(
            box,
            caller,
            'An AI app wants to save the network folder {folder}.',
            {'folder': config.display});
        final test = await service.testNetworkFolder(config);
        if (test.error != null) {
          return {
            'error': "Couldn't use this folder: ${test.error}. Nothing was "
                'saved.',
          };
        }
        final now = service.settings;
        final wasUsed = now.network != null && now.folder == now.network!.base;
        await service.updateSettings(use
            ? now.copyWith(network: config, folder: config.base)
            : now.copyWith(network: config, clearFolder: wasUsed));
        return {
          'saved': config.display,
          'in_use': use,
          if (test.free != null)
            'free_gb': (test.free! / (1024 * 1024 * 1024)).toStringAsFixed(1),
          'note': use
              ? 'Recordings and downloads now go to the network folder.'
              : 'Saved for browsing; this TV keeps saving to itself.',
        };
      case 'clear':
        if (saved == null) return {'note': 'No network folder was saved.'};
        await _confirmRemote(
            box,
            caller,
            'An AI app wants to forget the network folder {folder}.',
            {'folder': saved.display});
        await service
            .updateSettings(s.copyWith(clearNetwork: true, clearFolder: inUse));
        return {'cleared': saved.display};
      default:
        throw VesperToolError('action must be get, set or clear.');
    }
  },
);
