import 'package:flutter/material.dart';

import 'cp_empty_state.dart';

class CPErrorView extends StatelessWidget {
  const CPErrorView({
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.warning_amber_rounded,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CPEmptyState(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message,
      action: action,
    );
  }
}
