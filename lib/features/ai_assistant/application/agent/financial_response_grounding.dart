import 'package:decimal/decimal.dart';

import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../domain/agent/ai_tool_contracts.dart';

enum FinancialFactDimension { amount, percent, count, date, scalar }

enum FinancialFactNature { actual, projected, illustrative }

final class FinancialFactProvenance {
  const FinancialFactProvenance({
    required this.toolName,
    required this.dataPath,
  });

  final String toolName;
  final String dataPath;
}

final class FinancialGroundedFact {
  const FinancialGroundedFact({
    required this.dimension,
    required this.provenance,
    required this.nature,
    this.decimalValue,
    this.dateValue,
    this.currency,
    this.period,
    this.periodRole,
    this.context = const <String, String>{},
  }) : assert(decimalValue != null || dateValue != null);

  final FinancialFactDimension dimension;
  final Decimal? decimalValue;
  final String? dateValue;
  final String? currency;
  final String? period;
  final String? periodRole;
  final Map<String, String> context;
  final FinancialFactNature nature;
  final FinancialFactProvenance provenance;
}

/// Typed, structured facts that are safe to use when checking provider text.
///
/// Only the bounded `AiToolResult.data` payload and its trusted period metadata
/// enter this registry. Display summaries and model-generated prose are never
/// promoted to facts.
final class FinancialFactRegistry {
  FinancialFactRegistry._(this.facts);

  factory FinancialFactRegistry.fromToolResults(List<AiToolResult> results) {
    final facts = <FinancialGroundedFact>[];
    for (final result in results) {
      final schema = _financialFactSchemas[result.toolName];
      if (schema == null) {
        continue;
      }
      final period = _canonicalDate(result.period);
      if (period != null) {
        facts.add(
          FinancialGroundedFact(
            dimension: FinancialFactDimension.date,
            dateValue: period,
            period: period,
            nature: FinancialFactNature.actual,
            provenance: FinancialFactProvenance(
              toolName: result.toolName,
              dataPath: r'$.period',
            ),
          ),
        );
      }
      _collectMapFacts(
        result.data,
        toolName: result.toolName,
        path: r'$.data',
        inheritedCurrency: null,
        period: period ?? result.period,
        inheritedPeriodRole: _declaredPeriodRole(result.data['period']),
        inheritedContext: const <String, String>{},
        schema: schema,
        output: facts,
      );
    }
    return FinancialFactRegistry._(
      List<FinancialGroundedFact>.unmodifiable(facts),
    );
  }

  final List<FinancialGroundedFact> facts;

  bool _supports(_FinancialClaim claim) {
    var candidates = facts
        .where((fact) {
          if (fact.dimension != claim.dimension) {
            return false;
          }
          if (claim.dimension == FinancialFactDimension.date) {
            return fact.dateValue == claim.dateValue;
          }
          return fact.decimalValue == claim.decimalValue;
        })
        .toList(growable: false);
    if (claim.period != null) {
      candidates = candidates
          .where(
            (fact) =>
                fact.periodRole == claim.period || fact.period == claim.period,
          )
          .toList(growable: false);
    }
    if (claim.category != null) {
      final claimedCategory = _normalizeContextLabel(claim.category!);
      candidates = candidates
          .where(
            (fact) =>
                _normalizeContextLabel(fact.context['category'] ?? '') ==
                claimedCategory,
          )
          .toList(growable: false);
    }
    if (claim.nature != null) {
      candidates = candidates
          .where((fact) => fact.nature == claim.nature)
          .toList(growable: false);
    }
    if (candidates.isEmpty) {
      return false;
    }
    if (claim.dimension != FinancialFactDimension.amount) {
      return true;
    }

    final claimedCurrency = claim.currency;
    if (claimedCurrency != null) {
      return candidates.any((fact) => fact.currency == claimedCurrency);
    }

    final currencies = candidates
        .map((fact) => fact.currency)
        .whereType<String>()
        .toSet();
    return currencies.length <= 1;
  }

