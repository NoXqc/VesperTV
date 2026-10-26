import 'package:flutter/material.dart';

/// Shared gold outline used by channel quality and playlist labels.
class GoldTag extends StatelessWidget {
  const GoldTag(
      {super.key, required this.label, this.compact = false, this.margin});

  final String label;
  final bool compact;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5, vertical: compact ? 0 : 1),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.amber,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.bold,
                height: 1.1)),
      );
}
