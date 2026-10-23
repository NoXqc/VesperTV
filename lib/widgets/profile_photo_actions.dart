import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../l10n/l10n.dart';
import '../services/phone_pairing_service.dart';
import '../services/profile_photos.dart';
import '../services/device_memory_service.dart';
import 'phone_pair_panel.dart';
import 'tv_text_field_gate.dart';

class ProfilePhotoActions extends StatefulWidget {
  const ProfilePhotoActions(
      {super.key,
      required this.onPhoto,
      required this.onRemove,
      this.hasPhoto = false,
      this.skipNode});
  final Future<void> Function(Uint8List) onPhoto;
  final VoidCallback onRemove;
  final bool hasPhoto;
  final FocusNode? skipNode;
  @override
  State<ProfilePhotoActions> createState() => _ProfilePhotoActionsState();
}

class _ProfilePhotoActionsState extends State<ProfilePhotoActions> {
  bool _tv = true, _busy = false;
  @override
  void initState() {
    super.initState();
    DeviceTypeService.isTelevision().then((tv) {
      if (mounted) setState(() => _tv = tv);
    });
  }

  Future<void> _accept(Uint8List bytes) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPhoto(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                tr('Could not read photo. Choose a JPEG or PNG under 2 MB.'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'JPEG / PNG',
            extensions: ['jpg', 'jpeg', 'png'],
            mimeTypes: ['image/jpeg', 'image/png'],
            uniformTypeIdentifiers: ['public.jpeg', 'public.png'])
      ]);
      if (file == null) return;
      if (await file.length() > ProfilePhotos.maxBytes) {
        throw const FormatException('Too large');
      }
      await _accept(await file.readAsBytes());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                tr('Could not read photo. Choose a JPEG or PNG under 2 MB.'))));
      }
    }
  }

  Future<void> _qr() async {
    final photo = await showDialog<Uint8List>(
        context: context,
        builder: (ctx) => FocusNodeOwner(
            builder: (ctx, node) => Dialog(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: PhonePairPanel(
                            kind: PairingKind.photo,
                            toggleFocusNode: node,
                            onResult: (r) => Navigator.pop(ctx, r.photo)))))));
    if (photo != null && mounted) await _accept(photo);
  }

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 12, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: _busy ? null : _qr,
            icon: const Icon(Icons.qr_code),
            label: Text(tr('Scan with your phone to add a photo'))),
        if (!_tv)
          OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.photo),
              label: Text(tr('Choose a photo'))),
        if (widget.hasPhoto)
          TextButton(
              onPressed: _busy ? null : widget.onRemove,
              child: Text(tr('Remove photo'))),
        if (widget.skipNode != null)
          TextButton(
              focusNode: widget.skipNode,
              onPressed: () => widget.skipNode!.nextFocus(),
              child: Text(tr('Skip'))),
        if (_busy)
          const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator()),
      ]);
}
