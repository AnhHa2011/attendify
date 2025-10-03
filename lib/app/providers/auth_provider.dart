// lib/app/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 thêm
import '../../core/data/models/user_model.dart';
import '../../features/auth/data/services/firebase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _auth;

  // Subscriptions
  StreamSubscription<User?>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  // Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _profileData;

  AuthProvider(this._auth) {
    _loading = true;
    // Lắng nghe trạng thái đăng nhập
    _sub = _auth.authStateChanges().listen((u) async {
      // Hủy listener profile cũ (nếu có)
      await _profileSub?.cancel();
      _profileSub = null;
      _profileData = null;

      _user = u;
      _role = (u == null) ? null : await _auth.getUserRole(u.uid);

      // Nếu đã đăng nhập -> lắng nghe users/{uid} để lấy displayName/photoURL từ Firestore
      if (u != null) {
        _profileSub = _db.collection('users').doc(u.uid).snapshots().listen((
          doc,
        ) {
          _profileData = doc.data();
          notifyListeners(); // cập nhật UI ngay khi Firestore thay đổi
        });
      }

      _loading = false;
      notifyListeners();
    });
  }

  User? _user;
  UserRole? _role;
  bool _loading = false;

  // Getters
  User? get user => _user;
  UserRole? get role => _role;
  String? get roleKey => _role?.toKey();
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;

  /// Ưu tiên tên/ảnh từ Firestore; fallback về Auth nếu chưa có
  String? get displayNameFromProfile =>
      (_profileData?['displayName'] as String?) ?? _user?.displayName;

  String? get photoURLFromProfile =>
      (_profileData?['photoURL'] as String?) ?? _user?.photoURL;

  /// Reload lại currentUser của FirebaseAuth (ít khi cần nếu UI đang đọc Firestore)
  Future<void> refreshUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  // Email flows
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      await _auth.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
        role: role,
      );
    } catch (e) {
      throw e;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmail(email, password);
    } catch (e) {
      throw e;
    }
  }

  Future<void> loginWithGoogleAndPickRole(
    Future<UserRole?> Function() pickRole,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      await _auth.googleSignInThenEnsureRole(pickRole);
    } finally {
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

    // Dọn dẹp
    await _profileSub?.cancel();
    _profileSub = null;
    _profileData = null;

    _user = null;
    _role = null;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
