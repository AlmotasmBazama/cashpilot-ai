import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live Firebase auth and profile smoke flow',
    (tester) async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final auth = firebase_auth.FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final sessionGuard = FirebaseAuthSessionEpochGuard(auth);
      final dataSource = FirebaseAuthDataSource(
        auth: auth,
        firestore: firestore,
        googleSignIn: GoogleSignIn.instance,
        logger: AppLogger.instance,
        completedDeletionOverlay: const _NoCompletedDeletionOverlay(),
        sessionGuard: sessionGuard,
      );
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'codex-live-$stamp@example.com';
      const password = 'CodexSmoke123!';
      String? uid;

      try {
        final registered = await dataSource.signUp(
          name: 'Codex Live',
          email: email,
          password: password,
        );
        uid = registered.uid;

        final createdDoc = await firestore.collection('users').doc(uid).get();
        expect(createdDoc.exists, isTrue);
        expect(createdDoc.data()?['uid'], uid);
        expect(createdDoc.data()?['email'], email);
        expect(createdDoc.data()?['name'], 'Codex Live');

        await dataSource.signOut();
        expect(auth.currentUser, isNull);

        final signedIn = await dataSource.signIn(
          email: email,
          password: password,
          rememberMe: false,
        );
        expect(signedIn.uid, uid);

        final completed = await dataSource.completeProfile(
          expectedSession: AuthSessionIdentity(
            uid: signedIn.uid,
            isAnonymous: signedIn.isAnonymous,
            authSessionGeneration: signedIn.authSessionGeneration,
            tenantId: signedIn.tenantId,
          ),
          displayName: 'Codex Profile',
          currency: 'eur',
          language: 'en',
          country: 'US',
          timezone: 'UTC',
        );
        expect(completed.displayName, 'Codex Profile');
        expect(completed.currency, 'EUR');
        expect(completed.country, 'US');

        final updatedDoc = await firestore.collection('users').doc(uid).get();
        expect(updatedDoc.data()?['name'], 'Codex Profile');
        expect(updatedDoc.data()?['currency'], 'EUR');
        expect(updatedDoc.data()?['language'], 'en');
        expect(updatedDoc.data()?['country'], 'US');
        expect(updatedDoc.data()?['timezone'], 'UTC');

        await dataSource.signOut();
        expect(auth.currentUser, isNull);

        await dataSource.signIn(
          email: email,
          password: password,
          rememberMe: false,
        );
        await firestore.collection('users').doc(uid).delete();
        await auth.currentUser!.delete();
        uid = null;
        expect(auth.currentUser, isNull);
      } finally {
        if (uid != null) {
          try {
            await firestore.collection('users').doc(uid).delete();
          } on Object {
            // Best-effort cleanup for failed smoke runs.
          }
          try {
            var cleanupUser = auth.currentUser;
            if (cleanupUser?.uid != uid) {
              await auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              cleanupUser = auth.currentUser;
            }
            if (cleanupUser?.uid == uid) {
              await cleanupUser!.delete();
            }
          } on Object {
            // Best-effort cleanup for failed smoke runs.
          }
        }
        await auth.signOut();
        await dataSource.dispose();
        await sessionGuard.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

final class _NoCompletedDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  const _NoCompletedDeletionOverlay();

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) => false;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {}
}
