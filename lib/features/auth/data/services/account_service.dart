// lib/services/account_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> getFirestoreProfile() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _db.collection('users').doc(u.uid).get();
    return doc.data();
  }

  Future<void> updateDisplayName(String displayName) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Chưa đăng nhập.');

    final trimmed = displayName.trim();
    await u.updateDisplayName(trimmed);
    await _db.collection('users').doc(u.uid).set({
      'displayName': trimmed,
      'email': u.email,
      'updatedAt': Timestamp.now().toDate(),
    }, SetOptions(merge: true));
    await u.reload();
  }

  /// Cập nhật photoURL đã có sẵn (không upload)
  Future<void> updatePhotoUrl(String? photoUrl) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Chưa đăng nhập.');
    final url = (photoUrl ?? '').trim().isEmpty ? null : photoUrl!.trim();

    await u.updatePhotoURL(url);
    await _db.collection('users').doc(u.uid).set({
      'photoURL': url,
      'updatedAt': Timestamp.now().toDate(),
    }, SetOptions(merge: true));
    await u.reload();
  }

  /// Upload ảnh avatar lên Storage rồi cập nhật Auth + Firestore
  /// [bytes]: nội dung ảnh; [fileName]: tên gốc (để suy ra phần mở rộng)
  Future<String> uploadAvatarAndSave({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Chưa đăng nhập.');

    // Lấy extension để set tên file trong Storage
    final ext = _getExtension(fileName); // jpg/png/…
    final path = 'avatars/${u.uid}.$ext';
    final ref = _storage.ref().child(path);

    // Upload (có thể set contentType; ở đây để mặc định)
    final uploadTask = await ref.putData(bytes);
    final url = await uploadTask.ref.getDownloadURL();

    // Cập nhật Auth + Firestore
    await u.updatePhotoURL(url);
    await _db.collection('users').doc(u.uid).set({
      'photoURL': url,
      'updatedAt': Timestamp.now().toDate(),
    }, SetOptions(merge: true));
    await u.reload();

    return url;
  }

  String _getExtension(String name) {
    final idx = name.lastIndexOf('.');
    if (idx == -1 || idx == name.length - 1) return 'jpg';
    final ext = name.substring(idx + 1).toLowerCase();
    // Chỉ chấp nhận vài loại cơ bản; fallback -> jpg
    const ok = ['jpg', 'jpeg', 'png', 'webp'];
    return ok.contains(ext) ? ext : 'jpg';
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final u = _auth.currentUser;
    final email = u?.email;
    if (u == null || email == null) {
      throw Exception('Chưa đăng nhập hoặc thiếu email.');
    }
    final cred = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await u.reauthenticateWithCredential(cred);
    await u.updatePassword(newPassword);
  }

  bool get canChangePassword {
    final u = _auth.currentUser;
    if (u == null) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }
}
