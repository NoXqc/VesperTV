import 'package:flutter/material.dart';

import '../models/hub_collection.dart';
import '../utils/desktop_platform.dart';
import '../utils/image_urls.dart';
import 'hd_network_image.dart';
import 'hold_to_activate.dart';
import 'poster_card.dart';

/// One tile of a Media Hub collection row (owner, 2026-11-11, Nuvio's
/// collections): the folder's still cover, its animated picture while
/// focused (an animated WebP: "they look like GIFs"), the name under it.
/// Same height as a [PosterCard] so tile rows and poster rows share one
/// row extent; a landscape tile is as wide as a focused wide card.
class CollectionTile extends StatefulWidget {
  const CollectionTile({
    super.key,
    required this.folder,
    required this.focusNode,
    required this.onTap,
    this.onHold,
    this.onFocusGained,
    this.animate = false,
  });

  final HubFolder folder;
  final FocusNode focusNode;
  final VoidCallback onTap;

  /// Hold OK (or a long press): the collection's menu.
  final VoidCallback? onHold;
  final VoidCallback? onFocusGained;

  /// Play the animated picture without focus: a phone has no focus, and
  /// Nuvio's phone app plays every tile on screen.
  final bool animate;

  static double widthOf(HubTileShape shape) => switch (shape) {
        HubTileShape.landscape => PosterCard.wideCardWidth,
        HubTileShape.poster => PosterCard.width,
        HubTileShape.square => PosterCard.posterHeight,
      };

  /// A tile's slot in a row: the tile, its own 6 px padding each side and
  /// the row's 4 px each side (the same sum as a poster's slot).
  static double slotOf(HubTileShape shape) => widthOf(shape) + 12 + 8;

  @override
  State<CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends State<CollectionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folder = widget.folder;
    final width = CollectionTile.widthOf(folder.shape);
    final decode = HdNetworkImage.cardDecodeWidth(context, width);
    final moving = folder.focusUrl != null && (_focused || widget.animate);
    final fallback = _TileFallback(folder: folder);
    // OK / Enter opens on every platform (a computer's click only focuses,
    // see onTap below); PosterCard does the same.
    return HoldToActivate(
      onTap: widget.onTap,
      onHold: widget.onHold,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          focusNode: widget.focusNode,
          borderRadius: BorderRadius.circular(10),
          focusColor: Colors.transparent,
          // A computer's first click shows the tile in the hero, the second
          // opens it (same as PosterCard).
          onTap: isDesktop ? widget.focusNode.requestFocus : widget.onTap,
          onDoubleTap: isDesktop ? widget.onTap : null,
          onLongPress: widget.onHold,
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (f) widget.onFocusGained?.call();
          },
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: SizedBox(
              width: width,
              height: PosterCard.height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: width,
                    height: PosterCard.posterHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(10),
                      border: _focused
                          ? Border.all(color: scheme.primary, width: 3)
                          : null,
                      boxShadow: _focused
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.45),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (folder.coverUrl case final cover?)
                          HdNetworkImage(
                            url: cover,
                            kind: ImageKind.backdrop,
                            fit: BoxFit.cover,
                            decodeWidth: decode,
                            errorWidget: (_) => fallback,
                          )
                        else
                          fallback,
                        // Only the moving tile decodes its frames.
                        if (moving)
                          HdNetworkImage(
                            key: ValueKey(folder.focusUrl),
                            url: folder.focusUrl!,
                            kind: ImageKind.backdrop,
                            fit: BoxFit.cover,
                            decodeWidth: decode,
                            fadeInDuration: const Duration(milliseconds: 200),
                            errorWidget: (_) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                  if (!folder.hideTitle)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        folder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _focused ? FontWeight.w600 : null,
                          color: _focused ? scheme.primary : Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No picture (or it failed): the folder's emoji and name.
class _TileFallback extends StatelessWidget {
  const _TileFallback({required this.folder});

  final HubFolder folder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            [if (folder.emoji != null) folder.emoji!, folder.title].join('\n'),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
