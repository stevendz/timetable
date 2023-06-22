import 'package:flutter/material.dart';
import 'package:timetable/src/layouts/multi_resource.dart';

import '../config.dart';
import '../date/controller.dart';
import '../date/visible_date_range.dart';
import '../event/builder.dart';
import '../event/event.dart';
import '../event/provider.dart';
import '../theme.dart';
import '../time/controller.dart';
import 'multi_date.dart';


class ResourceTimetable<E extends Event> extends StatelessWidget {
  ResourceTimetable({
    super.key,
    WidgetBuilder? timetableBuilder,
  }) : timetableBuilder = timetableBuilder ?? _defaultTimetableBuilder<E>();

  final WidgetBuilder timetableBuilder;
  static WidgetBuilder _defaultTimetableBuilder<E extends Event>() {
    return (context) => MultiResourceTimetable<E>(
      headerBuilder: (header, leadingWidth) => MultiResourceTimetableHeader<E>(
        leading: SizedBox(width: leadingWidth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = TimetableTheme.orDefaultOf(context);

    return TimetableTheme(
      data: theme.copyWith(
        dateHeaderStyleProvider: (date) => theme
            .dateHeaderStyleProvider(date)
            .copyWith(showDateIndicator: false),
      ),
      child: Builder(builder: timetableBuilder),
    );
  }
}
