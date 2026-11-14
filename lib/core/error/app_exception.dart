class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  const AppException.cache({
    required String message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) : this(
         message: message,
         code: code ?? 'cache_error',
         cause: cause,
         stackTrace: stackTrace,
       );

  const AppException.validation({
    required String message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) : this(
         message: message,
         code: code ?? 'validation_error',
         cause: cause,
         stackTrace: stackTrace,
       );

  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final resolvedCode = code == null ? '' : '[$code] ';
    return 'AppException: $resolvedCode$message';
  }
}
