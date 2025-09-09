import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, lecture, student }

UserRole userRoleFromString(String v) {
  return UserRole.values.firstWhere(
    (e) => e.name == v,
    orElse: () => UserRole.student,
  );
}

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    uid: map['uid'] as String,
    email: map['email'] as String? ?? '',
    displayName: map['displayName'] as String?,
    role: userRoleFromString(map['role'] as String? ?? 'student'),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
