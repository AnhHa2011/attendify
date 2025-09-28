// lib/app/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/data/models/user_model.dart';
import '../../features/auth/data/services/firebase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _auth;
  StreamSubscription<User?>? _sub;

  AuthProvider(this._auth) {
    _loading = true;
    _sub = _auth.authStateChanges().listen((u) async {
      _user = u;
      _role = (u == null) ? null : await _auth.getUserRole(u.uid);
      _loading = false;
      notifyListeners();
    });
  }

  User? _user;
  UserRole? _role;
  bool _loading = false;

  User? get user => _user;
  UserRole? get role => _role;
  String? get roleKey => _role?.toKey();
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;

  // Email flows
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    // KHÔNG quản lý loading ở đây. Hãy để UI tự xử lý.
    try {
      await _auth.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
        role: role,
      );
    } catch (e) {
      // Chỉ cần ném lại lỗi, không cần notifyListeners()
      throw e;
    }
  }

  // SỬA LẠI PHƯƠNG THỨC LOGIN
  Future<void> login(String email, String password) async {
    // KHÔNG quản lý loading ở đây. Hãy để UI tự xử lý.
    try {
      await _auth.signInWithEmail(email, password);
    } catch (e) {
      // Chỉ cần ném lại lỗi, không cần notifyListeners()
      throw e;
    }
  }

  // Google flow riêng: login xong mới hỏi role nếu cần
  Future<void> loginWithGoogleAndPickRole(
    Future<UserRole?> Function() pickRole,
  ) async {
    // Có thể giữ lại loading ở đây vì nó phức tạp hơn
    _loading = true;
    notifyListeners();
    try {
      await _auth.googleSignInThenEnsureRole(pickRole);
    } catch (e) {
      throw e;
    } finally {
      // Đảm bảo loading luôn được tắt
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    await _auth.signOut();

    _user = null;
    _role = null;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
