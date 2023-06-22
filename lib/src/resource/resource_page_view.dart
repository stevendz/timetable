import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../timetable.dart';
import '../utils.dart';
import 'controller.dart';
import 'scroll_physics.dart';

/// "DateTimes can represent time values that are at a distance of at most
/// 100,000,000 days from epoch […]".
const _precisionErrorTolerance = 1e-5;

/// A page view for displaying resources that supports shrink-wrapping in the cross
/// axis.
///
/// A controller has to be provided, either directly via the constructor, or via
/// a [DefaultResourceController] above in the widget tree.
class ResourcePageView extends StatefulWidget {
  const ResourcePageView({
    super.key,
    this.controller,
    this.shrinkWrapInCrossAxis = false,
    required this.builder,
  });

  final ResourceController? controller;
  final bool shrinkWrapInCrossAxis;
  final DateResourceWidgetBuilder builder;

  @override
  State<ResourcePageView> createState() => _ResourcePageViewState();
}

class _ResourcePageViewState extends State<ResourcePageView> {
  ResourceController? _controller;
  MultiResourceScrollController? _scrollController;
  final _heights = <int, double>{};

  @override
  void didUpdateWidget(ResourcePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(_controller != null);
    _updateController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateController();
  }

  @override
  void dispose() {
    _controller!.resource.removeListener(_onResourceChanged);
    _scrollController!.dispose();
    super.dispose();
  }

  void _updateController() {
    if (_controller != null && widget.controller == _controller) return;

    if (_controller != null && !_controller!.isDisposed) {
      _controller!.resource.removeListener(_onResourceChanged);
      _scrollController!.dispose();
    }

    _controller = widget.controller ?? DefaultResourceController.of(context)!;
    _scrollController = MultiResourceScrollController(_controller!);
    _controller!.resource.addListener(_onResourceChanged);
  }

