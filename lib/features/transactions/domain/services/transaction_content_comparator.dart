import 'dart:convert';

import '../entities/transaction.dart';

/// Compares transaction content by value while normalizing equivalent UTC and
/// local [DateTime] representations produced by persistence round-trips.
bool transactionContentEquals(
  Transaction left,
  Transaction right, {
  bool ignoreUpdatedAt = false,
}) {
  return canonicalTransactionJson(left, ignoreUpdatedAt: ignoreUpdatedAt) ==
      canonicalTransactionJson(right, ignoreUpdatedAt: ignoreUpdatedAt);
}

String canonicalTransactionJson(
  Transaction transaction, {
  bool ignoreUpdatedAt = false,
}) {
  final exchangeRate = transaction.exchangeRate;
  final normalized = transaction.copyWith(
    transactionDate: _persistenceInstant(transaction.transactionDate),
    createdAt: _persistenceInstant(transaction.createdAt),
    updatedAt: _persistenceInstant(transaction.updatedAt),
    exchangeRate: exchangeRate?.copyWith(
      asOf: exchangeRate.asOf == null
          ? null
          : _persistenceInstant(exchangeRate.asOf!),
    ),
  );
  final value = Map<String, dynamic>.from(normalized.toJson());
  if (ignoreUpdatedAt) value.remove('updatedAt');
  return jsonEncode(_canonicalize(value));
}

DateTime _persistenceInstant(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(
      (value.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );

Object? _canonicalize(Object? value) {
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
