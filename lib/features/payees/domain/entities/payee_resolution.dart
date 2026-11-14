import 'payee.dart';

sealed class PayeeResolution {
  const PayeeResolution();
}

class PayeeResolved extends PayeeResolution {
  const PayeeResolved({required this.payee, required this.matchedText});

  final Payee payee;
  final String matchedText;
}

class PayeeAmbiguous extends PayeeResolution {
  const PayeeAmbiguous({required this.query, required this.matches});

  final String query;
  final List<Payee> matches;
}

class PayeeNotFound extends PayeeResolution {
  const PayeeNotFound({required this.query});

  final String query;
}
