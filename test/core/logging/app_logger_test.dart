import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  test('shared logger redacts messages and arbitrary exception values', () {
    final output = MemoryOutput();
    final logger = AppLogger.forTesting(output);

    logger.error(
      'Failed for secret@example.com uid=user-123 '
      'phone=٠٩١٢٣٤٥٦٧٨ token=private-test-value.',
      StateError(
        'raw exception secret@example.com 0912345678 private-test-value',
      ),
    );

    final rendered = output.buffer.single.lines.join('\n');
    expect(rendered, contains('[redacted-email]'));
    expect(rendered, contains('[redacted-phone]'));
    expect(rendered, contains('uid=[redacted]'));
    expect(rendered, contains('token=[redacted]'));
    expect(rendered, contains('Redacted error (StateError)'));
    expect(rendered, isNot(contains('secret@example.com')));
    expect(rendered, isNot(contains('٠٩١٢٣٤٥٦٧٨')));
    expect(rendered, isNot(contains('0912345678')));
    expect(rendered, isNot(contains('private-test-value')));
    expect(rendered, isNot(contains('raw exception')));
  });

  test('shared logger exposes only the safe owner-scope failure code', () {
    final output = MemoryOutput();
    final logger = AppLogger.forTesting(output);

    logger.error(
      'Scoped operation failed.',
      const OwnerScopeException(OwnerScopeFailure.activeScopeChanged),
    );

    final rendered = output.buffer.single.lines.join('\n');
    expect(
      rendered,
      contains('Redacted error (OwnerScopeException:activeScopeChanged)'),
    );
    expect(rendered, isNot(contains('OwnerScopeId')));
    expect(rendered, isNot(contains('ConfirmedOwnerScope')));
  });
}
