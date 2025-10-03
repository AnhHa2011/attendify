import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart' as g;
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../../../core/data/models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final remoteConfig = FirebaseRemoteConfig.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<String> getEmailSupport() async {
    await remoteConfig.fetchAndActivate();
    final supportEmail = remoteConfig.getString('support_email');
    return supportEmail;
  }

  // ===================== EMAIL/PASSWORD =====================

  // ▼▼▼ THAY ĐỔI Ở ĐÂY ▼▼▼
  /// Đăng nhập bằng Email và Mật khẩu, đồng thời kiểm tra trạng thái active
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      // B1: Đăng nhập với Firebase Auth như bình thường
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        // Trường hợp hiếm khi xảy ra nếu lệnh trên thành công
        throw Exception('Đăng nhập thất bại, không tìm thấy người dùng.');
      }

      // B2: Lấy dữ liệu người dùng từ Firestore để kiểm tra cờ 'isActive'
      final userDoc = await _db.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Nếu tài khoản tồn tại trong Auth nhưng không có trong Firestore (lỗi dữ liệu)
        await _auth.signOut(); // Đăng xuất để đảm bảo an toàn
        throw Exception(
          'Dữ liệu tài khoản không hợp lệ. Vui lòng liên hệ quản trị viên.',
        );
      }

      final userData = userDoc.data()!;
      // Mặc định là true nếu trường 'isActive' chưa tồn tại (để hỗ trợ các tài khoản cũ)
      final bool isActive = userData['isActive'] ?? true;

      // B3: Kiểm tra cờ. Nếu không active, đăng xuất và báo lỗi
      if (!isActive) {
        await _auth.signOut(); // Đăng xuất ngay lập tức
        throw Exception(
          'Tài khoản của bạn đã bị vô hiệu hoá. Vui lòng liên hệ quản trị viên.',
        );
      }

      // Nếu mọi thứ ổn, trả về userCredential
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Chuyển các lỗi của Firebase thành thông báo thân thiện hơn
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('Email hoặc mật khẩu không chính xác.');
      }
      throw Exception('Đã xảy ra lỗi trong quá trình đăng nhập.');
    } catch (e) {
      // Ném lại các lỗi đã được tùy chỉnh ở trên để UI có thể bắt được
      rethrow;
    }
  }

  // ▼▼▼ THAY ĐỔI Ở ĐÂY (Thêm trường isActive) ▼▼▼
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
      'createdAt': FieldValue.serverTimestamp(), // Nên dùng server timestamp
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive':
          true, // <-- THÊM DÒNG NÀY để đảm bảo người dùng mới luôn active
    });
  }

  // ===================== GOOGLE SIGN-IN =====================
  Future<UserCredential> _signInWithGoogleForceAccountPicker() async {
    // ... (Hàm này không thay đổi)
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    } else {
      final google = g.GoogleSignIn(scopes: const ['email']);
      try {
        await google.signOut();
      } catch (_) {}
      final account = await google.signIn();
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

  // ▼▼▼ THAY ĐỔI Ở ĐÂY (Kiểm tra isActive cho người dùng Google) ▼▼▼
  Future<void> googleSignInThenEnsureRole(
    Future<UserRole?> Function() pickRole,
  ) async {
    final cred = await _signInWithGoogleForceAccountPicker();
    final u = cred.user!;
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // User Google lần đầu → bắt chọn role và mặc định là active
      final role = (await pickRole()) ?? UserRole.student;
      await ref.set({
        'uid': u.uid,
        'email': u.email ?? '',
        'displayName': u.displayName ?? '',
        'role': role.toKey(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true, // <-- THÊM DÒNG NÀY
      });
      return;
    }

    // Đã có doc → kiểm tra cờ isActive trước khi làm bất cứ việc gì khác
    final data = snap.data()!;
    final bool isActive = data['isActive'] ?? true;

    if (!isActive) {
      // Nếu không active, đăng xuất khỏi cả Firebase và Google rồi báo lỗi
      await _auth.signOut();
      await g.GoogleSignIn().signOut();
      throw Exception(
        'Tài khoản của bạn đã bị vô hiệu hoá. Vui lòng liên hệ quản trị viên.',
      );
    }

    // Nếu active, tiếp tục logic kiểm tra và chọn role như cũ
    final currentRole = UserRoleX.fromKey(data['role'] as String?);
    if (currentRole == UserRole.student) {
      // logic cũ của bạn
      final picked = (await pickRole()) ?? UserRole.student;
      await ref.update({
        'role': picked.toKey(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
