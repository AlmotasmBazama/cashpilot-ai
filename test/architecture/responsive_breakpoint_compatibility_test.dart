import 'package:cashpilot_ai/core/responsive/app_breakpoints.dart';
import 'package:cashpilot_ai/shared/design_system/tokens/cp_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy and canonical breakpoint constants remain identical', () {
    expect(CPBreakpoints.compactMaxWidth, AppBreakpoints.compactMaxWidth);
    expect(CPBreakpoints.mediumMaxWidth, AppBreakpoints.mediumMaxWidth);
    expect(CPBreakpoints.contentMaxWidth, AppBreakpoints.contentMaxWidth);
  });

  test('legacy and canonical classifiers agree for boundary inputs', () {
    const widths = <double>[
      double.negativeInfinity,
      -1,
      0,
      598.999999,
      599,
      599.000001,
      838.999999,
      839,
      839.000001,
      1120,
      double.infinity,
      double.nan,
    ];

    for (final width in widths) {
      expect(
        cpWindowSizeClassForWidth(width).name,
        windowSizeClassForWidth(width).name,
        reason: 'classifiers diverged for width $width',
      );
    }
  });
}
