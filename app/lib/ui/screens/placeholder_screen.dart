import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../widgets/status_widgets.dart';

/// Stand-in for screens scheduled for a later phase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: S.placeholderTitle,
      body: S.placeholderBody,
    );
  }
}
