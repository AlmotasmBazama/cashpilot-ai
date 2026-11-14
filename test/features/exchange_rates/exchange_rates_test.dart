import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/exchange_rates/data/datasources/local/exchange_rates_local_data_source.dart';
import 'package:cashpilot_ai/features/exchange_rates/data/repositories/exchange_rate_repository_impl.dart';
import 'package:cashpilot_ai/features/exchange_rates/exchange_rates.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late ExchangeRateRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = ExchangeRateRepositoryImpl(
      localDataSource: DriftExchangeRatesLocalDataSource(
        scopedTestSession(database),
      ),
      logger: AppLogger.instance,
    );
  });

  tearDown(() => database.close());

  test('rejects zero, negative, same-currency, and unsupported rates', () {
    expect(
      () => _rate(rate: Decimal.zero),
      throwsA(_validationCode(ExchangeRateFailureCodes.invalidRate)),
    );
    expect(
      () => _rate(rate: Decimal.parse('-1')),
      throwsA(_validationCode(ExchangeRateFailureCodes.invalidRate)),
    );
    expect(
      () => _rate(quote: 'USD'),
      throwsA(_validationCode(ExchangeRateFailureCodes.sameCurrency)),
    );
    expect(
      () => _rate(quote: 'XYZ'),
      throwsA(_validationCode(ExchangeRateFailureCodes.invalidCurrency)),
    );
  });

  test('same-currency conversion returns the original amount', () async {
    final original = Money(
      amount: Decimal.parse('12.345'),
      currencyCode: 'LYD',
    );

    final converted = (await repository.convert(
      original,
      'LYD',
    )).expectSuccess();

    expect(converted, original);
  });

  test('direct and reverse conversions use Decimal rates', () async {
    await repository.upsertRate(_rate(rate: Decimal.parse('7.5')));

    final direct = (await repository.convert(
      Money(amount: Decimal.parse('100'), currencyCode: 'USD'),
      'LYD',
    )).expectSuccess();
    final reverse = (await repository.convert(
      Money(amount: Decimal.parse('750'), currencyCode: 'LYD'),
      'USD',
    )).expectSuccess();

    expect(direct.amount, Decimal.parse('750'));
    expect(reverse.amount, Decimal.parse('100'));
    expect(direct.currencyCode, 'LYD');
    expect(reverse.currencyCode, 'USD');
  });

  test('missing conversion rate returns a coded failure', () async {
    final result = await repository.convert(
      Money(amount: Decimal.one, currencyCode: 'USD'),
      'LYD',
    );

    expect(result, isA<AppFailure<Money>>());
    expect(
      (result as AppFailure<Money>).failure.code,
      ExchangeRateFailureCodes.missingRate,
    );
  });

  test('upsert updates the active pair instead of duplicating it', () async {
    final first = (await repository.upsertRate(
      _rate(rate: Decimal.parse('7.4')),
    )).expectSuccess();
    final updated = (await repository.upsertRate(
      _rate(rate: Decimal.parse('7.6')),
    )).expectSuccess();

    expect(updated.id, first.id);
    expect(updated.rate, Decimal.parse('7.6'));
    final rows = await database.select(database.exchangeRates).get();
    expect(rows, hasLength(1));
  });

  test(
    'watch emits changes and archive removes a rate from resolution',
    () async {
      final emissionsFuture = repository.watchRates().take(2).toList();
      await Future<void>.delayed(Duration.zero);
      final created = (await repository.upsertRate(
        _rate(rate: Decimal.parse('7.5')),
      )).expectSuccess();
      final emissions = await emissionsFuture;

      expect(emissions.first.expectSuccess(), isEmpty);
      expect(emissions.last.expectSuccess().single.id, created.id);

      final archived = (await repository.archiveRate(
        created.id,
      )).expectSuccess();
      final resolved = (await repository.getLatestRate(
        'USD',
        'LYD',
      )).expectSuccess();
      expect(archived.isArchived, isTrue);
      expect(resolved, isNull);
    },
  );

  test('latest rate resolves direct and reciprocal directions', () async {
    await repository.upsertRate(_rate(rate: Decimal.parse('7.5')));

    final direct = (await repository.getLatestRate(
      'USD',
      'LYD',
    )).expectSuccess();
    final reverse = (await repository.getLatestRate(
      'LYD',
      'USD',
    )).expectSuccess();

    expect(direct?.rate, Decimal.parse('7.5'));
    expect(reverse?.rate, Decimal.parse('0.133333333333'));
    expect(reverse?.fromCurrencyCode, 'LYD');
    expect(reverse?.toCurrencyCode, 'USD');
  });
}

StoredExchangeRate _rate({
  String base = 'USD',
  String quote = 'LYD',
  Decimal? rate,
}) {
  return StoredExchangeRate.create(
    baseCurrency: base,
    quoteCurrency: quote,
    rate: rate ?? Decimal.parse('7.5'),
    fetchedAt: DateTime.utc(2026, 7, 14),
  );
}

Matcher _validationCode(String code) {
  return isA<ExchangeRateValidationException>().having(
    (error) => error.code,
    'code',
    code,
  );
}

extension AppResultTestX<T> on AppResult<T> {
  T expectSuccess() => switch (this) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(failure.message),
  };
}