  static void _collectMapFacts(
    Map<Object?, Object?> data, {
    required String toolName,
    required String path,
    required String? inheritedCurrency,
    required String? period,
    required String? inheritedPeriodRole,
    required Map<String, String> inheritedContext,
    required Map<String, FinancialFactDimension> schema,
    required List<FinancialGroundedFact> output,
  }) {
    final localCurrency = _currencyFrom(data) ?? inheritedCurrency;
    final context = <String, String>{
      ...inheritedContext,
      ..._contextFrom(data, toolName: toolName),
    };

    for (final entry in data.entries) {
      final key = entry.key?.toString() ?? '';
      if (key.isEmpty || _metadataFields.contains(_normalizeField(key))) {
        continue;
      }
      final value = entry.value;
      final valuePath = '$path.$key';
      if (value is Map) {
        _collectMapFacts(
          value.cast<Object?, Object?>(),
          toolName: toolName,
          path: valuePath,
          inheritedCurrency: localCurrency,
          period: period,
          inheritedPeriodRole: inheritedPeriodRole,
          inheritedContext: context,
          schema: schema,
          output: output,
        );
        continue;
      }
      if (value is List) {
        for (var index = 0; index < value.length; index++) {
          final item = value[index];
          if (item is Map) {
            _collectMapFacts(
              item.cast<Object?, Object?>(),
              toolName: toolName,
              path: '$valuePath[$index]',
              inheritedCurrency: localCurrency,
              period: period,
              inheritedPeriodRole: inheritedPeriodRole,
              inheritedContext: context,
              schema: schema,
              output: output,
            );
          } else {
            _collectValueFact(
              item,
              toolName: toolName,
              path: '$valuePath[$index]',
              currency: localCurrency,
              period: period,
              periodRole: _periodRoleFor(
                toolName,
                '$valuePath[$index]',
                inheritedPeriodRole,
              ),
              context: context,
              schema: schema,
              output: output,
            );
          }
        }
        continue;
      }

      _collectValueFact(
        value,
        toolName: toolName,
        path: valuePath,
        currency: localCurrency,
        period: period,
        periodRole: _periodRoleFor(toolName, valuePath, inheritedPeriodRole),
        context: context,
        schema: schema,
        output: output,
      );
    }
  }

  static void _collectValueFact(
    Object? value, {
    required String toolName,
    required String path,
    required String? currency,
    required String? period,
    required String? periodRole,
    required Map<String, String> context,
    required Map<String, FinancialFactDimension> schema,
    required List<FinancialGroundedFact> output,
  }) {
    final dimension = schema[_schemaPath(path)];
    if (dimension == null) {
      return;
    }
    final provenance = FinancialFactProvenance(
      toolName: toolName,
      dataPath: path,
    );
    final nature = _natureForFact(toolName, path);
    if (dimension == FinancialFactDimension.date) {
      final canonical = _canonicalDate(value?.toString());
      if (canonical != null) {
        output.add(
          FinancialGroundedFact(
            dimension: dimension,
            dateValue: canonical,
            currency: null,
            period: period,
            periodRole: periodRole,
            context: Map<String, String>.unmodifiable(context),
            nature: nature,
            provenance: provenance,
          ),
        );
      }
      return;
    }

    final decimal = _decimalFromStructuredValue(value);
    if (decimal == null) {
      return;
    }
    output.add(
      FinancialGroundedFact(
        dimension: dimension,
        decimalValue: decimal,
        currency: dimension == FinancialFactDimension.amount ? currency : null,
        period: period,
        periodRole: periodRole,
        context: Map<String, String>.unmodifiable(context),
        nature: nature,
        provenance: provenance,
      ),
    );
  }
}

/// Rejects provider prose containing a number that cannot be matched exactly
/// to a typed, structured fact from the current tool results.
final class FinancialResponseGroundingValidator {
  const FinancialResponseGroundingValidator();

  bool supports({required String text, required List<AiToolResult> results}) {
    if (results.isEmpty) {
      return false;
    }
    final extraction = _FinancialClaimExtractor.extract(text);
    if (!extraction.isLexicallyValid) {
      return false;
    }
    final registry = FinancialFactRegistry.fromToolResults(results);
    if (registry.facts.isEmpty) {
      return false;
    }
    return extraction.claims.every(registry._supports);
  }
}

