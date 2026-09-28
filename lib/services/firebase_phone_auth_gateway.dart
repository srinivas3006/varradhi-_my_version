import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Thin seam over the Firebase Phone Auth SDK so the verification flow can
/// be driven by a fake in tests.
///
/// Firebase is used here ONLY to prove ownership of a phone number. The app's
/// own login is the backend session; the Firebase user created by
/// [signInWithCredential] is signed out again as soon as its ID token has
/// been handed to the backend.
abstract class PhoneAuthGateway {
  /// Makes sure a Firebase app exists. False means Phone Auth cannot run on
  /// this install and the backend SMS fallback should be used.
  Future<bool> ensureAvailable();

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onAutoRetrievalTimeout,
  });

  PhoneAuthCredential credential(String verificationId, String smsCode);

  /// Signs in with [credential] and returns a freshly minted ID token.
  Future<String> signInAndGetIdToken(PhoneAuthCredential credential);

  /// Forces a new ID token for the currently signed-in Firebase user, or
  /// null if there is none.
  Future<String?> refreshIdToken();

  Future<void> signOut();

  void setLanguageCode(String code);
}

class FirebasePhoneAuthGateway implements PhoneAuthGateway {
  FirebasePhoneAuthGateway._();
  static final FirebasePhoneAuthGateway instance = FirebasePhoneAuthGateway._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Future<bool> ensureAvailable() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 6));
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('[PhoneAuth] Firebase unavailable: $e');
      return false;
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onAutoRetrievalTimeout,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      // Android SMS auto-retrieval window.
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
    );
  }

  @override
  PhoneAuthCredential credential(String verificationId, String smsCode) =>
      PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode);

  @override
  Future<String> signInAndGetIdToken(PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    final user = result.user ?? _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'user-missing', message: 'Firebase sign-in returned no user.');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
          code: 'token-missing', message: 'Firebase returned no ID token.');
    }
    return token;
  }

  @override
  Future<String?> refreshIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(true);
  }

  @override
  Future<void> signOut() async {
    try {
      if (_auth.currentUser != null) await _auth.signOut();
    } catch (e) {
      debugPrint('[PhoneAuth] signOut failed: $e');
    }
  }

  @override
  void setLanguageCode(String code) {
    try {
      _auth.setLanguageCode(code);
    } catch (_) {
      // Cosmetic only (SMS template language).
    }
  }
}
