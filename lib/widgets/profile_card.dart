import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/viewer_profile.dart';
import '../services/viewer_profile_service.dart';
import 'hold_to_activate.dart';

class ProfilePortrait extends StatelessWidget {
  const ProfilePortrait(
      {super.key,
      required this.profile,
      this.width = 104,
      this.height = 136,
      this.preview});
  final ViewerProfile profile;
  final double width, height;
  final Uint8List? preview;
  @override
  Widget build(BuildContext context) {
    final colour = kProfileColors[profile.colorIndex % kProfileColors.length];
    final fallback = Center(
        child: Text(
            profile.name.isEmpty
                ? '?'
                : profile.name.characters.first.toUpperCase(),
            style: TextStyle(
                fontSize: width * .46,
                fontWeight: FontWeight.bold,
                color: Colors.white)));
    Widget face = fallback;
    if (preview != null) {
      face = Image.memory(preview!,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (_, e, s) => fallback);
    } else if (profile.photoVersion > 0) {
      final service = context.read<ViewerProfileService?>();
      if (service != null) {
        face = FutureBuilder<File>(
            key: ValueKey('${profile.id}:${profile.photoVersion}'),
            future: service.photoFile(profile.id),
            builder: (_, snapshot) => snapshot.hasData
                ? Image.file(snapshot.data!,
                    fit: BoxFit.cover,
                    width: width,
                    height: height,
                    errorBuilder: (_, e, s) => fallback)
                : fallback);
      }
    }
    return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                      colour,
                      Color.lerp(colour, Colors.black, .6)!
                    ])),
                child: Stack(fit: StackFit.expand, children: [
                  face,
                  if (profile.isRestricted)
                    const Positioned(
                        right: 7,
                        top: 7,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.lock,
                                    size: 16, color: Colors.white)))),
                ]))));
  }
}

class ProfileCard extends StatefulWidget {
  const ProfileCard(
      {super.key,
      this.profile,
      required this.label,
      required this.focusNode,
      required this.onTap,
      this.onHold,
      this.onFocused,
      this.active = false,
      this.scale = 1,
      this.compact = false});
  final ViewerProfile? profile;
  final String label;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onHold, onFocused;
  final bool active;
  final double scale;

  /// Home while the rows have focus: a small avatar, no name, so the hero
  /// and rows get the room; full card again when focus comes back up.
  final bool compact;
  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final s = widget.compact ? 0.3 : widget.scale;
    return HoldToActivate(
        onTap: widget.onTap,
        onHold: widget.onHold,
        child: InkWell(
            focusNode: widget.focusNode,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            onFocusChange: (f) {
              setState(() => _focused = f);
              if (f) widget.onFocused?.call();
            },
            child: SizedBox(
                width: widget.compact ? 44 : 124 * s,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedScale(
                      scale: _focused ? 1.1 : 1,
                      curve: Curves.easeOutBack,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                  width: 2.5,
                                  color: _focused
                                      ? Colors.white
                                      : widget.active
                                          ? primary
                                          : Colors.transparent)),
                          child: widget.profile != null
                              ? ProfilePortrait(
                                  profile: widget.profile!,
                                  width: 104 * s,
                                  height: 136 * s)
                              : Container(
                                  width: 104 * s,
                                  height: 136 * s,
                                  decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.add, size: 40)))),
                  if (!widget.compact) const SizedBox(height: 7),
                  if (!widget.compact)
                    Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: widget.active ? primary : Colors.white,
                            fontSize: 13 * s)),
                ]))));
  }
}
