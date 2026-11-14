import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CPEmptyState(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message,
    );
  }
}
