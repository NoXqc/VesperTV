import 'package:flutter/foundation.dart';
import '../../services/profile_photos.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../models/viewer_profile.dart';
import '../../models/profile_copy.dart';
import '../../services/viewer_profile_service.dart';
import '../../services/storage_service.dart';
import '../../services/playlist_manager.dart';
import '../../services/parental_pin.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/profile_card.dart';
import '../../widgets/profile_photo_actions.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_text_field_gate.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/hold_to_activate.dart';
import 'group_management_screen.dart';
import 'hidden_channels_screen.dart';

Future<void> openProfileEditor(BuildContext context, String id) async {
  if (!await context.read<ViewerProfileService>().requireUnlock(context) ||
      !context.mounted) {
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SwallowHeldActivate(child: ProfileDetailScreen(profileId: id))));
}

class ProfileColourRow extends StatefulWidget {
  const ProfileColourRow(
      {super.key,
      required this.selected,
      required this.onChanged,
      this.firstNode});
  final int selected;
  final ValueChanged<int> onChanged;
  final FocusNode? firstNode;
  @override
  State<ProfileColourRow> createState() => _ProfileColourRowState();
}

class _ProfileColourRowState extends State<ProfileColourRow> {
  int? _focused;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < kProfileColors.length; i++)
          Semantics(
              label: '${tr('Colour')} ${i + 1}',
              selected: i == widget.selected,
              child: InkWell(
                  focusNode: i == 0 ? widget.firstNode : null,
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onChanged(i),
                  onFocusChange: (f) => setState(() => _focused = f ? i : null),
                  child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kProfileColors[i],
                          border: Border.all(
                              width: 3,
                              color: _focused == i
                                  ? Colors.white
                                  : i == widget.selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent)),
                      child: i == widget.selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null)))
      ]);
}

Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(tr(text),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));

/// [controller]: lets the first field scroll the page back to the very top
/// (focus only scrolled far enough to show the field, cutting the preview).
Widget _layout(Widget preview, Widget form, {ScrollController? controller}) =>
    LayoutBuilder(
        builder: (context, limits) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            child: limits.maxWidth >= 800
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 240, child: preview),
                    const SizedBox(width: 32),
                    Expanded(child: form)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [preview, const SizedBox(height: 20), form])));

class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({super.key});
  @override
  State<AddProfileScreen> createState() => _AddProfileScreenState();
}

