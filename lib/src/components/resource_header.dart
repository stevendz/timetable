import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../callbacks.dart';
import '../config.dart';
import '../localization.dart';
import '../theme.dart';
import '../utils.dart';
import 'date_indicator.dart';
import 'weekday_indicator.dart';

class ResourceHeader extends StatelessWidget {
  const ResourceHeader(
    this.resource, {
    super.key,
    this.onTap,
  });

  final String resource;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(child: Text(resource)),
    );
  }
}
