import 'package:flutter/material.dart';

import '../../../../shared/design_system/design_system.dart';

class AccountsLoadingState extends StatelessWidget {
  const AccountsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return CPAdaptivePage(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 920
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          return GridView.builder(
            itemCount: columns == 1 ? 3 : columns * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: CPSpacing.lg,
              crossAxisSpacing: CPSpacing.lg,
              childAspectRatio: columns == 1 ? 1.75 : 1.35,
            ),
            itemBuilder: (_, _) => const CPSkeletonCard(height: 210),
          );
        },
      ),
    );
  }
}