final class _FinancialClaim {
  const _FinancialClaim.decimal({
    required this.dimension,
    required this.decimalValue,
    this.currency,
    this.period,
    this.category,
    this.nature,
  }) : dateValue = null;

  const _FinancialClaim.date(this.dateValue)
    : dimension = FinancialFactDimension.date,
      decimalValue = null,
      currency = null,
      period = null,
      category = null,
      nature = null;

  final FinancialFactDimension dimension;
  final Decimal? decimalValue;
  final String? dateValue;
  final String? currency;
  final String? period;
  final String? category;
  final FinancialFactNature? nature;
}

final class _FinancialClaimExtraction {
  const _FinancialClaimExtraction({
    required this.claims,
    required this.isLexicallyValid,
  });

  final List<_FinancialClaim> claims;
  final bool isLexicallyValid;
}

abstract final class _FinancialClaimExtractor {
  static final RegExp _exponentPattern = RegExp(
    r'[+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)[eE][+-]?\d+',
  );
  static final RegExp _datePattern = RegExp(
    r'\d{4}[-/]\d{1,2}(?:[-/]\d{1,2})?',
  );
  static final RegExp _numberPattern = RegExp(
    r'[+-]?(?:\d[\d.,]*\d|\d|[.,]\d+)',
  );

  static _FinancialClaimExtraction extract(String source) {
    final text = _normalizeNumericScript(source);
    if (_exponentPattern.hasMatch(text)) {
      return const _FinancialClaimExtraction(
        claims: <_FinancialClaim>[],
        isLexicallyValid: false,
      );
    }

    final claims = <_FinancialClaim>[];
    final dateSpans = <({int start, int end})>[];
    for (final match in _datePattern.allMatches(text)) {
      final canonical = _canonicalDate(match.group(0));
      if (canonical == null) {
        return const _FinancialClaimExtraction(
          claims: <_FinancialClaim>[],
          isLexicallyValid: false,
        );
      }
      claims.add(_FinancialClaim.date(canonical));
      dateSpans.add((start: match.start, end: match.end));
    }

    for (final match in _numberPattern.allMatches(text)) {
      if (dateSpans.any(
        (span) => match.start < span.end && match.end > span.start,
      )) {
        continue;
      }
      var lexeme = match.group(0)!;
      if (lexeme.startsWith('-') &&
          match.start > 0 &&
          _isAsciiDigit(text.codeUnitAt(match.start - 1))) {
        lexeme = lexeme.substring(1);
      }
      final decimal = _parseLocalizedDecimal(lexeme);
      if (decimal == null) {
        return const _FinancialClaimExtraction(
          claims: <_FinancialClaim>[],
          isLexicallyValid: false,
        );
      }
      final contextStart = match.start > 64 ? match.start - 64 : 0;
      final contextEnd = match.end + 64 < text.length
          ? match.end + 64
          : text.length;
      final before = text.substring(contextStart, match.start).toLowerCase();
      final after = text.substring(match.end, contextEnd).toLowerCase();
      final dimension = _dimensionFromContext(before, after);
      if (dimension == null || dimension == FinancialFactDimension.date) {
        return const _FinancialClaimExtraction(
          claims: <_FinancialClaim>[],
          isLexicallyValid: false,
        );
      }
      claims.add(
        _FinancialClaim.decimal(
          dimension: dimension,
          decimalValue: decimal,
          currency: dimension == FinancialFactDimension.amount
              ? _nearestCurrency(before, after)?.code
              : null,
          period: _periodFromContext(before, after),
          category: dimension == FinancialFactDimension.amount
              ? _categoryFromClaim(text, match.start)
              : null,
          nature: _natureFromContext(before, after),
        ),
      );
    }
    return _FinancialClaimExtraction(
      claims: List<_FinancialClaim>.unmodifiable(claims),
      isLexicallyValid: true,
    );
  }
}

