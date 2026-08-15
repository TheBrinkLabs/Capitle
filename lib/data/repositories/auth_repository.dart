import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_bootstrap.dart';

/// Stream of the current Firebase Auth user (null when signed out, which
/// shouldn't normally happen once [AuthService.ensureSignedIn] has run —
/// but Firebase isn't guaranteed to be available, so this can stay null
/// forever on a device where Firebase failed to init).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  if (!firebaseAvailable) return const Stream.empty();
  return FirebaseAuth.instance.authStateChanges();
});

/// The current player's Firebase Auth UID, or null if not signed in (or
/// Firebase is unavailable). This is the identity every league Firestore
/// document is keyed on.
final uidProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
});
