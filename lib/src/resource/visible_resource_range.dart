import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import '../layouts/recurring_multi_date.dart';
import '../utils.dart';

/// Defines how many resources are visible at once
class VisibleResourceRange with Diagnosticable {
  VisibleResourceRange({
    required this.visibleResourceCount,
    required this.resources,
    this.swipeRange = 1,
  })  : assert(visibleResourceCount > 0),
        assert(resources.isNotEmpty) {
    maxPage = _getMinimumPageForFocus(resources.length - 1);
  }

  final int visibleResourceCount;
  final List<String> resources;
  final int swipeRange;

  late final double? maxPage;

  double getTargetPageForFocus(
    double focusPage, {
    double velocity = 0,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }) {
    // Taken from [_InteractiveViewerState._kDrag].
    const kDrag = 0.0000135;
    final simulation = FrictionSimulation(kDrag, focusPage, velocity, tolerance: tolerance);
    final targetFocusPage = simulation.finalX;

    final alignmentDifference = targetFocusPage.floor() % swipeRange;
    final alignmentCorrectedTargetPage = targetFocusPage - alignmentDifference;
    final swipeAlignedTargetPage = (alignmentCorrectedTargetPage / swipeRange).floor() * swipeRange;
    return swipeAlignedTargetPage.toDouble();
  }

  double _getMinimumPageForFocus(double focusPage) {
    var page = focusPage - visibleResourceCount;
    while (true) {
      final target = getTargetPageForFocus(page);
      if (target + visibleResourceCount > focusPage) return target;
      page += swipeRange;
    }
  }

  double getTargetPageForCurrent(
    double currentPage, {
    double velocity = 0,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }) {
    return getTargetPageForFocus(
      currentPage + swipeRange / 2,
      velocity: velocity,
      tolerance: tolerance,
    );
  }

  double applyBoundaryConditions(double page) {
    final targetPage = page.coerceIn(0, maxPage ?? 0);
    return page - targetPage;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('swipeRange', swipeRange));
  }
}
