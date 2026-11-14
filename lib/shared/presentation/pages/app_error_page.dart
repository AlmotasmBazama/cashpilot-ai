import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../widgets/empty_state.dart';

class AppErrorPage extends StatelessWidget {
  const AppErrorPage({required this.error, super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.warning_amber_rounded,
        title: context.l10n.routeNotFoundTitle,
        message: context.l10n.routeNotFoundMessage,
      ),
    );
  }
}
