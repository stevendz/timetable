import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' hide Interval;

import '../config.dart';
import '../date/controller.dart';
import '../date/date_page_view.dart';
import '../event/event.dart';
import '../event/provider.dart';
import '../resource/controller.dart';
import '../resource/resource_page_view.dart';
import '../time/overlay.dart';
import '../time/zoom.dart';
import '../utils.dart';
import 'date_content.dart';
import 'date_dividers.dart';
import 'hour_dividers.dart';
import 'now_indicator.dart';

/// A widget that displays the content of multiple resources, zoomable
/// and with decoration like date and hour dividers.
///
/// A [DefaultResourceController] must be above in the widget tree.
///
/// See also:
///
/// * [PartDayDraggableEvent], which can be wrapped around an event widget to
///   make it draggable to a different time or date.
/// * [DefaultEventProvider] (and [TimetableConfig]), which provide the [Event]s
///   to be displayed.
/// * [DefaultTimeOverlayProvider] (and [TimetableConfig]), which provide the
///   [TimeOverlay]s to be displayed.
/// * [DateDividers], [TimeZoom], [HourDividers], [NowIndicator],
///   [DatePageView], and [DateContent], which are used internally by this
///   widget and can be styled.
class MultiResourceContent<E extends Event> extends StatefulWidget {
  const MultiResourceContent({super.key, this.geometryKey});

  final GlobalKey<MultiResourceContentGeometry>? geometryKey;

  @override
  State<MultiResourceContent<E>> createState() => _MultiResourceContentState<E>();
}

class _MultiResourceContentState<E extends Event> extends State<MultiResourceContent<E>> {
  late GlobalKey<MultiResourceContentGeometry> geometryKey;
  late bool wasGeometryKeyFromWidget;

  @override
  void initState() {
    super.initState();
    geometryKey = widget.geometryKey ?? GlobalKey();
    wasGeometryKeyFromWidget = widget.geometryKey != null;
  }

  @override
  void didUpdateWidget(covariant MultiResourceContent<E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.geometryKey == null && wasGeometryKeyFromWidget) {
      geometryKey = GlobalKey();
      wasGeometryKeyFromWidget = false;
    } else if (widget.geometryKey != null && geometryKey != widget.geometryKey) {
      geometryKey = widget.geometryKey!;
      wasGeometryKeyFromWidget = true;
    }
  }

  @override
  Widget build(BuildContext context) {

    final resourcePages = ResourcePageView(
      controller: DefaultResourceController.of(context)!,
      builder: (context, date, resource) => DateContent<E>(
        date: date,
        events: DefaultEventProvider.of<E>(context)
                ?.call(date.fullDayInterval)
                .where((element) => element.resource == resource)
                .toList() ??
            [],
        overlays: DefaultTimeOverlayProvider.of(context)?.call(context, date, resource) ?? [],
      ),
    );

    return DateDividers(
      child: TimeZoom(
        child: HourDividers(
          child: NowIndicator(
            child: _MultiResourceContentGeometryWidget(
              key: geometryKey,
              child: resourcePages,
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiResourceContentGeometryWidget extends StatefulWidget {
  const _MultiResourceContentGeometryWidget({
    required GlobalKey<MultiResourceContentGeometry> key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  MultiResourceContentGeometry createState() => MultiResourceContentGeometry._();
}

class MultiResourceContentGeometry extends State<_MultiResourceContentGeometryWidget> {
  MultiResourceContentGeometry._();

  @override
  Widget build(BuildContext context) => widget.child;

  bool contains(Offset globalOffset) {
    final renderBox = _findRenderBox();
    final localOffset = renderBox.globalToLocal(globalOffset);
    return (Offset.zero & renderBox.size).contains(localOffset);
  }

  DateTime resolveOffset(Offset globalOffset) {
    final renderBox = _findRenderBox();
    final size = renderBox.size;
    final localOffset = renderBox.globalToLocal(globalOffset);
    final pageValue = DefaultDateController.of(context)!.value;
    final page = (pageValue.page + localOffset.dx / size.width * pageValue.visibleDayCount).floor();
    return DateTimeTimetable.dateFromPage(page) + 1.days * (localOffset.dy / size.height);
  }

  RenderBox _findRenderBox() => context.findRenderObject()! as RenderBox;

  static MultiResourceContentGeometry? maybeOf(BuildContext context) => context.findAncestorStateOfType();
}
