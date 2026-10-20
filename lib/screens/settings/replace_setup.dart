import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/catalog_database.dart';
import '../../services/epg_service.dart';
import '../../services/storage_service.dart';
import '../../l10n/l10n.dart';

/// Replaces this device's setup ([importer] writes the new one) and closes
/// the app — shared by Transfer (receive) and Backup & restore. Old caches
/// go first (clearCache also drops watch positions, which the import then
/// brings back). Every service still holds the old setup in memory, so a
/// fresh start is the only clean way to load the new one.
Future<void> replaceSetupAndExit(
  BuildContext context, {
  required String title,
  required Future<void> Function(StorageService storage) importer,
}) async {
  final storage = context.read<StorageService>();
  final catalogDb = context.read<CatalogDatabase>();
  final epg = context.read<EpgService>();
  await storage.clearCache();
  await epg.clearAll();
  await catalogDb.clearAll();
  await importer(storage);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
          tr('VesperTV will close now. Open it again to load your playlists.')),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('OK')),
        ),
      ],
    ),
  );
  exit(0);
}
