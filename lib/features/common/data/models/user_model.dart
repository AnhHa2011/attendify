// lib/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Các role trong hệ thống
enum UserRole { admin, lecture, student, unknown }

// === KHÔI PHỤC LẠI EXTENSION ĐỂ TƯƠNG THÍCH VỚI CODE CŨ ===
extension UserRoleX on UserRole {
  /// Key chuẩn để lưu Firestore
  String toKey() {
    return name; // Dùng .name cho ngắn gọn và an toàn
  }

  /// Parse từ string Firestore → enum
  static UserRole fromKey(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'lecture':
        return UserRole.lecture;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.unknown;
    }
  }
}

/// Model đại diện cho User trong app
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  /// Hàm factory để tạo UserModel từ DocumentSnapshot của Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: doc.id,
      email: (data['email'] ?? '') as String,
      displayName: (data['displayName'] ?? '') as String,
      // Vẫn sử dụng hàm fromKey để parse role
      role: UserRoleX.fromKey(data['role'] as String?),
    );
  }

  /// Hàm để chuyển đổi UserModel thành Map để ghi vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      // Vẫn sử dụng hàm toKey để lưu role
      'role': role.toKey(),
    };
  }
}
