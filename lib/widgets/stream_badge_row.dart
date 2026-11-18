import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/archive_playback_sources.dart';
import '../services/archive_service.dart';
import '../services/stream_badges.dart';
import 'gold_tag.dart';

/// One Media Hub source's badges: the saved pack's pictures
/// ([StreamBadges]), or VesperTV's own gold format tags
/// ([archiveStreamFormats]) without a pack, while it can't be read, or when
/// none of its badges match. One line of [height]; [wrap] lets extra
/// badges go to more lines, otherwise they are cut at the edge.
class StreamBadgeRow extends StatelessWidget {
  const StreamBadgeRow({
    super.key,
    required this.option,
    this.height = 20,
    this.wrap = true,
    this.compact = false,
  });

  final ArchiveStreamOption option;
  final double height;
  final bool wrap;

  /// Smaller gold tags (the source drawer's narrow rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badges = StreamBadges.instance;
    badges.ensureLoaded();
    return ListenableBuilder(
      listenable: Listenable.merge([badges.pack, badges.matched]),
      builder: (context, _) {
        final children = _children(badges);
        if (children == null) return SizedBox(height: height);
        if (children.isEmpty) return const SizedBox.shrink();
        final row = Wrap(
          spacing: 5,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          clipBehavior: wrap ? Clip.none : Clip.hardEdge,
          children: children,
        );
        return wrap ? row : SizedBox(height: height, child: row);
      },
    );
  }

  /// Null = the pack is still matching this source (keep the row's height).
  List<Widget>? _children(StreamBadges badges) {
    List<Widget> builtIn() => [
      for (final f in archiveStreamFormats(option))
        GoldTag(label: f, compact: compact),
    ];
    if (!badges.enabled) return builtIn();
    if (badges.pack.value == null) return null;
    final s = option.stream;
    final hits = badges.badgesFor(
      streamBadgeText(name: s.name, title: s.title, fileName: s.fileName),
    );
    if (hits == null) return null;
    if (hits.isEmpty) return builtIn();
    return [for (final b in hits) StreamBadgeChip(badge: b, height: height)];
  }
}

/// One pack badge as Nuvio draws it: a rounded pill in the badge's own
/// colours (tag fill, 1 px border) holding its picture, or its name as text.
/// A picture on a clear fill sits edge to edge (most packs draw the whole
/// badge in the picture).
class StreamBadgeChip extends StatelessWidget {
  const StreamBadgeChip({super.key, required this.badge, this.height = 20});

  final StreamBadge badge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fill = badge.tagColor;
    final border = badge.borderColor;
    final radius = BorderRadius.circular(height * 0.24);
    final decode = (height * MediaQuery.devicePixelRatioOf(context)).round();
    final text = Text(
      badge.name,
      maxLines: 1,
      style: TextStyle(
        color: Color(badge.textColor ?? 0xFFFFFFFF),
        fontSize: height * 0.55,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
    Widget textTag() => Padding(
      padding: EdgeInsets.symmetric(horizontal: height * 0.35),
      child: Center(widthFactor: 1, child: text),
    );
    final bytes = badge.imageBytes;
    final network = badge.networkImage;
    final Widget face;
    if (bytes != null) {
      face = Image.memory(
        bytes,
        height: height,
        cacheHeight: decode,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => textTag(),
      );
    } else if (network != null) {
      face = CachedNetworkImage(
        imageUrl: network,
        height: height,
        memCacheHeight: decode,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => SizedBox(width: height * 1.6),
        errorWidget: (_, __, ___) => textTag(),
      );
    } else {
      face = textTag();
    }
    final picture = bytes != null || network != null;
    return Container(
      height: height,
      padding: picture && fill != null
          ? EdgeInsets.symmetric(
              horizontal: height * 0.18,
              vertical: height * 0.1,
            )
          : null,
      decoration: BoxDecoration(
        color: fill == null ? null : Color(fill),
        borderRadius: radius,
        border: border == null ? null : Border.all(color: Color(border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: face,
    );
  }
}
