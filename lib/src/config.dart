import 'package:flutter/material.dart';
import 'package:timetable/src/resource/controller.dart';

import 'callbacks.dart';
import 'date/controller.dart';
import 'event/all_day.dart';
import 'event/builder.dart';
import 'event/event.dart';
import 'event/provider.dart';
import 'resource/visible_resource_range.dart';
import 'theme.dart';
import 'time/controller.dart';
import 'time/overlay.dart';

class TimetableConfig<E extends Event> extends StatefulWidget {
  TimetableConfig({
    super.key,
    this.dateController,
    this.timeController,
    this.resourceController,
    EventProvider<E>? eventProvider,
    this.eventBuilder,
    this.allDayEventBuilder,
    this.allDayOverflowBuilder,
    this.timeOverlayProvider,
    this.callbacks,
    this.theme,
    required this.child,
  }) : eventProvider = eventProvider?.debugChecked;

  final DateController? dateController;
  final TimeController? timeController;
  final ResourceController? resourceController;
  final EventProvider<E>? eventProvider;
  final EventBuilder<E>? eventBuilder;
  final AllDayEventBuilder<E>? allDayEventBuilder;
  final AllDayOverflowBuilder<E>? allDayOverflowBuilder;
  final TimeOverlayProvider? timeOverlayProvider;
  final TimetableCallbacks? callbacks;
  final TimetableThemeData? theme;
  final Widget child;

  @override
  State<TimetableConfig<E>> createState() => _TimetableConfigState<E>();
}

class _TimetableConfigState<E extends Event> extends State<TimetableConfig<E>> {
  late final _dateController = DateController();
  late final _timeController = TimeController();
  late final _resourceController = ResourceController(
    visibleRange: VisibleResourceRange(
      visibleResourceCount: 1,
      resources: [''],
    ),
  );

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _resourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = DefaultTimetableCallbacks(
      callbacks: widget.callbacks ?? DefaultTimetableCallbacks.of(context) ?? const TimetableCallbacks(),
      child: TimetableTheme(
        data: widget.theme ?? TimetableTheme.of(context) ?? TimetableThemeData(context),
        child: widget.child,
      ),
    );

    child = DefaultTimeOverlayProvider(
      overlayProvider: widget.timeOverlayProvider ?? DefaultTimeOverlayProvider.of(context) ?? emptyTimeOverlayProvider,
      child: child,
    );

    child = DefaultEventProvider<E>(
      eventProvider: widget.eventProvider ?? DefaultEventProvider.of<E>(context) ?? (_) => [],
      child: DefaultEventBuilder(
        builder: widget.eventBuilder ?? DefaultEventBuilder.of<E>(context)!,
        allDayBuilder: widget.allDayEventBuilder,
        allDayOverflowBuilder: widget.allDayOverflowBuilder,
        child: child,
      ),
    );

    return DefaultDateController(
      controller: widget.dateController ?? DefaultDateController.of(context) ?? _dateController,
      child: DefaultTimeController(
        controller: widget.timeController ?? DefaultTimeController.of(context) ?? _timeController,
        child: DefaultResourceController(
          controller: widget.resourceController ?? DefaultResourceController.of(context) ?? _resourceController,
          child: child,
        ),
      ),
    );
  }
}
