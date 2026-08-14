import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/services/broadcast_service.dart';

import '../firebase_test_setup.dart';

/// Tests for [BroadcastService].
///
/// `BroadcastService.sendBroadcast` reads `FirebaseFirestore.instance` and
/// drives `firestore.batch().set(...).commit()` in a chunked loop with chunk
/// size 499 (Firestore's batch write limit, minus one for safety). Testing
/// the chunking logic against real Firestore would require connectivity; we
/// instead install an in-memory fake [FirebaseFirestorePlatform] behind the
/// `cloud_firestore` facade so that the real [BroadcastService.sendBroadcast]
/// code path exercises our fake. The fake counts commits and the number of
/// `set` operations per chunk, letting us verify the chunking formula ends
/// up with the expected number of `{chunk_size, commit_count}` tuples for
/// lists both below and above the 499 threshold.
void main() {
  setUpAll(() async {
    await setupFirebaseForTests();
    // Install the fake ONCE. `FirebaseFirestore.instance` lazily caches its
    // delegate by app-name; replacing `FirebaseFirestorePlatform.instance`
    // after that cache is populated has no effect, so the platform fake must
    // be installed before the first Firestore interaction in this isolate.
    FirebaseFirestorePlatform.instance = FakeFirestorePlatform();
  });

  group('BroadcastService singleton', () {
    test('exposes a stable static instance', () {
      expect(BroadcastService.instance, same(BroadcastService.instance));
    });
  });

  group('BroadcastService.sendBroadcast chunking', () {
    FakeFirestorePlatform fake() =>
        FirebaseFirestorePlatform.instance as FakeFirestorePlatform;

    setUp(() => fake().reset());

    test('writes nothing for an empty audience list', () async {
      final sent = await BroadcastService.instance.sendBroadcast(
        title: 't',
        body: 'b',
        audienceIds: const [],
      );

      expect(sent, equals(0));
      expect(fake().commitCount, equals(0));
      expect(fake().totalSetCalls, equals(0));
    });

    test('writes a single batch for fewer than 499 recipients', () async {
      final ids = List<String>.generate(100, (i) => 'u$i');

      final sent = await BroadcastService.instance.sendBroadcast(
        title: 't',
        body: 'b',
        audienceIds: ids,
      );

      expect(sent, equals(100));
      expect(fake().commitCount, equals(1));
      expect(fake().totalSetCalls, equals(100));
    });

    test('chunks exactly at 499 — single batch at the boundary', () async {
      final ids = List<String>.generate(499, (i) => 'u$i');

      final sent = await BroadcastService.instance.sendBroadcast(
        title: 't',
        body: 'b',
        audienceIds: ids,
      );

      expect(sent, equals(499));
      expect(fake().commitCount, equals(1));
    });

    test('splits a >499 list into multiple commits (998 -> 2 commits of 499)',
        () async {
      final ids = List<String>.generate(998, (i) => 'u$i');

      final sent = await BroadcastService.instance.sendBroadcast(
        title: 't',
        body: 'b',
        audienceIds: ids,
      );

      expect(sent, equals(998));
      expect(fake().commitCount, equals(2));
      expect(fake().setsPerCommit.first, equals(499));
      expect(fake().setsPerCommit.last, equals(499));
    });

    test('splits 1500 recipients into 4 commits (499 + 499 + 499 + 3)',
        () async {
      final ids = List<String>.generate(1500, (i) => 'u$i');

      final sent = await BroadcastService.instance.sendBroadcast(
        title: 't',
        body: 'b',
        audienceIds: ids,
      );

      expect(sent, equals(1500));
      expect(fake().commitCount, equals(4));
      expect(fake().setsPerCommit[0], equals(499));
      expect(fake().setsPerCommit[1], equals(499));
      expect(fake().setsPerCommit[2], equals(499));
      expect(fake().setsPerCommit[3], equals(3));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────
// In-memory fake Firestore platform. Implements only the surfaces
// `BroadcastService.sendBroadcast` reaches (`batch`, `collection`, `doc`,
// `set`, `commit`). All other methods throw UnimplementedError via the
// parent abstract class defaults.
// ─────────────────────────────────────────────────────────────────────────

class FakeFirestorePlatform extends FirebaseFirestorePlatform {
  FakeFirestorePlatform() : super(appInstance: Firebase.app());

  int commitCount = 0;
  int totalSetCalls = 0;
  final List<int> setsPerCommit = [];

  void reset() {
    commitCount = 0;
    totalSetCalls = 0;
    setsPerCommit.clear();
  }

  @override
  FakeFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;

  @override
  FakeWriteBatchPlatform batch() => FakeWriteBatchPlatform(this);

  @override
  FakeCollectionReferencePlatform collection(String collectionPath) =>
      FakeCollectionReferencePlatform(this, collectionPath);

  void recordCommit(FakeWriteBatchPlatform batch) {
    commitCount++;
    setsPerCommit.add(batch.setCount);
    totalSetCalls += batch.setCount;
  }
}

class FakeWriteBatchPlatform extends WriteBatchPlatform {
  FakeWriteBatchPlatform(this._firestore);

  final FakeFirestorePlatform _firestore;
  int setCount = 0;

  @override
  void set(String documentPath, Map<String, dynamic> data, [SetOptions? options]) {
    setCount++;
  }

  @override
  Future<void> commit() async {
    _firestore.recordCommit(this);
  }
}

class FakeCollectionReferencePlatform extends CollectionReferencePlatform {
  FakeCollectionReferencePlatform(super.firestore, super.path);

  @override
  FakeDocumentReferencePlatform doc([String? path]) {
    final id = path ?? 'auto-id-${DateTime.now().microsecondsSinceEpoch}';
    return FakeDocumentReferencePlatform(firestore, '$path/$id');
  }
}

class FakeDocumentReferencePlatform extends DocumentReferencePlatform {
  FakeDocumentReferencePlatform(super.firestore, super.path);
}
