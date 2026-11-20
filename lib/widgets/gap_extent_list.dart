import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A fixed-extent list (like `ListView.builder(itemExtent:)`) where one
/// row, [gapAfter], is [gapExtent] taller: the space under it opens and
/// the rows after it move down. The Timeline guide opens a programme's
/// details there.
///
/// Not `itemExtentBuilder`: Flutter's varied-extent list adds up every
/// row above to place each child, on each layout (a 10k-channel group
/// scrolled to its end = ~150k calls per D-pad step, twice: grid and
/// channel names). Here every offset is one multiplication.
///
/// The gapped row's child gets the taller extent: give children a top
/// alignment (an `Align`), always, so a row's subtree is the same widget
/// whether or not its gap is open (a remount loses the focused block).
class GapExtentList extends SliverMultiBoxAdaptorWidget {
  const GapExtentList({
    super.key,
    required super.delegate,
    required this.rowExtent,
    this.gapAfter,
    this.gapExtent = 0,
  });

  final double rowExtent;

  /// The row followed by the gap; null = no gap.
  final int? gapAfter;
  final double gapExtent;

  @override
  RenderGapExtentList createRenderObject(BuildContext context) =>
      RenderGapExtentList(
        childManager: context as SliverMultiBoxAdaptorElement,
        rowExtent: rowExtent,
        gapAfter: gapAfter,
        gapExtent: gapExtent,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderGapExtentList renderObject) {
    renderObject.update(
        rowExtent: rowExtent, gapAfter: gapAfter, gapExtent: gapExtent);
  }
}

class RenderGapExtentList extends RenderSliverFixedExtentBoxAdaptor {
  RenderGapExtentList({
    required super.childManager,
    required double rowExtent,
    int? gapAfter,
    double gapExtent = 0,
  })  : _rowExtent = rowExtent,
        _gapAfter = gapAfter,
        _gapExtent = gapExtent;

  double _rowExtent;
  int? _gapAfter;
  double _gapExtent;

  double get rowExtent => _rowExtent;

  /// The row followed by the gap, or null (none, or an empty gap).
  int? get gapAfter => _gapExtent > 0 ? _gapAfter : null;
  double get gapExtent => _gapExtent;

  void update(
      {required double rowExtent, int? gapAfter, double gapExtent = 0}) {
    if (rowExtent == _rowExtent &&
        gapAfter == _gapAfter &&
        gapExtent == _gapExtent) {
      return;
    }
    _rowExtent = rowExtent;
    _gapAfter = gapAfter;
    _gapExtent = gapExtent;
    markNeedsLayout();
  }

  static const double _tolerance = 1e-10;

  double? _extentOf(int index, SliverLayoutDimensions _) =>
      index == gapAfter ? _rowExtent + _gapExtent : _rowExtent;

  // Non-null so the base class sizes each child through it (and skips
  // its fixed-extent-only checks); every offset below is overridden.
  @override
  ItemExtentBuilder get itemExtentBuilder => _extentOf;

  @override
  double? get itemExtent => null;

  /// Where the row after the gap starts (null without a gap).
  double? get _gapEnd {
    final g = gapAfter;
    return g == null ? null : (g + 1) * _rowExtent + _gapExtent;
  }

  /// [RenderSliverFixedExtentList]'s own index maths, no gap.
  int _plainMin(double offset) {
    if (_rowExtent <= 0) return 0;
    final actual = offset / _rowExtent;
    final round = actual.round();
    if ((actual * _rowExtent - round * _rowExtent).abs() < _tolerance) {
      return round;
    }
    return actual.floor();
  }

  int _plainMax(double offset) {
    if (_rowExtent <= 0) return 0;
    final actual = offset / _rowExtent - 1;
    final round = actual.round();
    if ((actual * _rowExtent - round * _rowExtent).abs() < _tolerance) {
      return round < 0 ? 0 : round;
    }
    final up = actual.ceil();
    return up < 0 ? 0 : up;
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) {
    final g = gapAfter;
    return index * _rowExtent + (g != null && index > g ? _gapExtent : 0);
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    final g = gapAfter;
    final end = _gapEnd;
    if (g == null || end == null) return _plainMin(scrollOffset);
    // Up to the gap's end it's the gapped row (or one before it).
    if (scrollOffset < end - _tolerance) {
      final i = _plainMin(scrollOffset);
      return i < g ? i : g;
    }
    return _plainMin(scrollOffset - _gapExtent);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    final g = gapAfter;
    final end = _gapEnd;
    if (g == null || end == null) return _plainMax(scrollOffset);
    if (scrollOffset <= end + _tolerance) {
      final i = _plainMax(scrollOffset);
      return i < g ? i : g;
    }
    return _plainMax(scrollOffset - _gapExtent);
  }

  @override
  double computeMaxScrollOffset(
      SliverConstraints constraints, double itemExtent) {
    final count = childManager.childCount;
    final g = gapAfter;
    return count * _rowExtent + (g != null && g < count ? _gapExtent : 0);
  }

  // Exact, not the element's average-based guess (the gapped row would
  // inflate the average and the list would scroll past its end).
  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) =>
      computeMaxScrollOffset(constraints, -1);
}
