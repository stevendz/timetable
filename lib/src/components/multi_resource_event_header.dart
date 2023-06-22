import 'dart:ui';

import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter/rendering.dart';

import '../../timetable.dart';
import '../callbacks.dart';
import '../config.dart';
import '../date/controller.dart';
import '../date/date_page_view.dart';
import '../event/all_day.dart';
import '../event/builder.dart';
import '../event/event.dart';
import '../event/provider.dart';
import '../layouts/multi_date.dart';
import '../theme.dart';
import '../utils.dart';

/// A widget that displays all-day [Event]s.
///
/// A [DefaultDateController] and a [DefaultEventBuilder] must be above in the
/// widget tree.
///
/// If [onBackgroundTap] is not supplied, [DefaultTimetableCallbacks]'s
/// `onDateBackgroundTap` is used if it's provided above in the widget tree.
///
/// See also:
///
/// * [DefaultEventProvider] (and [TimetableConfig]), which provide the [Event]s
///   to be displayed.
/// * [MultiDateEventHeaderStyle], which defines visual properties for this
///   widget.
/// * [TimetableTheme] (and [TimetableConfig]), which provide styles to
///   descendant Timetable widgets.
/// * [DefaultTimetableCallbacks], which provides callbacks to descendant
///   Timetable widgets.
class MultiResourceEventHeader<E extends Event> extends StatelessWidget {
  const MultiResourceEventHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = TimetableTheme.orDefaultOf(context).multiDateEventHeaderStyle;

    final child = LayoutBuilder(builder: (context, constraints) {
      var maxEventRows = style.maxEventRows;
      if (constraints.maxHeight.isFinite) {
        final maxRowsFromHeight = (constraints.maxHeight / style.eventHeight).floor();
        final maxEventRowsFromHeight = (maxRowsFromHeight - 1).coerceAtLeast(0);
        maxEventRows = maxEventRowsFromHeight.coerceAtMost(maxEventRows);
      }

      return ValueListenableBuilder(
        valueListenable: DefaultDateController.of(context)!,
        builder: (context, date, _) => ValueListenableBuilder(
          valueListenable: DefaultResourceController.of(context)!,
          builder: (context, pageValue, __) => _buildContent(
            context,
            pageValue,
            eventHeight: style.eventHeight,
            maxEventRows: maxEventRows,
          ),
        ),
      );
    });

    return Stack(children: [
      Positioned.fill(
        child: ResourcePageView(builder: (context, date, res) => const SizedBox()),
      ),
      ClipRect(child: Padding(padding: style.padding, child: child)),
    ]);
  }

  Widget _buildContent(
    BuildContext context,
    ResourcePageValue pageValue, {
    required double eventHeight,
    required int maxEventRows,
  }) {
    return _MultiResourceEventHeaderEvents<E>(
      pageValue: pageValue,
      events:
          DefaultEventProvider.of<E>(context)?.call(DefaultDateController.of(context)!.date.value.fullDayInterval) ??
              [],
      eventHeight: eventHeight,
      maxEventRows: maxEventRows,
    );
  }
}

class _MultiResourceEventHeaderEvents<E extends Event> extends StatefulWidget {
  const _MultiResourceEventHeaderEvents({
    required this.pageValue,
    required this.events,
    required this.eventHeight,
    required this.maxEventRows,
  });

  final ResourcePageValue pageValue;
  final List<E> events;
  final double eventHeight;
  final int maxEventRows;

  @override
  State<_MultiResourceEventHeaderEvents<E>> createState() => _MultiResourceEventHeaderEventsState<E>();
}

class _MultiResourceEventHeaderEventsState<E extends Event> extends State<_MultiResourceEventHeaderEvents<E>> {
  final _yPositions = <E, int?>{};
  final _maxEventPositions = <int, int>{};

