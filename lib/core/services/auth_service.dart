import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_bootstrap.dart';

/// Wraps Firebase Anonymous Auth (the baseline identity every player gets,
/// invisibly) plus an optional "Sign in with Google" upgrade that links the
/// anonymous account to a real Google credential so progress survives a
/// reinstall or a new device — without ever forcing a login screen on
/// someone who just wants to play.
class AuthService {
  bool _googleInitialized = false;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  bool get isLinkedToGoogle =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  /// Signs in anonymously if there's no current user yet. Safe to call on
  /// every app launch. Never throws — on failure (offline cold start,
  /// Firebase misconfigured, etc.) [uid] just stays null and league
  /// features treat that as "unavailable for now."
  Future<void> ensureSignedIn({Duration timeout = const Duration(seconds: 8)}) async {
    if (!firebaseAvailable) return;
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance.signInAnonymously().timeout(timeout);
    } catch (e, st) {
      debugPrint('Anonymous sign-in failed (non-fatal): $e\n$st');
    }
  }

  // The web (client_type: 3) OAuth client from google-services.json —
  // needed as serverClientId so the ID token GoogleSignIn returns is
  // audienced correctly for Firebase's GoogleAuthProvider.credential() to
  // accept. In principle google_sign_in_android can auto-discover this
  // from google-services.json without it being passed explicitly, but
  // the package's own README lists a missing/incorrect serverClientId as
  // one of the top causes of sign-in silently failing — passing it
  // explicitly removes that as a variable entirely.
  static const _webClientId =
      '429418557392-9cqu5orjg80t2dnpf7ouinmn8aj258k8.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _googleInitialized = true;
  }

  /// Upgrades the current anonymous account to be backed by a Google
  /// account, preserving the same league profile/history. If this Google
  /// account is already linked to a different (older) anonymous UID — e.g.
  /// the user reinstalled and got a fresh anonymous UID, then signs back in
  /// with the Google account they used before — Firebase rejects the link
  /// with `credential-already-in-use`; in that case this signs in with that
  /// credential directly instead, which switches the active UID to the
  /// pre-existing linked account. Callers must treat that case as "welcome
  /// back, restoring your previous profile," not a silent identity swap.
  Future<UserCredential> linkGoogle() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return FirebaseAuth.instance.signInWithCredential(credential);
    }

    try {
      return await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        return FirebaseAuth.instance.signInWithCredential(credential);
      }
      rethrow;
    }
  }
}

final authService = AuthService();
