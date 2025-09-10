// lib/data/models/user_model.dart

/// Các role trong hệ thống
enum UserRole { admin, lecture, student, unknown }

extension UserRoleX on UserRole {
  /// Key chuẩn để lưu Firestore
  String toKey() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.lecture:
        return 'lecture';
      case UserRole.student:
        return 'student';
      case UserRole.unknown:
      default:
        return 'unknown';
    }
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
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.toKey(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      displayName: (map['displayName'] ?? '') as String,
      role: UserRoleX.fromKey(map['role'] as String?),
    );
  }
}
