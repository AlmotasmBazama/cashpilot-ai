import 'package:freezed_annotation/freezed_annotation.dart';

import 'failure.dart';

part 'result.freezed.dart';

@freezed
sealed class AppResult<T> with _$AppResult<T> {
  const factory AppResult.success(T data) = AppSuccess<T>;

  const factory AppResult.failure(Failure failure) = AppFailure<T>;
}
