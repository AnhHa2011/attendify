// lib/app/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../services/firebase/auth/firebase_auth_service.dart';

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
    _loading = true;
    notifyListeners();
    await _auth.registerWithEmail(
      email: email,
      password: password,
      displayName: name,
      role: role,
    );
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    await _auth.signInWithEmail(email, password);
  }

  // Google flow riêng: login xong mới hỏi role nếu cần
  Future<void> loginWithGoogleAndPickRole(
    Future<UserRole?> Function() pickRole,
  ) async {
    _loading = true;
    notifyListeners();
    await _auth.googleSignInThenEnsureRole(pickRole);
    _loading = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    await _auth.signOut();
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
