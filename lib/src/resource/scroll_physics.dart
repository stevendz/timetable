import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:timetable/src/resource/resource_page_view.dart';

import 'visible_resource_range.dart';

class ResourceScrollPhysics extends ScrollPhysics {
  const ResourceScrollPhysics(this.visibleRangeListenable, {super.parent});

  final ValueListenable<VisibleResourceRange> visibleRangeListenable;
  VisibleResourceRange get visibleRange => visibleRangeListenable.value;

  @override
  ResourceScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ResourceScrollPhysics(visibleRangeListenable, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position is! MultiResourceScrollPosition) {
      throw ArgumentError(
        'ResourceScrollPhysics must be used with MultiDateScrollPosition.',
      );
    }

    final page = position.pixelsToPage(value);
    final overscrollPages = visibleRange.applyBoundaryConditions(page);
    final overscroll = position.pageDeltaToPixelDelta(overscrollPages);

    // Flutter doesn't allow boundary conditions to apply greater differences
    // than the actual delta. Due to numbers having a limited precision, this
    // occurs fairly often after conversion between pixels and pages, hence we
    // clamp the final value.
    final maximumDelta = (value - position.pixels).abs();
    return overscroll.clamp(-maximumDelta, maximumDelta);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position,
      double velocity,
      ) {
    if (position is! MultiResourceScrollPosition) {
      throw ArgumentError(
        'ResourceScrollPhysics must be used with MultiResourceScrollPosition.',
      );
    }

    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at a page boundary.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final targetPage = visibleRange.getTargetPageForCurrent(
      position.page,
      velocity: position.pixelDeltaToPageDelta(velocity),
      tolerance: Tolerance(
        distance: position.pixelDeltaToPageDelta(tolerance.distance),
        time: tolerance.time,
        velocity: position.pixelDeltaToPageDelta(tolerance.velocity),
      ),
    );
    final target = position.pageToPixels(targetPage);

    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

Tolerance toleranceFor(ScrollMetrics position) {
  final devicePixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
  return Tolerance(
    velocity: 1 / (0.050 * devicePixelRatio),
    distance: 1 / devicePixelRatio,
  );
}
