// ignore_for_file: avoid_print
//
// Promote a user to admin.
//
// This is a thin Dart wrapper that delegates to the Node.js script
// `tools/promote_admin.js`, which uses the Firebase Admin SDK to bypass
// Firestore security rules (required to update the `role` field).
//
// PREREQUISITES:
//   1. `tools/service-account.json` (download from Firebase Console →
//      Project settings → Service accounts → Generate new private key).
//   2. `npm install firebase-admin` inside the `tools/` directory.
//   3. Node.js installed and on PATH.
//
// USAGE:
//   dart run tools/make_admin.dart [email]
//   (defaults to christiankethaguacito@sksu.edu.ph)
//
// WHY: The client SDK (used by the Flutter app) cannot update the `role`
// field — Firestore rules forbid it for non-admins. Bootstrapping the first
// admin requires the Admin SDK, which bypasses rules.

import 'dart:io';

void main(List<String> args) async {
  final email = args.isNotEmpty ? args[0] : 'christiankethaguacito@sksu.edu.ph';

  final scriptPath =
      '${Directory.current.path}${Platform.pathSeparator}tools${Platform.pathSeparator}promote_admin.js';
  final scriptFile = File(scriptPath);
  if (!scriptFile.existsSync()) {
    print('❌ Could not find promote_admin.js at: $scriptPath');
    exit(1);
  }

  print('🚀 Running: node "$scriptPath" "$email"');
  final result = await Process.start('node', [scriptPath, email]);
  await stdout.addStream(result.stdout);
  await stderr.addStream(result.stderr);
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    print('❌ Script exited with code $exitCode');
  }
  exit(exitCode);
}
