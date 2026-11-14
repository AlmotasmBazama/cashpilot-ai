import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../entities/payee_resolution.dart';
import '../enums/payee_type.dart';

abstract interface class PayeesRepository {
  Stream<AppResult<List<Payee>>> watchPayees({
    bool includeArchived = false,
    PayeeType? type,
  });

  Future<AppResult<Payee?>> getPayeeById(String id);

  Future<AppResult<List<Payee>>> searchPayees(
    String query, {
    bool includeArchived = false,
  });

  Future<AppResult<Payee>> createPayee(Payee payee);

  Future<AppResult<Payee>> updatePayee(Payee payee);

  Future<AppResult<Payee>> archivePayee(String id);

  Future<AppResult<Payee>> restorePayee(String id);

  Future<AppResult<PayeeResolution>> resolvePayee(
    String query, {
    bool includeArchived = false,
  });

  Future<AppResult<Payee>> touchLastUsed(String id, DateTime usedAt);
}