FinancialFactDimension? _dimensionFromContext(String before, String after) {
  final scores = <({FinancialFactDimension dimension, int distance})>[
    if (_nearestCueDistance(before, after, _percentCues) case final distance?)
      (dimension: FinancialFactDimension.percent, distance: distance),
    if (_nearestCueDistance(before, after, _dateCues) case final distance?)
      (dimension: FinancialFactDimension.date, distance: distance),
    if (_nearestCueDistance(before, after, _countCues) case final distance?)
      (dimension: FinancialFactDimension.count, distance: distance),
    if (_nearestCueDistance(before, after, _scalarCues) case final distance?)
      (dimension: FinancialFactDimension.scalar, distance: distance),
    if (_nearestCueDistance(before, after, _amountCues) case final distance?)
      (dimension: FinancialFactDimension.amount, distance: distance),
    if (_nearestCurrency(before, after) case final currency?)
      (dimension: FinancialFactDimension.amount, distance: currency.distance),
  ]..sort((left, right) => left.distance.compareTo(right.distance));
  if (scores.isEmpty) {
    return null;
  }
  return scores.first.dimension;
}

Decimal? _decimalFromStructuredValue(Object? value) {
  if (value is int || value is String) {
    return _parseLocalizedDecimal(value.toString());
  }
  return null;
}

Decimal? _parseLocalizedDecimal(String source) {
  var value = _normalizeNumericScript(source).trim();
  if (value.isEmpty || value.contains(RegExp('[eE]'))) {
    return null;
  }
  final sign = value.startsWith('-') || value.startsWith('+') ? value[0] : '';
  if (sign.isNotEmpty) {
    value = value.substring(1);
  }
  if (value.isEmpty || !RegExp(r'^\d[\d.,]*$').hasMatch(value)) {
    return null;
  }

  final commaCount = ','.allMatches(value).length;
  final dotCount = '.'.allMatches(value).length;
  String canonical;
  if (commaCount > 0 && dotCount > 0) {
    final decimalSeparator = value.lastIndexOf(',') > value.lastIndexOf('.')
        ? ','
        : '.';
    final groupingSeparator = decimalSeparator == ',' ? '.' : ',';
    if (!_validMixedSeparators(value, decimalSeparator, groupingSeparator)) {
      return null;
    }
    canonical = value
        .replaceAll(groupingSeparator, '')
        .replaceFirst(decimalSeparator, '.');
  } else if (commaCount > 0) {
    canonical = _singleSeparatorCanonical(value, ',') ?? '';
  } else if (dotCount > 1) {
    canonical = _allGroupsHaveThreeDigits(value, '.')
        ? value.replaceAll('.', '')
        : '';
  } else {
    canonical = value;
  }
  if (canonical.isEmpty || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(canonical)) {
    return null;
  }
  return Decimal.tryParse('$sign$canonical');
}

String? _singleSeparatorCanonical(String value, String separator) {
  final groups = value.split(separator);
  if (groups.any((group) => group.isEmpty)) {
    return null;
  }
  if (groups.length > 2) {
    return _allGroupsHaveThreeDigits(value, separator) ? groups.join() : null;
  }
  return groups[1].length == 3 && groups[0].length <= 3
      ? groups.join()
      : '${groups[0]}.${groups[1]}';
}

bool _validMixedSeparators(
  String value,
  String decimalSeparator,
  String groupingSeparator,
) {
  if (decimalSeparator.allMatches(value).length != 1) {
    return false;
  }
  final parts = value.split(decimalSeparator);
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
    return false;
  }
  if (parts[1].contains(groupingSeparator)) {
    return false;
  }
  return _allGroupsHaveThreeDigits(parts[0], groupingSeparator);
}

bool _allGroupsHaveThreeDigits(String value, String separator) {
  final groups = value.split(separator);
  if (groups.isEmpty || groups.first.isEmpty || groups.first.length > 3) {
    return false;
  }
  return groups.skip(1).every((group) => group.length == 3);
}

