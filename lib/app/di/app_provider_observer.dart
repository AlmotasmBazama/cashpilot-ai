import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';

final class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver(this._logger);

  final AppLogger _logger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error('Provider failed: ${context.provider}', error, stackTrace);
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (!kDebugMode) {
      return;
    }

    _logger.debug('Provider updated: ${context.provider}');
  }
}
