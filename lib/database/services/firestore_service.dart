import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Wraps Firestore reads/writes for user profile documents.
/// Collection layout: `users/{uid}` -> UserModel.toMap()
class FirestoreService {
  final CollectionReference<Map<String, dynamic>> _usersRef =
      FirebaseFirestore.instance.collection('users');

  /// Creates/overwrites the profile document for this user, keyed by
  /// their Firebase Auth uid. Called right after registerWithEmail
  /// succeeds, so Auth (identity) and Firestore (profile data) stay
  /// linked by the same uid.
  Future<void> saveUserProfile(UserModel user) {
    // Ensure new users get a default role = 'user' unless explicitly set elsewhere.
    final map = user.toMap();
    map['role'] = map['role'] ?? 'user';
    // Use merge to avoid overwriting fields that may have been set manually
    // (e.g. role or adminLevel created by admins via the admin UI).
    return _usersRef.doc(user.uid).set(map, SetOptions(merge: true));
  }

  /// Fetches a user's profile document. Returns null if it doesn't exist.
  Future<UserModel?> getUserProfile(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserModel.fromMap(uid, snapshot.data()!);
  }

  Stream<UserModel?> watchUserProfile(String uid) =>
      _usersRef.doc(uid).snapshots().map(
            (snapshot) => snapshot.exists
                ? UserModel.fromMap(uid, snapshot.data()!)
                : null,
          );

  Future<void> updateUserProfile(String uid, Map<String, dynamic> values) {
    return _usersRef.doc(uid).update(values);
  }
}