  @override
  void initState() {
    _updateEventPositions(oldMaxEventRows: null);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _MultiResourceEventHeaderEvents<E> oldWidget) {
    if (oldWidget.pageValue != widget.pageValue ||
        oldWidget.eventHeight != widget.eventHeight ||
        oldWidget.maxEventRows != widget.maxEventRows ||
        !const DeepCollectionEquality().equals(oldWidget.events, widget.events)) {
      _updateEventPositions(oldMaxEventRows: oldWidget.maxEventRows);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _updateEventPositions({required int? oldMaxEventRows}) {
    int getPage(String resource) => widget.pageValue.visibleRange.resources.indexOf(resource);

    // Remove events outside the current viewport (with some buffer).
    _yPositions.removeWhere((event, yPosition) {
      return getPage(event.resource!) > widget.pageValue.lastVisiblePage ||
          getPage(event.resource!) + 1 <= widget.pageValue.firstVisiblePage;
    });
    _maxEventPositions.removeWhere((date, _) {
      return date < widget.pageValue.firstVisiblePage || date > widget.pageValue.lastVisiblePage;
    });

    // Remove old events.
    _yPositions.removeWhere((it, _) => !widget.events.contains(it));

    if (oldMaxEventRows != null && oldMaxEventRows > widget.maxEventRows) {
      // Remove events that no longer fit the decreased `maxEventRows`.
      for (final entry in _yPositions.entries) {
        if (entry.value == null || entry.value! < widget.maxEventRows) continue;

        _yPositions[entry.key] = null;
      }
    }

    // Insert new events and, in case [maxEventRows] increased, display
    // previously overflowed events.
    final sortedEvents = widget.events.where((it) => _yPositions[it] == null).sortedByResource();

    Iterable<E> eventsWithPosition(int y) => _yPositions.entries.where((it) => it.value == y).map((it) => it.key);

    outer:
    for (final event in sortedEvents) {
      var y = 0;
      while (y < widget.maxEventRows) {
        final intersectingEvents = eventsWithPosition(y);
        if (intersectingEvents.every((it) => it.resource != event.resource)) {
          _yPositions[event] = y;
          continue outer;
        }

        y++;
      }
      _yPositions[event] = null;
    }

    for (final resource in widget.pageValue.visibleResourcesIterable) {
      final maxEventPosition = _yPositions.entries
          .where((it) => it.key.resource == resource)
          .map((it) => it.value ?? widget.maxEventRows)
          .maxOrNull;
      _maxEventPositions[getPage(resource)] = maxEventPosition != null ? maxEventPosition + 1 : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDayBuilder = DefaultEventBuilder.allDayOf<E>(context)!;
    final allDayOverflowBuilder = DefaultEventBuilder.allDayOverflowOf<E>(context)!;
    return _EventsWidget(
      pageValue: widget.pageValue,
      eventHeight: widget.eventHeight,
      maxEventRows: Map.from(_maxEventPositions),
      children: [
        for (final event in widget.events)
          if (_yPositions[event] != null)
            _EventParentDataWidget(
              key: ValueKey(event),
              resource: event.resource!,
              yPosition: _yPositions[event]!,
              child: _buildEvent(allDayBuilder, event),
            ),
        ...widget.pageValue.visibleResourcesIterable.mapNotNull((resource) {
          final maxPosition = _maxEventPositions[widget.pageValue.visibleRange.resources.indexOf(resource)]!;
          if (maxPosition <= widget.maxEventRows) return null;

          final overflowedEvents = widget.events.where((it) {
            return widget.pageValue.visibleResources.contains(it.resource) && _yPositions[it] == null;
          }).toList();

          return _EventParentDataWidget(
            key: ValueKey(resource),
            resource: resource,
            yPosition: widget.maxEventRows,
            child: allDayOverflowBuilder(context, DefaultDateController.of(context)!.date.value, overflowedEvents),
          );
        }),
      ],
    );
  }

  Widget _buildEvent(AllDayEventBuilder<E> allDayBuilder, E event) {
    return allDayBuilder(
      context,
      event,
      AllDayEventLayoutInfo(
        hiddenStartDays:
            (widget.pageValue.page - widget.pageValue.visibleRange.resources.indexOf(event.resource!)).coerceAtLeast(0),
        hiddenEndDays: (widget.pageValue.visibleRange.resources.indexOf(event.resource!) -
                widget.pageValue.page -
                widget.pageValue.visibleResourceCount)
            .coerceAtLeast(0),
      ),
    );
  }
}

class _EventParentDataWidget extends ParentDataWidget<_EventParentData> {
  _EventParentDataWidget({
    super.key,
    required this.resource,
    required this.yPosition,
    required super.child,
  });

  final String resource;
  final int yPosition;

  @override
  Type get debugTypicalAncestorWidgetClass => _EventsWidget;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is _EventParentData);
    final parentData = renderObject.parentData! as _EventParentData;

    if (parentData.resource == resource && parentData.yPosition == yPosition) {
      return;
    }

    parentData.resource = resource;
    parentData.yPosition = yPosition;
    final targetParent = renderObject.parent;
    if (targetParent is RenderObject) targetParent.markNeedsLayout();
  }
}

class _EventsWidget extends MultiChildRenderObjectWidget {
   _EventsWidget({
    required this.pageValue,
    required this.eventHeight,
    required this.maxEventRows,
    required super.children,
  });

