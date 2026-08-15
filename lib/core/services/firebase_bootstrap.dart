import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Whether Firebase finished initializing successfully. League features must
/// check this before touching Auth/Firestore — a Firebase outage or missing
/// config (e.g. no GoogleService-Info.plist on iOS) should degrade the app
/// gracefully rather than crash it, since the rest of Capitle works entirely
/// offline/local today.
bool firebaseAvailable = false;

Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
  } catch (e, st) {
    debugPrint('Firebase init failed (league features will be unavailable): $e\n$st');
    firebaseAvailable = false;
  }
}
