import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_supabase_bridge_service.dart';

/// Central authentication service for ResQ.
///
/// Firebase Auth is the primary authentication system.
///
/// After Firebase login/registration succeeds, the
/// Firebase -> Supabase bridge is started immediately
/// in the background.
///
/// IMPORTANT:
/// Login/registration NEVER waits for Supabase.
///
/// Supabase access is checked strictly later when a
/// Supabase-dependent feature such as pet upload/search
/// is actually used.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  final FirebaseSupabaseBridgeService _supabaseBridge;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseSupabaseBridgeService? supabaseBridge,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _supabaseBridge = supabaseBridge ?? FirebaseSupabaseBridgeService();

  // ---------------------------------------------------------------------------
  // Authentication state
  // ---------------------------------------------------------------------------

  User? get currentUser => _firebaseAuth.currentUser;

  bool get isSignedIn => _firebaseAuth.currentUser != null;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Stream<User?> get idTokenChanges => _firebaseAuth.idTokenChanges();

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError(
        'Email cannot be empty.',
      );
    }

    if (password.isEmpty) {
      throw ArgumentError(
        'Password cannot be empty.',
      );
    }

    // -------------------------------------------------------
    // Firebase registration.
    //
    // This is the ONLY operation registration waits for.
    // -------------------------------------------------------

    final UserCredential credential =
        await _firebaseAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    // -------------------------------------------------------
    // Firebase succeeded.
    //
    // Start Firebase -> Supabase bridge immediately,
    // but DO NOT wait for it.
    // -------------------------------------------------------

    _startSupabaseBridgeInBackground();

    // Return immediately.
    return credential;
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError(
        'Email cannot be empty.',
      );
    }

    if (password.isEmpty) {
      throw ArgumentError(
        'Password cannot be empty.',
      );
    }

    // -------------------------------------------------------
    // Firebase login.
    //
    // Login waits ONLY for Firebase authentication.
    // -------------------------------------------------------

    final UserCredential credential =
        await _firebaseAuth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    // -------------------------------------------------------
    // Firebase succeeded.
    //
    // Start the Supabase bridge immediately,
    // but do not block navigation/login.
    // -------------------------------------------------------

    _startSupabaseBridgeInBackground();

    // Login completes immediately.
    return credential;
  }

  // ---------------------------------------------------------------------------
  // Firebase -> Supabase background bridge
  // ---------------------------------------------------------------------------

  void _startSupabaseBridgeInBackground() {
    unawaited(
      _runSupabaseBridgeSafely(),
    );
  }

  Future<void> _runSupabaseBridgeSafely() async {
    try {
      await _supabaseBridge.ensureSupabaseRole();

      debugPrint(
        'Firebase -> Supabase bridge ready.',
      );
    } catch (e, stackTrace) {
      // -----------------------------------------------------
      // IMPORTANT:
      //
      // Never throw this error back into login/register.
      //
      // Firebase authentication already succeeded.
      //
      // PetSearchService will attempt the bridge again
      // before a protected Supabase operation.
      // -----------------------------------------------------

      debugPrint(
        'Firebase -> Supabase background bridge '
        'failed: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Strict Supabase preparation
  // ---------------------------------------------------------------------------

  /// Use when a feature ACTUALLY requires Supabase.
  ///
  /// Unlike the background bridge after login,
  /// this method waits and throws if preparation fails.
  Future<void> ensureSupabaseAccess() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'A Firebase user must be logged in '
        'before accessing Supabase.',
      );
    }

    await _supabaseBridge.ensureSupabaseRole();
  }

  // ---------------------------------------------------------------------------
  // Firebase token
  // ---------------------------------------------------------------------------

  Future<String> getIdToken({
    bool forceRefresh = false,
  }) async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'No Firebase user is currently signed in.',
      );
    }

    final String? token = await user.getIdToken(
      forceRefresh,
    );

    if (token == null || token.isEmpty) {
      throw StateError(
        'Firebase did not return an ID token.',
      );
    }

    return token;
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// Google Sign-In will be implemented later.
  ///
  /// When added, it will authenticate through Firebase
  /// and then call:
  ///
  ///     _startSupabaseBridgeInBackground();
  ///
  /// exactly like email/password login.
  Future<UserCredential> signInWithGoogle() async {
    throw FirebaseAuthException(
      code: 'google-signin-not-configured',
      message: 'Google Sign-In is not configured yet. '
          'Please use email/password authentication.',
    );
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    _supabaseBridge.dispose();
  }
}