String _normalizeNumericScript(String value) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  final output = StringBuffer();
  for (final codePoint in value.runes) {
    final character = String.fromCharCode(codePoint);
    final arabicIndex = arabicDigits.indexOf(character);
    if (arabicIndex >= 0) {
      output.write(arabicIndex);
      continue;
    }
    final persianIndex = persianDigits.indexOf(character);
    if (persianIndex >= 0) {
      output.write(persianIndex);
      continue;
    }
    output.write(switch (character) {
      '٫' => '.',
      '٬' => ',',
      '−' => '-',
      _ => character,
    });
  }
  return output.toString();
}

String? _canonicalDate(String? source) {
  final value = _normalizeNumericScript(source ?? '').trim();
  final match = RegExp(
    r'^(\d{4})[-/](\d{1,2})(?:[-/](\d{1,2}))?(?:[T ].*)?$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final dayText = match.group(3);
  if (month < 1 || month > 12) {
    return null;
  }
  if (dayText == null) {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  }
  final day = int.parse(dayText);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

String? _currencyFrom(Map<Object?, Object?> data) {
  for (final key in const <String>[
    'currency',
    'currencyCode',
    'toCurrency',
    'targetCurrency',
    'to',
  ]) {
    final raw = data[key]?.toString().trim().toUpperCase();
    if (raw != null && CurrencyCatalog.supportedCodes.contains(raw)) {
      return raw;
    }
  }
  return null;
}

({String code, int distance})? _nearestCurrency(String before, String after) {
  ({String code, int distance})? nearest;
  for (final code in CurrencyCatalog.supportedCodes) {
    final boundedCode = RegExp('[^A-Z]${RegExp.escape(code)}[^A-Z]');
    final paddedBefore = ' ${before.toUpperCase()} ';
    for (final match in boundedCode.allMatches(paddedBefore)) {
      final distance = paddedBefore.length - match.end - 1;
      if (nearest == null || distance < nearest.distance) {
        nearest = (code: code, distance: distance);
      }
    }
    final paddedAfter = ' ${after.toUpperCase()} ';
    for (final match in boundedCode.allMatches(paddedAfter)) {
      final distance = match.start == 0 ? 0 : match.start - 1;
      if (nearest == null || distance < nearest.distance) {
        nearest = (code: code, distance: distance);
      }
    }
  }
  for (final entry in _currencyTokens.entries) {
    final beforeIndex = before.lastIndexOf(entry.key);
    if (beforeIndex >= 0) {
      final distance = before.length - beforeIndex - entry.key.length;
      if (nearest == null || distance < nearest.distance) {
        nearest = (code: entry.value, distance: distance);
      }
    }
    final afterIndex = after.indexOf(entry.key);
    if (afterIndex >= 0 && (nearest == null || afterIndex < nearest.distance)) {
      nearest = (code: entry.value, distance: afterIndex);
    }
  }
  return nearest;
}

Map<String, String> _contextFrom(
  Map<Object?, Object?> data, {
  required String toolName,
}) {
  final context = <String, String>{};
  for (final entry in _contextFields.entries) {
    final value = data[entry.key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      context[entry.value] = value;
    }
  }
  final name = data['name']?.toString().trim();
  if (name != null && name.isNotEmpty) {
    if (toolName == 'get_budget_progress') {
      context['budget'] = name;
    } else if (toolName == 'get_accounts_summary') {
      context['account'] = name;
    }
  }
  if (toolName == 'get_goal_progress') {
    final title = data['title']?.toString().trim();
    if (title != null && title.isNotEmpty) {
      context['goal'] = title;
    }
  }
  return context;
}

String _schemaPath(String path) => path.replaceAll(RegExp(r'\[\d+\]'), '[]');

String? _declaredPeriodRole(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  return switch (normalized) {
    'current_month' || 'previous_month' || 'year' => normalized,
    _ => null,
  };
}

String? _periodRoleFor(String toolName, String path, String? declaredRole) {
  final schemaPath = _schemaPath(path);
  return switch ((toolName, schemaPath)) {
    ('get_dashboard_summary', _) => 'current_month',
    ('get_monthly_comparison', r'$.data.currentExpense') => 'current_month',
    ('get_monthly_comparison', r'$.data.previousExpense') => 'previous_month',
    ('get_monthly_comparison', r'$.data.expenseChangePercent') =>
      'current_month',
    ('get_category_spending', _) ||
    ('get_top_spending_categories', _) => declaredRole ?? 'current_month',
    ('get_cash_flow_trend', r'$.data.currentNet') => 'current_month',
    ('get_cash_flow_trend', r'$.data.previousNet') => 'previous_month',
    ('get_income_expense_breakdown', _) => declaredRole,
    _ => declaredRole,
  };
}

String? _periodFromContext(String before, String after) {
  ({String role, int distance})? nearest;
  for (final entry in _periodCues.entries) {
    final distance = _nearestCueDistance(before, after, entry.value);
    if (distance != null && (nearest == null || distance < nearest.distance)) {
      nearest = (role: entry.key, distance: distance);
    }
  }
  return nearest?.role;
}

FinancialFactNature? _natureFromContext(String before, String after) {
  final projected = _nearestCueDistance(before, after, _projectedCues);
  final illustrative = _nearestCueDistance(before, after, _illustrativeCues);
  if (projected == null && illustrative == null) {
    return null;
  }
  return illustrative != null && (projected == null || illustrative < projected)
      ? FinancialFactNature.illustrative
      : FinancialFactNature.projected;
}

String? _categoryFromClaim(String text, int numberStart) {
  final lineStart = text.lastIndexOf('\n', numberStart - 1) + 1;
  final lineBeforeNumber = text.substring(lineStart, numberStart);
  final match = RegExp(
    r'(?:^|\|)\s*([^|:\n]{1,80})\s*:\s*(?:[*_`]+\s*)?$',
  ).firstMatch(lineBeforeNumber);
  if (match == null) {
    return null;
  }
  var label = match
      .group(1)!
      .replaceAll(RegExp(r'^[#*_`\s]+|[#*_`\s]+$'), '')
      .trim();
  label = label.replaceFirst(
    RegExp(r'^(?:category|spending for|الفئة)\s+', caseSensitive: false),
    '',
  );
  final normalized = _normalizeContextLabel(label);
  if (normalized.isEmpty || _nonCategoryLabels.contains(normalized)) {
    return null;
  }
  return label;
}

String _normalizeContextLabel(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'^[#*_`\s]+|[#*_`\s.,;:]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int? _nearestCueDistance(String before, String after, Set<String> cues) {
  int? nearest;
  for (final cue in cues) {
    final beforeIndex = before.lastIndexOf(cue);
    if (beforeIndex >= 0) {
      final distance = before.length - beforeIndex - cue.length;
      if (nearest == null || distance < nearest) {
        nearest = distance;
      }
    }
    final afterIndex = after.indexOf(cue);
    if (afterIndex >= 0 && (nearest == null || afterIndex < nearest)) {
      nearest = afterIndex;
    }
  }
  return nearest;
}

FinancialFactNature _natureForFact(String toolName, String path) {
  final normalized = '$toolName.$path'.toLowerCase();
  if (normalized.contains('illustrative') || normalized.contains('example')) {
    return FinancialFactNature.illustrative;
  }
  if (normalized.contains('projected') ||
      normalized.contains('projection') ||
      normalized.contains('forecast') ||
      normalized.contains('simulate')) {
    return FinancialFactNature.projected;
  }
  return FinancialFactNature.actual;
}

String _normalizeField(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

const Set<String> _metadataFields = <String>{
  'currency',
  'currencycode',
  'fromcurrency',
  'tocurrency',
  'targetcurrency',
  'category',
  'categoryname',
  'account',
  'accountname',
  'budget',
  'budgetname',
  'goal',
  'goalname',
  'title',
  'name',
};

const Map<String, Map<String, FinancialFactDimension>> _financialFactSchemas =
    <String, Map<String, FinancialFactDimension>>{
      'get_dashboard_summary': <String, FinancialFactDimension>{
        r'$.data.monthlyIncome': FinancialFactDimension.amount,
        r'$.data.monthlyExpense': FinancialFactDimension.amount,
        r'$.data.monthlySavings': FinancialFactDimension.amount,
        r'$.data.netWorth': FinancialFactDimension.amount,
        r'$.data.accountCount': FinancialFactDimension.count,
      },
      'get_monthly_comparison': <String, FinancialFactDimension>{
        r'$.data.currentExpense': FinancialFactDimension.amount,
        r'$.data.previousExpense': FinancialFactDimension.amount,
        r'$.data.expenseChangePercent': FinancialFactDimension.percent,
      },
      'get_category_spending': <String, FinancialFactDimension>{
        r'$.data.categories[].amount': FinancialFactDimension.amount,
      },
      'get_top_spending_categories': <String, FinancialFactDimension>{
        r'$.data.categories[].amount': FinancialFactDimension.amount,
      },
      'get_budget_summary': <String, FinancialFactDimension>{
        r'$.data.activeCount': FinancialFactDimension.count,
        r'$.data.warningCount': FinancialFactDimension.count,
        r'$.data.exceededCount': FinancialFactDimension.count,
      },
      'get_budget_progress': <String, FinancialFactDimension>{
        r'$.data.budgets[].spent': FinancialFactDimension.amount,
        r'$.data.budgets[].limit': FinancialFactDimension.amount,
        r'$.data.budgets[].remaining': FinancialFactDimension.amount,
        r'$.data.budgets[].progressPercent': FinancialFactDimension.percent,
      },
      'get_goal_summary': <String, FinancialFactDimension>{
        r'$.data.activeCount': FinancialFactDimension.count,
        r'$.data.completedCount': FinancialFactDimension.count,
        r'$.data.savedTotals[].amount': FinancialFactDimension.amount,
        r'$.data.nearestTargetDate': FinancialFactDimension.date,
      },
      'get_goal_progress': <String, FinancialFactDimension>{
        r'$.data.goals[].current': FinancialFactDimension.amount,
        r'$.data.goals[].target': FinancialFactDimension.amount,
        r'$.data.goals[].remaining': FinancialFactDimension.amount,
        r'$.data.goals[].progressPercent': FinancialFactDimension.percent,
        r'$.data.goals[].daysRemaining': FinancialFactDimension.count,
        r'$.data.goals[].monthlyNeeded': FinancialFactDimension.amount,
      },
      'get_cash_flow_trend': <String, FinancialFactDimension>{
        r'$.data.currentNet': FinancialFactDimension.amount,
        r'$.data.previousNet': FinancialFactDimension.amount,
        r'$.data.sixMonthExpenseTrend[]': FinancialFactDimension.amount,
      },
      'get_recurring_transactions': <String, FinancialFactDimension>{
        r'$.data.detectedPatternCount': FinancialFactDimension.count,
        r'$.data.periodStart': FinancialFactDimension.date,
        r'$.data.periodEnd': FinancialFactDimension.date,
      },
      'get_income_expense_breakdown': <String, FinancialFactDimension>{
        r'$.data.income': FinancialFactDimension.amount,
        r'$.data.expense': FinancialFactDimension.amount,
      },
      'get_net_worth': <String, FinancialFactDimension>{
        r'$.data.amount': FinancialFactDimension.amount,
      },
      'get_accounts_summary': <String, FinancialFactDimension>{
        r'$.data.accounts[].balance': FinancialFactDimension.amount,
      },
      'get_exchange_rate': <String, FinancialFactDimension>{
        r'$.data.rate': FinancialFactDimension.scalar,
        r'$.data.asOf': FinancialFactDimension.date,
      },
      'search_transactions': <String, FinancialFactDimension>{
        r'$.data.transactions[].date': FinancialFactDimension.date,
        r'$.data.transactions[].amount': FinancialFactDimension.amount,
        r'$.data.resultCount': FinancialFactDimension.count,
      },
      'calculate_savings_rate': <String, FinancialFactDimension>{
        r'$.data.savings': FinancialFactDimension.amount,
        r'$.data.savingsRatePercent': FinancialFactDimension.percent,
      },
      'project_month_end': <String, FinancialFactDimension>{
        r'$.data.projectedAmount': FinancialFactDimension.amount,
      },
      'simulate_budget_change': <String, FinancialFactDimension>{
        r'$.data.remaining': FinancialFactDimension.amount,
      },
      'calculate_goal_feasibility': <String, FinancialFactDimension>{
        r'$.data.monthsNeeded': FinancialFactDimension.count,
      },
      'forecast_goal_completion': <String, FinancialFactDimension>{
        r'$.data.monthsNeeded': FinancialFactDimension.count,
      },
      'calculate_safe_allowance': <String, FinancialFactDimension>{
        r'$.data.safeAllowance': FinancialFactDimension.amount,
      },
      'simulate_income_change': <String, FinancialFactDimension>{
        r'$.data.projectedCashFlow': FinancialFactDimension.amount,
      },
      'compare_scenarios': <String, FinancialFactDimension>{
        r'$.data.difference': FinancialFactDimension.amount,
      },
      'convert_currency_amount': <String, FinancialFactDimension>{
        r'$.data.amount': FinancialFactDimension.amount,
      },
    };

const Map<String, String> _contextFields = <String, String>{
  'category': 'category',
  'categoryName': 'category',
  'account': 'account',
  'accountName': 'account',
  'budget': 'budget',
  'budgetName': 'budget',
  'goal': 'goal',
  'goalName': 'goal',
  'title': 'title',
};

const Map<String, Set<String>> _periodCues = <String, Set<String>>{
  'current_month': <String>{
    'this month',
    'current month',
    'current-month',
    'هذا الشهر',
    'الشهر الحالي',
  },
  'previous_month': <String>{
    'last month',
    'previous month',
    'previous-month',
    'الشهر الماضي',
    'الشهر السابق',
  },
  'year': <String>{
    'this year',
    'year to date',
    'year-to-date',
    'هذه السنة',
    'هذا العام',
  },
};

const Set<String> _projectedCues = <String>{
  'projected',
  'projection',
  'forecast',
  'estimated',
  'متوقع',
  'تقديري',
};

const Set<String> _illustrativeCues = <String>{
  'illustrative',
  'example',
  'hypothetical',
  'مثال',
  'افتراضي',
};

const Set<String> _nonCategoryLabels = <String>{
  'amount',
  'income',
  'expense',
  'expenses',
  'spending',
  'savings',
  'balance',
  'net worth',
  'cash flow',
  'budget',
  'target',
  'remaining',
  'progress',
  'rate',
  'date',
  'count',
  'دخل',
  'مصروف',
  'إنفاق',
  'ادخار',
  'رصيد',
  'مبلغ',
};

const Set<String> _percentCues = <String>{
  '%',
  '٪',
  'percent',
  'percentage',
  'بالمئة',
  'بالمائة',
  'في المئة',
};

const Set<String> _dateCues = <String>{
  'date',
  'as of',
  'as-of',
  'dated',
  'تاريخ',
};

const Set<String> _countCues = <String>{
  ' count',
  'active budget',
  'budgets',
  'goals',
  'accounts',
  'transactions',
  'days',
  'months',
  'عدد',
  'ميزانيات',
  'أهداف',
  'حسابات',
  'معاملات',
  'أيام',
  'أشهر',
};

const Set<String> _scalarCues = <String>{
  'exchange rate',
  ' rate',
  'ratio',
  'سعر الصرف',
  'معدل',
};

const Set<String> _amountCues = <String>{
  'amount',
  'income',
  'expense',
  'spending',
  'spent',
  'saving',
  'balance',
  'cash flow',
  'net worth',
  'budget limit',
  'remaining',
  'target',
  'دخل',
  'مصروف',
  'إنفاق',
  'ادخار',
  'رصيد',
  'مبلغ',
  'تدفق نقدي',
};

const Map<String, String> _currencyTokens = <String, String>{
  r'$': 'USD',
  '€': 'EUR',
  '£': 'GBP',
  'د.ل': 'LYD',
  'دينار': 'LYD',
  'دولار': 'USD',
  'يورو': 'EUR',
};
