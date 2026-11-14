import 'package:firebase_app_check/firebase_app_check.dart';

abstract interface class AppCheckTokenProbe {
  Future<bool> hasValidToken();
}

final class FirebaseAppCheckTokenProbe implements AppCheckTokenProbe {
  const FirebaseAppCheckTokenProbe();

  @override
  Future<bool> hasValidToken() async {
    final token = await FirebaseAppCheck.instance.getToken(true);
    return token?.trim().isNotEmpty == true;
  }
}
