import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/payees/data/datasources/local/payees_local_data_source.dart';
import 'package:cashpilot_ai/features/payees/data/repositories/payees_repository_impl.dart';
import 'package:cashpilot_ai/features/payees/payees.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late PayeesRepository repository;
  late String categoryId;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    final categories = await DriftCategoriesLocalDataSource(
      session,
    ).getCategories();
    categoryId = categories.first.id;
    await _seedAccount(database, 'cash', session.ownerScopeValue);
    repository = PayeesRepositoryImpl(
      localDataSource: DriftPayeesLocalDataSource(session),
      resolver: const PayeeResolver(),
      logger: AppLogger.instance,
    );
  });

  tearDown(() => database.close());

  test('creates and reloads a valid dedicated payee', () async {
    final created = (await repository.createPayee(
      Payee.create(
        name: '  Al Nawar Market  ',
        type: PayeeType.merchant,
        aliases: const <String>['النوار', 'Al Nawar'],
        defaultCategoryId: categoryId,
        defaultAccountId: 'cash',
        notes: 'Groceries merchant',
      ),
    )).expectSuccess();

    expect(created.name, 'Al Nawar Market');
    expect(created.normalizedName, 'al nawar market');
    expect(created.aliases, <String>['النوار', 'Al Nawar']);
    final reloaded = (await repository.getPayeeById(
      created.id,
    )).expectSuccess();
    expect(reloaded?.id, created.id);
    expect(reloaded?.name, created.name);
    expect(reloaded?.aliases, created.aliases);
  });

  test('watchPayees emits repository changes', () async {
    final emissionsFuture = repository.watchPayees().take(2).toList();
    await Future<void>.delayed(Duration.zero);

    final created = (await repository.createPayee(
      Payee.create(name: 'Watched Merchant'),
    )).expectSuccess();
    final emissions = await emissionsFuture;

    expect(emissions, hasLength(2));
    expect(emissions.first.expectSuccess(), isEmpty);
    expect(emissions.last.expectSuccess().single.id, created.id);
  });

  test('searches payees by compact alias', () async {
    final created = (await repository.createPayee(
      Payee.create(name: 'Payment Service', aliases: const <String>['Ed Faly']),
    )).expectSuccess();

    final matches = (await repository.searchPayees('edfaly')).expectSuccess();

    expect(matches.map((payee) => payee.id), contains(created.id));
  });

  test('updates and renormalizes a payee', () async {
    final created = (await repository.createPayee(
      Payee.create(name: 'Old Merchant'),
    )).expectSuccess();

    final updated = (await repository.updatePayee(
      created.copyWith(name: '  New Merchant  ', notes: 'Updated'),
    )).expectSuccess();

    expect(updated.name, 'New Merchant');
    expect(updated.normalizedName, 'new merchant');
    expect(updated.notes, 'Updated');
  });

  test('rejects an empty payee name', () {
    expect(
      () => Payee.create(name: '   '),
      throwsA(
        isA<PayeeValidationException>().having(
          (error) => error.code,
          'code',
          PayeeFailureCodes.emptyName,
        ),
      ),
    );
  });

  test('rejects duplicate normalized names', () async {
    await repository.createPayee(Payee.create(name: 'Al Nawar'));
    final result = await repository.createPayee(
      Payee.create(name: '  AL   NAWAR '),
    );

    expect(result, isA<AppFailure<Payee>>());
    expect(
      (result as AppFailure<Payee>).failure.code,
      PayeeFailureCodes.duplicateName,
    );
  });

  test('rejects duplicate aliases across payees', () async {
    await repository.createPayee(
      Payee.create(name: 'Merchant One', aliases: const ['Edfaly']),
    );
    final result = await repository.createPayee(
      Payee.create(name: 'Merchant Two', aliases: const ['Ed Faly']),
    );

    expect(result, isA<AppFailure<Payee>>());
    expect(
      (result as AppFailure<Payee>).failure.code,
      PayeeFailureCodes.duplicateAlias,
    );
  });

  test('archives and restores a payee without deleting it', () async {
    final payee = (await repository.createPayee(
      Payee.create(name: 'Salem'),
    )).expectSuccess();
    final archived = (await repository.archivePayee(payee.id)).expectSuccess();

    expect(archived.isArchived, isTrue);
    expect(
      (await repository.getPayeeById(payee.id)).expectSuccess(),
      isNotNull,
    );
    expect(
      (await repository.restorePayee(payee.id)).expectSuccess().isArchived,
      isFalse,
    );
  });

  test('updates lastUsedAt through the payee repository', () async {
    final payee = (await repository.createPayee(
      Payee.create(name: 'Frequently Used'),
    )).expectSuccess();
    final usedAt = DateTime.utc(2026, 7, 12);

    final updated = (await repository.touchLastUsed(
      payee.id,
      usedAt,
    )).expectSuccess();

    expect(updated.lastUsedAt, usedAt);
  });

  test('lastUsedAt never moves backwards', () async {
    final payee = (await repository.createPayee(
      Payee.create(name: 'Monotonic Usage'),
    )).expectSuccess();
    final latest = DateTime.utc(2026, 7, 12);
    await repository.touchLastUsed(payee.id, latest);

    final unchanged = (await repository.touchLastUsed(
      payee.id,
      DateTime.utc(2026, 6, 1),
    )).expectSuccess();

    expect(unchanged.lastUsedAt, latest);
  });

  test('resolves exact names and compact aliases', () {
    final payee = Payee.create(
      name: 'Edfaly Service',
      aliases: const <String>['Edfaly', 'ادفع لي'],
    );
    const resolver = PayeeResolver();

    expect(resolver.resolve('Edfaly Service', [payee]), isA<PayeeResolved>());
    expect(resolver.resolve('Ed Faly', [payee]), isA<PayeeResolved>());
    expect(resolver.resolve('ادفعلي', [payee]), isA<PayeeResolved>());
  });

  test('resolves Arabic normalized variants', () {
    final payee = Payee.create(
      name: 'الأَنْوار',
      aliases: const ['الأنوار ماركت'],
    );
    const resolver = PayeeResolver();

    expect(resolver.resolve('الانوار', [payee]), isA<PayeeResolved>());
    expect(resolver.resolve('الانوار ماركت', [payee]), isA<PayeeResolved>());
    expect(resolver.resolve('الانوار،', [payee]), isA<PayeeResolved>());
  });

  test('returns ambiguous when more than one payee matches', () {
    final first = Payee.create(name: 'Salem One', aliases: const ['Salem']);
    final second = Payee.create(name: 'Salem Two', aliases: const ['Salem']);
    final result = const PayeeResolver().resolve('salem', [first, second]);

    expect(result, isA<PayeeAmbiguous>());
    expect((result as PayeeAmbiguous).matches, hasLength(2));
  });

  test('resolveFromText prefers the strongest longest payee match', () {
    final short = Payee.create(name: 'Salem');
    final full = Payee.create(name: 'Salem Mohammed');

    final result = const PayeeResolver().resolveFromText(
      'I paid Salem Mohammed 50',
      <Payee>[short, full],
    );

    expect(result, isA<PayeeResolved>());
    expect((result as PayeeResolved).payee.id, full.id);
  });

  test('archived payees are excluded from normal resolution', () {
    final payee = Payee.create(
      name: 'Old Merchant',
      archivedAt: DateTime.utc(2026, 1, 1),
    );
    const resolver = PayeeResolver();

    expect(resolver.resolve('Old Merchant', [payee]), isA<PayeeNotFound>());
    expect(
      resolver.resolve('Old Merchant', [payee], includeArchived: true),
      isA<PayeeResolved>(),
    );
  });

  test(
    'legacy compact payee insert receives migration-safe defaults',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.payees)
          .insert(
            PayeesCompanion.insert(
              id: 'legacy',
              name: 'Legacy Payee',
              normalizedName: 'legacy payee',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (database.select(
        database.payees,
      )..where((item) => item.id.equals('legacy'))).getSingle();
      expect(row.type, 'other');
      expect(row.aliases, '[]');
      expect(row.archivedAt, isNull);
    },
  );
}

Future<void> _seedAccount(AppDatabase database, String id, String scope) {
  final now = DateTime.utc(2026, 1, 1);
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          ownerScopeId: Value(scope),
          name: 'Cash',
          type: 'cash',
          currencyCode: 'LYD',
          balance: '1000',
          icon: 'wallet',
          color: 0xFF006C67,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

extension AppResultTestX<T> on AppResult<T> {
  T expectSuccess() => switch (this) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(failure.message),
  };
}
