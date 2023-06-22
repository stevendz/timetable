import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Interval;

import '../config.dart';
import '../utils.dart';
import 'visible_resource_range.dart';

/// Controls the visible resources in Timetable widgets.
///
/// You can read (and listen to) the currently visible resources via [resource].
///
/// To programmatically change the visible resources, use any of the following
/// functions:
///
/// * [animateToToday], [animateTo], or [animateToPage] if you want an animation
/// * [jumpToToday], [jumpTo], or [jumpToPage] if you don't want an animation
///
/// You can also get and update the [VisibleResourceRange] via [visibleRange].
class ResourceController extends ValueNotifier<ResourcePageValueWithScrollActivity> {
  ResourceController({
    int? initialIndex,
    required VisibleResourceRange visibleRange,
  }) :
  // We set the correct value in the body below.
        super(ResourcePageValueWithScrollActivity(
        visibleRange,
        0,
        const IdleResourceScrollActivity(),
      )) {
    // The correct value is set via the listener when we assign to our value.
    _resource = ValueNotifier(visibleRange.resources.first);
    addListener(() => _resource.value = value.resource);

    // The correct value is set via the listener when we assign to our value.
    _visibleResources = ValueNotifier([visibleRange.resources.first]);
    addListener(() => _visibleResources.value = value.visibleResources);

    final rawStartPage = initialIndex?.toDouble() ?? 0.0;
    value = value.copyWithActivity(
      page: value.visibleRange.getTargetPageForFocus(rawStartPage),
      activity: const IdleResourceScrollActivity(),
    );
  }

  late final ValueNotifier<String> _resource;

  ValueListenable<String> get resource => _resource;

  VisibleResourceRange get visibleRange => value.visibleRange;

  set visibleRange(VisibleResourceRange visibleRange) {
    cancelAnimation();
    value = value.copyWithActivity(
      page: visibleRange.getTargetPageForFocus(value.page),
      visibleRange: visibleRange,
      activity: const IdleResourceScrollActivity(),
    );
  }

  late final ValueNotifier<List<String>> _visibleResources;

  ValueListenable<List<String>> get visibleResources => _visibleResources;

  // Animation
  AnimationController? _animationController;


  Future<void> animateTo(String resource, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 200),
    required TickerProvider vsync,
  }) {
    return animateToPage(
      visibleRange.resources.indexOf(resource).toDouble(),
      curve: curve,
      duration: duration,
      vsync: vsync,
    );
  }

  Future<void> animateToPage(double page, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 200),
    required TickerProvider vsync,
  }) async {
    cancelAnimation();
    final controller =
    AnimationController(debugLabel: 'DateController', vsync: vsync);
    _animationController = controller;

    final previousPage = value.page;
    final targetPage = value.visibleRange.getTargetPageForFocus(page);
    final targetResourcePageValue = ResourcePageValue(visibleRange, targetPage);
    controller.addListener(() {
      value = value.copyWithActivity(
        page: lerpDouble(previousPage, targetPage, controller.value)!,
        activity: controller.isAnimating
            ? DrivenResourceScrollActivity(targetResourcePageValue)
            : const IdleResourceScrollActivity(),
      );
    });

    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      controller.dispose();
      _animationController = null;
    });

    await controller.animateTo(1, duration: duration, curve: curve);
  }

  void jumpTo(String resource) {
    jumpToPage(visibleRange.resources.indexOf(resource).toDouble());
  }

  void jumpToPage(double page) {
    cancelAnimation();
    value = value.copyWithActivity(
      page: value.visibleRange.getTargetPageForFocus(page),
      activity: const IdleResourceScrollActivity(),
    );
  }

  void cancelAnimation() {
    if (_animationController == null) return;

    value = value.copyWithActivity(activity: const IdleResourceScrollActivity());
    _animationController!.dispose();
    _animationController = null;
  }

  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _resource.dispose();
    super.dispose();
    _isDisposed = true;
  }
}

/// The value held by [ResourceController].
@immutable
class ResourcePageValue with Diagnosticable {
  const ResourcePageValue(this.visibleRange, this.page);

  final VisibleResourceRange visibleRange;

  int get visibleResourceCount => visibleRange.visibleResourceCount;

  final double page;

  String get resource => visibleRange.resources[page.round()];

  int get firstVisiblePage => page.floor();

  /// The first resource that is at least partially visible.
  String get firstVisibleResource {
    return visibleRange.resources[firstVisiblePage];
  }

  int get lastVisiblePage => page.ceil() + visibleResourceCount - 1;

  /// The last resource that is at least partially visible.
  String get lastVisibleResource {
    return visibleRange.resources[lastVisiblePage];
  }

  /// The interval of resources that are at least partially visible.
  List<String> get visibleResources {
    return visibleRange.resources.sublist(firstVisiblePage, lastVisiblePage);
  }

  Iterable<String> get visibleResourcesIterable sync* {
    var currentIndex = firstVisiblePage;
    while (currentIndex <= lastVisiblePage) {
      yield visibleRange.resources[currentIndex];
      currentIndex += 1;
    }
  }

  ResourcePageValue copyWith({VisibleResourceRange? visibleRange, double? page}) =>
      ResourcePageValue(visibleRange ?? this.visibleRange, page ?? this.page);

  @override
  int get hashCode => Object.hash(visibleRange, page);

  @override
  bool operator ==(Object other) {
    return other is ResourcePageValue &&
        visibleRange == other.visibleRange &&
        page == other.page;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('visibleRange', visibleRange));
    properties.add(DoubleProperty('page', page));
    properties.add(DiagnosticsProperty('resource', resource));
  }
}

class ResourcePageValueWithScrollActivity extends ResourcePageValue {
  const ResourcePageValueWithScrollActivity(super.visibleRange,
      super.page,
      this.activity,);

  final ResourceScrollActivity activity;

  ResourcePageValueWithScrollActivity copyWithActivity({
    VisibleResourceRange? visibleRange,
    double? page,
    required ResourceScrollActivity activity,
  }) {
    return ResourcePageValueWithScrollActivity(
      visibleRange ?? this.visibleRange,
      page ?? this.page,
      activity,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('activity', activity));
  }
}

/// The equivalent of [ScrollActivity] for [ResourceController].
@immutable
abstract class ResourceScrollActivity with Diagnosticable {
  const ResourceScrollActivity();
}

/// A scroll activity that does nothing.
class IdleResourceScrollActivity extends ResourceScrollActivity {
  const IdleResourceScrollActivity();
}

/// The activity a [ResourceController] performs when the user drags their finger
/// across the screen and is settling afterwards.
class DragResourceScrollActivity extends ResourceScrollActivity {
  const DragResourceScrollActivity();
}

/// A scroll activity for when the [ResourceController] is animated to a new page.
class DrivenResourceScrollActivity extends ResourceScrollActivity {
  const DrivenResourceScrollActivity(this.target);

  final ResourcePageValue target;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('target', target));
  }
}

/// Provides the [ResourceController] for Timetable widgets below it.
///
/// See also:
///
/// * [TimetableConfig], which bundles multiple configuration widgets for
///   Timetable.
class DefaultResourceController extends InheritedWidget {
  const DefaultResourceController({required this.controller, required super.child});

  final ResourceController controller;

  @override
  bool updateShouldNotify(DefaultResourceController oldWidget) =>
      controller != oldWidget.controller;

  static ResourceController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DefaultResourceController>()
        ?.controller;
  }
}