  final ResourcePageValue pageValue;
  final double eventHeight;
  final Map<int, int> maxEventRows;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EventsLayout(
      pageValue: pageValue,
      eventHeight: eventHeight,
      maxEventRows: maxEventRows,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _EventsLayout renderObject) {
    renderObject
      ..pageValue = pageValue
      ..eventHeight = eventHeight
      ..maxEventRows = maxEventRows;
  }
}

class _EventParentData extends ContainerBoxParentData<RenderBox> {
  String? resource;
  int? yPosition;
}

class _EventsLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EventParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EventParentData> {
  _EventsLayout({
    required ResourcePageValue pageValue,
    required double eventHeight,
    required Map<int, int> maxEventRows,
  })  : _pageValue = pageValue,
        _eventHeight = eventHeight,
        _maxEventPositions = maxEventRows;

  ResourcePageValue _pageValue;

  ResourcePageValue get pageValue => _pageValue;

  set pageValue(ResourcePageValue value) {
    if (_pageValue == value) return;

    _pageValue = value;
    markNeedsLayout();
  }

  double _eventHeight;

  double get eventHeight => _eventHeight;

  set eventHeight(double value) {
    if (_eventHeight == value) return;

    _eventHeight = value;
    markNeedsLayout();
  }

  Map<int, int> _maxEventPositions;

  Map<int, int> get maxEventRows => _maxEventPositions;

  set maxEventRows(Map<int, int> value) {
    if (_maxEventPositions == value) return;

    _maxEventPositions = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _EventParentData) {
      child.parentData = _EventParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0;
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw Exception("$runtimeType doesn't have an intrinsic width.");
      }
      return true;
    }());
    return true;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _parallelEventCount() * eventHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _parallelEventCount() * eventHeight;

  @override
  void performLayout() {
    assert(!sizedByParent);

    if (children.isEmpty) {
      size = Size(constraints.maxWidth, 0);
      return;
    }

    size = Size(constraints.maxWidth, _parallelEventCount() * eventHeight);
    _positionEvents();
  }

  void _positionEvents() {
    //todo:show events for all resources over full width
    final dateWidth = size.width / pageValue.visibleResourceCount;
    for (final child in children) {
      final data = child.data;
      final startPage = pageValue.visibleRange.resources.indexOf(data.resource!);
      final left = ((startPage - pageValue.page) * dateWidth).coerceAtLeast(0);
      final endPage = startPage + 1;
      final right = ((endPage - pageValue.page) * dateWidth).coerceAtMost(size.width);

      child.layout(
        BoxConstraints(
          minWidth: right - left,
          maxWidth: (right - left).coerceAtLeast(dateWidth),
          minHeight: eventHeight,
          maxHeight: eventHeight,
        ),
        parentUsesSize: true,
      );
      final actualLeft = startPage >= pageValue.page ? left : left.coerceAtMost(right - child.size.width);
      data.offset = Offset(actualLeft, data.yPosition! * eventHeight);
    }
  }

  double _parallelEventCount() {
    int parallelEventsFrom(int page) {
      return page.rangeTo(page + pageValue.visibleResourceCount - 1).map((it) => _maxEventPositions[it]!).max;
    }

    final oldParallelEvents = parallelEventsFrom(pageValue.page.floor());
    final newParallelEvents = parallelEventsFrom(pageValue.page.ceil());
    final t = pageValue.page - pageValue.page.floorToDouble();
    return lerpDouble(oldParallelEvents, newParallelEvents, t)!;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

extension _ParentData on RenderBox {
  _EventParentData get data => parentData! as _EventParentData;
}
