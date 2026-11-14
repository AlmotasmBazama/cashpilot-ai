import 'package:uuid/uuid.dart';

import '../enums/insight_severity.dart';
import '../enums/insight_type.dart';
import 'insight_evidence.dart';

class FinancialInsight {
  const FinancialInsight({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.evidence,
    required this.createdAt,
    required this.periodStart,
    required this.periodEnd,
    this.actionLabel,
    this.actionRoute,
  });

  factory FinancialInsight.create({
    required InsightType type,
    required InsightSeverity severity,
    required String title,
    required String message,
    required InsightEvidence evidence,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? actionLabel,
    String? actionRoute,
    String? id,
    DateTime? createdAt,
  }) {
    return FinancialInsight(
      id: id ?? const Uuid().v7(),
      type: type,
      severity: severity,
      title: title,
      message: message,
      evidence: evidence,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      periodStart: periodStart.toUtc(),
      periodEnd: periodEnd.toUtc(),
    );
  }

  final String id;
  final InsightType type;
  final InsightSeverity severity;
  final String title;
  final String message;
  final InsightEvidence evidence;
  final String? actionLabel;
  final String? actionRoute;
  final DateTime createdAt;
  final DateTime periodStart;
  final DateTime periodEnd;

  FinancialInsight copyWith({String? title, String? message}) {
    return FinancialInsight(
      id: id,
      type: type,
      severity: severity,
      title: title ?? this.title,
      message: message ?? this.message,
      evidence: evidence,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      createdAt: createdAt,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