  void _onResourceChanged() {
    final resourcePageValue = _controller!.value;
    final firstPage = resourcePageValue.page.round();
    final lastPage = resourcePageValue.page.round() + resourcePageValue.visibleResourceCount;
    _heights.removeWhere((key, _) => key < firstPage - 5 || key > lastPage + 5);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scrollable(
      axisDirection: AxisDirection.right,
      physics: ResourceScrollPhysics(_controller!.map((it) => it.visibleRange)),
      controller: _scrollController!,
      viewportBuilder: (context, position) => Viewport(
        axisDirection: AxisDirection.right,
        offset: position,
        slivers: [
          ValueListenableBuilder(
            valueListenable: _controller!.map((it) => it.visibleResourceCount),
            builder: (context, visibleResourceCount, _) => SliverFillViewport(
              padEnds: false,
              viewportFraction: 1 / visibleResourceCount,
              delegate: SliverChildBuilderDelegate(
                _buildPage,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.shrinkWrapInCrossAxis) {
      child = ValueListenableBuilder(
        valueListenable: _controller!,
        builder: (context, pageValue, child) => ImmediateSizedBox(
          heightGetter: () => _getHeight(pageValue),
          child: child!,
        ),
        child: child,
      );
    }
    return child;
  }

  double _getHeight(ResourcePageValue pageValue) {
    double maxHeightFrom(int page) {
      return page.rangeTo(page + pageValue.visibleResourceCount - 1).map((it) => _heights[it] ?? 0).max.toDouble();
    }

    final oldMaxHeight = maxHeightFrom(pageValue.page.floor());
    final newMaxHeight = maxHeightFrom(pageValue.page.ceil());
    final t = pageValue.page - pageValue.page.floorToDouble();
    return lerpDouble(oldMaxHeight, newMaxHeight, t)!;
  }

  Widget _buildPage(BuildContext context, int page) {
    final resources = _controller!.visibleRange.resources;
    Widget child = ValueListenableBuilder(
      valueListenable: DefaultDateController.of(context)!.date,
      builder: (context, date, _) => widget.builder(
        context,
        date,
        resources.length > page ? resources[page] : "",
      ),
    );
    if (widget.shrinkWrapInCrossAxis) {
      child = ImmediateSizeReportingOverflowPage(
        onSizeChanged: (size) {
          if (_heights[page] == size.height) return;
          _heights[page] = size.height;
          WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
        },
        child: child,
      );
    }
    return child;
  }
}

class MultiResourceScrollController extends ScrollController {
  MultiResourceScrollController(this.controller) : super(initialScrollOffset: controller.value.page) {
    controller.addListener(_listenToController);
  }

  final ResourceController controller;

  int get visibleResourceCount => controller.value.visibleResourceCount;

  double get page => position.page;

  void _listenToController() {
    if (hasClients) position.forcePage(controller.value.page);
  }

  @override
  void dispose() {
    controller.removeListener(_listenToController);
    super.dispose();
  }

  @override
  void attach(ScrollPosition position) {
    assert(
      position is MultiResourceScrollPosition,
      'MultiResourceScrollControllers can only be used with '
      'MultiResourceScrollPositions.',
    );
    final linkedPosition = position as MultiResourceScrollPosition;
    assert(
      linkedPosition.controller == controller,
      'MultiResourceScrollPosition cannot change controllers once created.',
    );
    super.attach(position);
  }

  @override
  MultiResourceScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return MultiResourceScrollPosition(
      this,
      physics: physics,
      context: context,
      initialPage: initialScrollOffset,
      oldPosition: oldPosition,
    );
  }

  @override
  MultiResourceScrollPosition get position => super.position as MultiResourceScrollPosition;
}

class MultiResourceScrollPosition extends ScrollPositionWithSingleContext {
  MultiResourceScrollPosition(
    this.owner, {
    required super.physics,
    required super.context,
    required this.initialPage,
    super.oldPosition,
  }) : super(initialPixels: null);

  final MultiResourceScrollController owner;

  ResourceController get controller => owner.controller;
  double initialPage;

  double get page => pixelsToPage(pixels);

  @override
  bool applyViewportDimension(double viewportDimension) {
    final hadViewportDimension = hasViewportDimension;
    final isInitialLayout = !hasPixels || !hadViewportDimension;
    final oldPixels = hasPixels ? pixels : null;
    final page = isInitialLayout ? initialPage : this.page;

    final result = super.applyViewportDimension(viewportDimension);
    final newPixels = pageToPixels(page);
    if (newPixels != oldPixels) {
      correctPixels(newPixels);
      return false;
    }
    return result;
  }

  bool _isApplyingNewDimensions = false;

  @override
  void applyNewDimensions() {
    _isApplyingNewDimensions = true;
    super.applyNewDimensions();
    _isApplyingNewDimensions = false;
  }

  @override
  void goBallistic(double velocity) {
    if (_isApplyingNewDimensions) {
      assert(velocity == 0);
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  double setPixels(double newPixels) {
    if (newPixels == pixels) return 0;

    _updateUserScrollDirectionFromDelta(newPixels - pixels);
    final overscroll = super.setPixels(newPixels);

    final activity = this.activity;
    final dateScrollActivity = activity is DragScrollActivity ||
            (activity is BallisticScrollActivity && activity.velocity.abs() > precisionErrorTolerance)
        ? const DragResourceScrollActivity()
        : const IdleResourceScrollActivity();
    controller.value = controller.value.copyWithActivity(
      page: pixelsToPage(pixels),
      activity: dateScrollActivity,
    );
    return overscroll;
  }

  void forcePage(double page) => forcePixels(pageToPixels(page));

  @override
  void forcePixels(double value) {
    if (value == pixels) return;

    _updateUserScrollDirectionFromDelta(value - pixels);
    super.forcePixels(value);
  }

  void _updateUserScrollDirectionFromDelta(double delta) {
    final direction = delta > 0 ? ScrollDirection.forward : ScrollDirection.reverse;
    updateUserScrollDirection(direction);
  }

  double pixelsToPage(double pixels) => pixelDeltaToPageDelta(pixels);

  double pageToPixels(double page) => pageDeltaToPixelDelta(page);

  double pixelDeltaToPageDelta(double pixels) {
    final result = pixels * owner.visibleResourceCount / viewportDimension;
    final closestWholeNumber = result.roundToDouble();
    if ((result - closestWholeNumber).abs() <= _precisionErrorTolerance) {
      return closestWholeNumber;
    }
    return result;
  }

  double pageDeltaToPixelDelta(double page) => page / owner.visibleResourceCount * viewportDimension;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('owner: $owner');
  }
}