class _AddProfileScreenState extends State<AddProfileScreen> {
  final _name = TextEditingController(),
      _nameNode = FocusNode(),
      _colourNode = FocusNode(),
      _skipNode = FocusNode();
  final _scroll = ScrollController();
  final _options = <ProfileCopy>{};
  int _colour = 0;
  bool _restricted = false, _saving = false;
  Uint8List? _photo;
  @override
  void initState() {
    super.initState();
    _nameNode.addListener(() {
      if (_nameNode.hasFocus && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameNode.dispose();
    _colourNode.dispose();
    _skipNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    // Create stays enabled (a disabled button can't take remote focus, so
    // the page looked like it had no end): no name = say so, go to Name.
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Enter a name first'))));
      _nameNode.requestFocus();
      return;
    }
    setState(() => _saving = true);
    try {
      if (_restricted && !context.read<ParentalPin>().isSet) {
        if (!await setupPinFlow(context) || !mounted) return;
      }
      if (!mounted) return;
      final profile = await context.read<ViewerProfileService>().createProfile(
          name: _name.text.trim(),
          colorIndex: _colour,
          isRestricted: _restricted,
          copyFromMain: _options,
          photo: _photo);
      if (mounted) Navigator.pop(context, profile.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Could not save profile. Try again.'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ViewerProfile(
        id: 'preview',
        name: _name.text,
        colorIndex: _colour,
        isRestricted: _restricted,
        createdAt: DateTime(2026));
    final labels = {
      ProfileCopy.favourites: 'Favorites',
      ProfileCopy.history: 'Watch history',
      ProfileCopy.sports: 'Sports Trak',
      ProfileCopy.visibility: 'Hidden groups and channels',
      ProfileCopy.home: 'Home rows layout'
    };
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
            title: tr('Add Profile'),
            body: _layout(
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ProfilePortrait(
                      profile: preview,
                      width: 156,
                      height: 204,
                      preview: _photo),
                  const SizedBox(height: 12),
                  Text(_name.text, maxLines: 2),
                  if (_restricted) Chip(label: Text(tr('Kids profile'))),
                ]),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Name'),
                      TvTextFieldGate(
                          focusNode: _nameNode,
                          builder: (context, readOnly) => TextField(
                              focusNode: _nameNode,
                              controller: _name,
                              autofocus: true,
                              readOnly: readOnly,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _colourNode.requestFocus(),
                              decoration: InputDecoration(
                                  labelText: tr('Name'),
                                  border: const OutlineInputBorder()))),
                      _heading('Colour'),
                      ProfileColourRow(
                          selected: _colour,
                          firstNode: _colourNode,
                          onChanged: (i) => setState(() => _colour = i)),
                      TvSwitchListTile(
                          title: Text(tr('Kids profile')),
                          value: _restricted,
                          onChanged: (v) async {
                            if (v &&
                                !context.read<ParentalPin>().isSet &&
                                !await setupPinFlow(context)) {
                              return;
                            }
                            if (mounted) {
                              setState(() {
                                _restricted = v;
                                if (v) _options.remove(ProfileCopy.visibility);
                              });
                            }
                          }),
                      _heading('Photo'),
                      ProfilePhotoActions(
                          hasPhoto: _photo != null,
                          skipNode: _skipNode,
                          onPhoto: (bytes) async {
                            final normalized =
                                await compute(ProfilePhotos.normalize, bytes);
                            if (mounted) setState(() => _photo = normalized);
                          },
                          onRemove: () => setState(() => _photo = null)),
                      _heading('What should this profile get from Main?'),
                      Text(tr(
                          'Copies are independent. Playlists, accounts and device settings stay shared.')),
                      Wrap(spacing: 12, children: [
                        TextButton(
                            onPressed: () => setState(() => _options.addAll(
                                ProfileCopy.values.where((o) =>
                                    !_restricted ||
                                    o != ProfileCopy.visibility))),
                            child: Text(tr('Everything'))),
                        TextButton(
                            onPressed: () => setState(_options.clear),
                            child: Text(tr('None')))
                      ]),
                      for (final option in ProfileCopy.values)
                        if (!_restricted || option != ProfileCopy.visibility)
                          CheckboxListTile(
                              title: Text(tr(labels[option]!)),
                              value: _options.contains(option),
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() {
                                        if (v == true) {
                                          _options.add(option);
                                        } else {
                                          _options.remove(option);
                                        }
                                      })),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(tr(_saving ? 'Saving…' : 'Create'),
                                  style: const TextStyle(fontSize: 18)))),
                    ]),
                controller: _scroll)));
  }
}

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key, required this.profileId});
  final String profileId;
  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _name = TextEditingController(),
      _nameNode = FocusNode(),
      _colourNode = FocusNode();
  final _scroll = ScrollController();
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _nameNode.addListener(() {
      if (_nameNode.hasFocus && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameNode.dispose();
    _colourNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _delete(ViewerProfile profile) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title:
                    Text(tr('Delete "{name}"?', {'name': profile.displayName})),
                content: Text(tr(
                    'Their favorites, hidden groups, and watch history are deleted too. This can\'t be undone.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(tr('Delete')))
                ]));
    if (yes != true || !mounted) return;
    if (await context.read<ViewerProfileService>().deleteProfile(profile.id) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _playlist(ViewerProfile profile, String id, String name) async {
    final viewers = context.read<ViewerProfileService>();
    if (!await viewers.switchTo(context, profile.id) || !mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SettingsScaffold(
                title: name,
                body: SingleChildScrollView(
                    child: Column(children: [
                  TvMenuTile(
                      autofocus: true,
                      title: tr('Groups'),
                      icon: Icons.folder_outlined,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GroupManagementScreen(playlistId: id)))),
                  TvMenuTile(
                      title: tr('Hidden channels'),
                      icon: Icons.visibility_off,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  HiddenChannelsScreen(playlistId: id)))),
                ])))));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final viewers = context.watch<ViewerProfileService>(),
        storage = context.read<StorageService>();
    final profile = viewers.profiles.firstWhere((p) => p.id == widget.profileId,
        orElse: ViewerProfile.main);
    final active = profile.id == viewers.active.id;
    if (!_initialized) {
      _name.text = profile.name;
      _initialized = true;
    }
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
            title: profile.displayName,
            body: _layout(
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ProfilePortrait(profile: profile, width: 156, height: 204),
                  const SizedBox(height: 12),
                  Text(profile.displayName,
                      style: const TextStyle(fontSize: 22)),
                  if (profile.isRestricted)
                    Chip(label: Text(tr('Kids profile'))),
                  if (active) Chip(label: Text(tr('Active'))),
                ]),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Profile'),
                      TvTextFieldGate(
                          focusNode: _nameNode,
                          builder: (ctx, readOnly) => TextField(
                              controller: _name,
                              focusNode: _nameNode,
                              autofocus: true,
                              readOnly: readOnly,
                              onSubmitted: (_) => _colourNode.requestFocus(),
                              decoration:
                                  InputDecoration(labelText: tr('Name')))),
                      TextButton(
                          onPressed: () async {
                            if (_name.text.trim().isNotEmpty) {
                              await viewers.renameProfile(
                                  profile.id, _name.text.trim());
                            }
                          },
                          child: Text(tr('Save name'))),
                      _heading('Photo'),
                      ProfilePhotoActions(
                          hasPhoto: profile.photoVersion > 0,
                          onPhoto: (bytes) =>
                              viewers.setPhoto(profile.id, bytes),
                          onRemove: () => viewers.removePhoto(profile.id)),
                      _heading('Colour'),
                      ProfileColourRow(
                          selected: profile.colorIndex,
                          firstNode: _colourNode,
                          onChanged: (i) => viewers.setColour(profile.id, i)),
                      if (profile.isRestricted) ...[
                        _heading('Kids & PIN'),
                        Text(tr(
                            'Profile restrictions are fixed when the profile is created.')),
                        TvMenuTile(
                            title: tr('Change PIN'),
                            icon: Icons.lock,
                            onTap: () => setupPinFlow(context))
                      ],
                      _heading('What this profile can see'),
                      for (final playlist
                          in context.watch<PlaylistManager>().profiles)
                        TvMenuTile(
                            title: playlist.name,
                            icon: Icons.folder_outlined,
                            subtitle: profile.isRestricted
                                ? tr('{n} groups allowed', {
                                    'n': storage.viewerGroupCount(
                                        playlist.id, profile.id,
                                        allowed: true)
                                  })
                                : tr(
                                    '{groups} groups hidden · {channels} channels hidden',
                                    {
                                        'groups': storage.viewerGroupCount(
                                            playlist.id, profile.id),
                                        'channels':
                                            storage.viewerHiddenChannelCount(
                                                playlist.id, profile.id)
                                      }),
                            onTap: () =>
                                _playlist(profile, playlist.id, playlist.name)),
                      _heading('Actions'),
                      TvMenuTile(
                          title: tr(active
                              ? 'This is the active profile'
                              : 'Switch to this profile'),
                          enabled: !active,
                          icon: Icons.swap_horiz,
                          onTap: () => viewers.switchTo(context, profile.id)),
                      Theme(
                          data: Theme.of(context).copyWith(
                              listTileTheme: const ListTileThemeData(
                                  textColor: Colors.redAccent,
                                  iconColor: Colors.redAccent)),
                          child: TvMenuTile(
                              title: tr('Delete profile'),
                              icon: Icons.delete_outline,
                              enabled: !profile.isMain && !active,
                              subtitle: profile.isMain
                                  ? tr('Main cannot be deleted')
                                  : active
                                      ? tr(
                                          'Switch to another profile before deleting this one')
                                      : null,
                              onTap: () => _delete(profile))),
                    ]),
                controller: _scroll)));
  }
}
