import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/firestore_collections.dart';
import '../../data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as g;
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);

    await _db
        .collection(FirestoreCollections.users)
        .doc(cred.user!.uid)
        .set(
          UserModel(
            uid: cred.user!.uid,
            email: email,
            displayName: displayName,
            role: role,
            createdAt: DateTime.now(),
          ).toMap(),
          SetOptions(merge: true),
        );
    return cred;
  }

  Future<void> sendPasswordResetEmail(String email) {
    // ĐÚNG tên hàm của FirebaseAuth
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserRole?> getUserRole(String uid) async {
    final doc = await _db.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return userRoleFromString(data['role'] as String? ?? 'student');
  }

  /// Google Sign-In cho Android/iOS/Web/macOS
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      // provider.addScope('email'); // nếu cần
      // provider.setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    }

    // Android/iOS/macOS
    final gUser = await g.GoogleSignIn().signIn();
    if (gUser == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'User cancelled Google Sign-In',
      );
    }

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// (Tuỳ chọn) Liên kết Google vào tài khoản đang đăng nhập (account linking)
  Future<UserCredential> linkGoogleToCurrentUser() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is signed in.',
      );
    }
    final googleUser = await g.GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'User cancelled Google Sign-In',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return current.linkWithCredential(credential);
  }
}
