import 'package:flutter/material.dart';
import 'package:timetable/src/layouts/multi_date.dart';
import 'package:timetable/src/resource/resource_page_view.dart';

import '../../timetable.dart';
import '../components/date_header.dart';
import '../components/multi_date_content.dart';
import '../components/multi_date_event_header.dart';
import '../components/multi_resource_content.dart';
import '../components/resource_header.dart';
import '../components/time_indicators.dart';
import '../components/week_indicator.dart';
import '../config.dart';
import '../date/controller.dart';
import '../date/date_page_view.dart';
import '../event/builder.dart';
import '../event/event.dart';
import '../event/provider.dart';
import '../theme.dart';
import '../time/controller.dart';
import '../time/zoom.dart';
import '../utils.dart';
import '../utils/constraints_passing_column.dart';
import 'recurring_multi_date.dart';

typedef MultiResourceTimetableHeaderBuilder = Widget Function(
  BuildContext context,
  double? leadingWidth,
);
typedef MultiResourceTimetableContentBuilder = Widget Function(
  BuildContext context,
  ValueChanged<double> onLeadingWidthChanged,
);

/// A Timetable widget that displays multiple resources.
///
/// To configure it, provide a [DateController], [TimeController], [ResourceController]
/// [EventProvider], and [EventBuilder] via a [TimetableConfig] widget above in
/// the widget tree. (You can also provide these via `DefaultFoo` widgets
/// directly, like [DefaultDateController].)
class MultiResourceTimetable<E extends Event> extends StatefulWidget {
  factory MultiResourceTimetable({
    Key? key,
    MultiResourceTimetableHeaderBuilder? headerBuilder,
    MultiResourceTimetableContentBuilder? contentBuilder,
    Widget? contentLeading,
    GlobalKey<MultiResourceContentGeometry>? contentGeometryKey,
  }) {
    assert(
      contentBuilder == null || contentLeading == null,
      "`contentLeading` can't be used when `contentBuilder` is specified.",
    );
    assert(
      contentBuilder == null || contentGeometryKey == null,
      "`contentGeometryKey` can't be used when `contentBuilder` is specified.",
    );

    return MultiResourceTimetable.raw(
      key: key,
      headerBuilder: headerBuilder ?? _defaultHeaderBuilder<E>(),
      contentBuilder: contentBuilder ?? _defaultContentBuilder<E>(contentLeading, contentGeometryKey),
    );
  }

  const MultiResourceTimetable.raw({
    super.key,
    required this.headerBuilder,
    required this.contentBuilder,
  });

  final MultiResourceTimetableHeaderBuilder headerBuilder;

  static MultiResourceTimetableHeaderBuilder _defaultHeaderBuilder<E extends Event>() {
    return (context, leadingWidth) => MultiResourceTimetableHeader<E>(
          leading: SizedBox(
            width: leadingWidth,
            child: Align(
              heightFactor: 1,
              alignment: Alignment.center,
              child: WeekIndicator.forController(null),
            ),
          ),
        );
  }

  final MultiResourceTimetableContentBuilder contentBuilder;

  static MultiResourceTimetableContentBuilder _defaultContentBuilder<E extends Event>(
    Widget? contentLeading,
    GlobalKey<MultiResourceContentGeometry>? contentGeometryKey,
  ) {
    return (context, onLeadingWidthChanged) => MultiResourceTimetableContent<E>(
          leading: SizeReportingWidget(
            onSizeChanged: (size) => onLeadingWidthChanged(size.width),
            child: contentLeading ?? const DefaultContentLeading(),
          ),
          contentGeometryKey: contentGeometryKey,
        );
  }

  @override
  State<MultiResourceTimetable<E>> createState() => _MultiResourceTimetableState();
}

class _MultiResourceTimetableState<E extends Event> extends State<MultiResourceTimetable<E>> {
  double? _leadingWidth;

  @override
  Widget build(BuildContext context) {
    final style = TimetableTheme.orDefaultOf(context).multiDateTimetableStyle;
    final eventProvider = DefaultEventProvider.of<E>(context) ?? (_) => [];

    final header = DefaultEventProvider<E>(
      eventProvider: (visibleDates) => eventProvider(visibleDates).where((it) => it.isAllDay).toList(),
      child: Builder(
        builder: (context) => widget.headerBuilder(context, _leadingWidth),
      ),
    );

    final content = DefaultEventProvider<E>(
      eventProvider: (visibleDates) => eventProvider(visibleDates).where((it) => it.isPartDay).toList(),
      child: Builder(
        builder: (context) => widget.contentBuilder(
          context,
          (newWidth) => setState(() => _leadingWidth = newWidth),
        ),
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final maxHeaderHeight = constraints.maxHeight * style.maxHeaderFraction;
      return Column(children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeaderHeight),
          child: header,
        ),
        Expanded(child: content),
      ]);
    });
  }
}

class MultiResourceTimetableHeader<E extends Event> extends StatelessWidget {
  MultiResourceTimetableHeader({
    Key? key,
    Widget? leading,
    DateResourceWidgetBuilder? resourceHeaderBuilder,
    Widget? bottom,
  }) : this.raw(
          key: key,
          leading: leading ?? WeekIndicator.forController(null),
          resourceHeaderBuilder: resourceHeaderBuilder ?? ((context, date, resource) => ResourceHeader(resource)),
          bottom: bottom ?? MultiResourceEventHeader<E>(),
        );

  const MultiResourceTimetableHeader.raw({
    super.key,
    required this.leading,
    required this.resourceHeaderBuilder,
    required this.bottom,
  });

  final Widget leading;
  final DateResourceWidgetBuilder resourceHeaderBuilder;

  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      leading,
      Expanded(
        child: ConstraintsPassingColumn(children: [
          ResourcePageView(
            shrinkWrapInCrossAxis: true,
            builder: resourceHeaderBuilder,
          ),
          bottom,
        ]),
      ),
    ]);
  }
}

class MultiResourceTimetableContent<E extends Event> extends StatelessWidget {
  factory MultiResourceTimetableContent({
    Key? key,
    Widget? leading,
    Widget? divider,
    Widget? content,
    GlobalKey<MultiResourceContentGeometry>? contentGeometryKey,
  }) {
    assert(
      content == null || contentGeometryKey == null,
      "`contentGeometryKey` can't be used when `content` is specified.",
    );
    return MultiResourceTimetableContent.raw(
      key: key,
      leading: leading ?? const DefaultContentLeading(),
      divider: divider ?? const VerticalDivider(width: 0),
      content: content ?? MultiResourceContent<E>(geometryKey: contentGeometryKey),
    );
  }

  const MultiResourceTimetableContent.raw({
    super.key,
    required this.leading,
    required this.divider,
    required this.content,
  });

  final Widget leading;
  final Widget divider;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      leading,
      divider,
      Expanded(child: content),
    ]);
  }
}
