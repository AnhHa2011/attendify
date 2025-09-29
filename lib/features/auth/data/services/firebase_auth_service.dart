import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart' as g;
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../../../core/data/models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Trong Firebase Console: Remote Config, tạo key 'support_email'
  final remoteConfig = FirebaseRemoteConfig.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ===================== EMAIL/PASSWORD =====================
  Future<String> getEmailSupport() async {
    await remoteConfig.fetchAndActivate();
    final supportEmail = remoteConfig.getString('support_email');
    return supportEmail;
  }

  // ===================== EMAIL/PASSWORD =====================
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName);

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'displayName': displayName,
      'role': role.toKey(),
      'createdAt': Timestamp.now().toDate(),
    });
  }

  // ===================== GOOGLE SIGN-IN =====================
  /// Sign-in Google nhưng **ép hiển thị chọn tài khoản** mỗi lần:
  /// - Web: setCustomParameters(prompt=select_account)
  /// - Mobile/Desktop: signOut() trước signIn() để xoá cache
  Future<UserCredential> _signInWithGoogleForceAccountPicker() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      // Nếu web đã đăng nhập sẵn, signInWithPopup vẫn hiện chọn account nhờ custom param
      return _auth.signInWithPopup(provider);
    } else {
      final google = g.GoogleSignIn(scopes: const ['email']);

      // EP: Xoá phiên Google trước đó để lần nào cũng hiện màn chọn tài khoản
      try {
        await google.signOut();
        // (tuỳ trường hợp) có thể dùng thêm: await google.disconnect();
      } catch (_) {
        // ignore: nếu chưa có session trước đó
      }

      final account = await google.signIn(); // -> sẽ hiện chọn account
      if (account == null) {
        throw FirebaseAuthException(code: 'canceled', message: 'User canceled');
      }

      final gAuth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      return _auth.signInWithCredential(cred);
    }
  }

  /// Đăng nhập Google xong, nếu user **mới** hoặc **role thiếu/unknown** → gọi pickRole() để chọn role và lưu.
  Future<void> googleSignInThenEnsureRole(
    Future<UserRole?> Function() pickRole,
  ) async {
    final cred = await _signInWithGoogleForceAccountPicker();
    final u = cred.user!;
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // User Google lần đầu → bắt chọn role
      final role = (await pickRole()) ?? UserRole.student;
      await ref.set({
        'uid': u.uid,
        'email': u.email ?? '',
        'displayName': u.displayName ?? '',
        'role': role.toKey(),
        'createdAt': Timestamp.now().toDate(),
      });
      return;
    }

    // Đã có doc → nếu thiếu role hoặc role unknown thì yêu cầu chọn
    final data = snap.data()!;
    final currentRole = UserRoleX.fromKey(data['role'] as String?);
    if (currentRole == UserRole.student) {
      final picked = (await pickRole()) ?? UserRole.student;
      await ref.update({'role': picked.toKey()});
    }
  }

  // ===================== COMMON =====================
  Future<UserRole?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return UserRole.student;
    return UserRoleX.fromKey(doc.data()!['role'] as String?);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();
}
