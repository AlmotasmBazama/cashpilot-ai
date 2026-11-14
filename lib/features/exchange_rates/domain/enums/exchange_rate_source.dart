enum ExchangeRateSource { manual, cached, remote, system }

extension ExchangeRateSourceX on ExchangeRateSource {
  String get storageValue => name;
}

abstract final class ExchangeRateSourceMapper {
  static ExchangeRateSource fromStorage(String value) {
    return ExchangeRateSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => ExchangeRateSource.manual,
    );
  }
}
