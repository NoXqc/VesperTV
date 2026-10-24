import 'package:flutter/widgets.dart';

/// An attached ScrollPosition can still have no metrics during a widget
/// update. jumpTo then starts a ballistic simulation with null extents.
/// Return false so a caller can retry after layout when a reset is needed.
bool jumpToIfLaidOut(ScrollController controller, double offset) {
  if (!controller.hasClients ||
      controller.positions
          .any((p) => !p.hasContentDimensions || !p.hasPixels)) {
    return false;
  }
  controller.jumpTo(offset);
  return true;
}
