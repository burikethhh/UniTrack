// Shared Firebase test setup.
//
// Both `DatabaseService`, `NotificationService`, `AdminProvider`, and
// `BroadcastService` initialize `FirebaseFirestore.instance` as a field
// initializer — which throws `[core/no-app]` unless a Firebase app has
// been registered. These helpers install the firebase_core_platform_interface
// mock method channel and create a real (mocked) default firebase app so that
// constructing those classes in unit tests does not blow up.
//
// The helpers do NOT mock Firestore operations themselves; tests that would
// actually hit a collection (e.g. `DatabaseService.searchFaculty('something')`
// with a non-empty query) are avoided for exactly that reason.
//
// No new dependencies are required — `firebase_core_platform_interface` is
// a transitive dep of `firebase_core`, which is already a direct dependency.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

bool _initialized = false;

/// Installs the firebase_core mock method channel and ensures a default
/// `FirebaseApp` exists. Safe to call from multiple `setUpAll` blocks — only
/// the first call performs the initialization.
///
/// `FirebaseFirestore.instance` resolves the DEFAULT firebase app. The
/// `firebase_core` mock installs a `FirebaseCoreHostApi.initializeCore` that
/// auto-registers a `[DEFAULT]` app the first time the platform interface is
/// touched (including via `Firebase.apps`), so wrapping the explicit
/// `initializeApp` call in try/catch-on-duplicate-app keeps this idempotent.
Future<void> setupFirebaseForTests() async {
  if (_initialized) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender',
        projectId: 'test-project',
      ),
    );
  } catch (e) {
    // `[core/duplicate-app]` is fine — the mock's initializeCore already
    // registered the [DEFAULT] app once accessor side-effects kicked in.
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  _initialized = true;
}
