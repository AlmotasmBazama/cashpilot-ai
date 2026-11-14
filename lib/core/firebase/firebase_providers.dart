import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_app_check_activation.dart';
import 'firebase_app_check_readiness.dart';
import 'firebase_initializer.dart';
import '../logging/app_logger.dart';

final firebaseInitializerProvider = Provider<FirebaseInitializer>(
  (ref) => const DefaultFirebaseInitializer(),
  name: 'firebaseInitializerProvider',
);

final firebaseAuthProvider = Provider<firebase_auth.FirebaseAuth>(
  (ref) => firebase_auth.FirebaseAuth.instance,
  name: 'firebaseAuthProvider',
);

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
  name: 'firebaseFirestoreProvider',
);

final firebaseAppCheckProvider = Provider<FirebaseAppCheck>(
  (ref) => FirebaseAppCheck.instance,
  name: 'firebaseAppCheckProvider',
);

final firebaseAppCheckActivationControllerProvider =
    Provider<FirebaseAppCheckActivationController>(
      (ref) => defaultFirebaseAppCheckActivationController,
      name: 'firebaseAppCheckActivationControllerProvider',
    );

final firebaseAppCheckActivationStateProvider =
    StreamProvider<FirebaseAppCheckActivationState>(
      (ref) => ref.watch(firebaseAppCheckActivationControllerProvider).states,
      name: 'firebaseAppCheckActivationStateProvider',
    );

/// One process-wide readiness gate is shared by Chat, Retry, and the Settings
/// live probe. Constructing it does not access the native SDK; token loading
/// begins only after Firebase Core bootstrap and activation have completed.
final firebaseAppCheckReadinessCoordinatorProvider =
    Provider<FirebaseAppCheckReadinessCoordinator>((ref) {
      final coordinator = FirebaseAppCheckReadinessCoordinator(
        activationController: ref.watch(
          firebaseAppCheckActivationControllerProvider,
        ),
        tokenLoader: ({required forceRefresh}) =>
            ref.read(firebaseAppCheckProvider).getToken(forceRefresh),
        safeDiagnosticLog: AppLogger.instance.debug,
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    }, name: 'firebaseAppCheckReadinessCoordinatorProvider');

final firebaseAppCheckReadinessStateProvider =
    StreamProvider<FirebaseAppCheckReadinessState>(
      (ref) => ref.watch(firebaseAppCheckReadinessCoordinatorProvider).states,
      name: 'firebaseAppCheckReadinessStateProvider',
    );

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
  name: 'googleSignInProvider',
);
