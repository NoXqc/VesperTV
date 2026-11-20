import 'package:flutter/material.dart';

/// One slot of a [PhonePillBar].
class PhonePillItem {
  const PhonePillItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Portrait phone: the floating tab bar under the pages (streaming-app
/// style). The TV home's tabs (Home, TV, Movies...) and the Media Hub's
/// (Movies, TV Shows, Sources...) share it, so both look the same.
class PhonePillBar extends StatelessWidget {
  const PhonePillBar({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(0, 6, 0, 8),
  });

  final List<PhonePillItem> items;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget slot(PhonePillItem item) {
      final selected = item.selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: item.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.all(5),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: selected ? Colors.white24 : Colors.transparent),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon,
                      size: 24,
                      color: selected ? scheme.primary : Colors.white70),
                  const SizedBox(height: 3),
                  // Shrinks a long label to fit its slot ("Sports Trak" was
                  // cut to "Sports T…" on a narrow phone) instead of an
                  // ellipsis.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ]),
            color: Colors.black,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 12),
            ],
          ),
          child: Row(children: [for (final item in items) slot(item)]),
        ),
      ),
    );
  }
}
