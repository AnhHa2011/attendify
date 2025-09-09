import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../services/firebase/firebase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService;

  AuthProvider(this._authService) {
    _authService.authStateChanges().listen((u) async {
      _user = u;
      if (_user != null) {
        _role = await _authService.getUserRole(_user!.uid);
      } else {
        _role = null;
      }
      notifyListeners();
    });
  }

  User? _user;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  UserRole? _role;
  UserRole? get role => _role;

  Future<void> login(String email, String password) async {
    await _authService.signInWithEmail(email, password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    await _authService.registerWithEmail(
      email: email,
      password: password,
      displayName: name,
      role: role,
    );
  }

  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> logout() => _authService.signOut();
}
