// lib/services/firebase/admin_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/course_model.dart';
import '../../data/models/user_model.dart'; // Giả sử bạn có UserModel

class AdminService {
  final _db = FirebaseFirestore.instance;

  // === QUẢN LÝ MÔN HỌC (COURSES) ===

  /// Tạo một môn học mới
  Future<void> createCourse({
    required String courseCode,
    required String courseName,
    required int credits,
  }) {
    return _db.collection('courses').add({
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
    });
  }

  /// Lấy danh sách tất cả môn học
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _db
        .collection('courses')
        .orderBy('courseCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  // === QUẢN LÝ NGƯỜI DÙNG (USERS) ===

  /// Lấy danh sách tất cả giảng viên
  Stream<List<Map<String, String>>> getAllLecturersStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'lecturer')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final d = doc.data();
            return {
              'uid': doc.id,
              'name': (d['displayName'] ?? '') as String,
              'email': (d['email'] ?? '') as String,
            };
          }).toList(),
        );
  }

  // Bạn có thể thêm các hàm khác ở đây sau này, ví dụ:
  // Stream<List<UserModel>> getAllStudentsStream() { ... }
  // Future<void> createUser(...) { ... }
}
