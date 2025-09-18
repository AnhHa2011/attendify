// lib/services/firebase/admin_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/course_model.dart';
import '../../data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ───────────────────────────
  // QUẢN LÝ NGƯỜI DÙNG (USERS)
  // ───────────────────────────

  /// Chỉ Admin mới được phép gửi email đặt lại mật khẩu cho user khác.
  /// Kiểm tra role của currentUser trong Firestore: users/{uid}.role == 'admin'
  Future<void> sendPasswordResetForUserAsAdmin(String targetEmail) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    // check role from Firestore
    final meDoc = await _db.collection('users').doc(current.uid).get();
    final role = (meDoc.data()?['role'] ?? '').toString().toLowerCase();

    if (role != 'admin' && role != 'it') {
      // tùy cách đặt tên role, ở đây cho phép 'admin' hoặc 'it'
      throw Exception('Chỉ Admin mới có quyền gửi email đặt lại mật khẩu.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: targetEmail.trim());
    } on FirebaseAuthException catch (e) {
      // Firebase có thể không ném lỗi nếu email không tồn tại (tránh dò tài khoản),
      // nhưng nếu có lỗi khác thì surface ra:
      throw Exception('Gửi email reset thất bại: ${e.message}');
    } catch (_) {
      throw Exception('Đã có lỗi khi gửi email đặt lại mật khẩu.');
    }
  }

  // /// Chỉ Admin mới được phép gửi email đặt lại mật khẩu cho user khác.
  // Future<void> sendPasswordResetForUserAsAdmin(String targetEmail) async {
  //   final current = _auth.currentUser;
  //   if (current == null) {
  //     throw Exception('Bạn chưa đăng nhập.');
  //   }
  //   final meDoc = await _db.collection('users').doc(current.uid).get();
  //   final role = (meDoc.data()?['role'] ?? '').toString().toLowerCase();
  //   if (role != 'admin' && role != 'it') {
  //     throw Exception('Chỉ Admin mới có quyền gửi email đặt lại mật khẩu.');
  //   }
  //   await _auth.sendPasswordResetEmail(email: targetEmail.trim());
  // }
  /// Send reset password email to a user
  Future<void> sendPasswordResetForUser(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
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

  /// Lấy danh sách người dùng theo vai trò
  Stream<List<UserModel>> getUsersStreamByRole(UserRole role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role.name)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy danh sách tất cả sinh viên
  Stream<List<UserModel>> getAllStudentsStream() {
    return getUsersStreamByRole(UserRole.student);
  }

  /// Tạo một người dùng mới (bao gồm cả Auth và Firestore)
  Future<void> createNewUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      // B1: Tạo người dùng trong Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // B2: Lấy UID từ người dùng vừa tạo
      String uid = userCredential.user!.uid;

      // B3: Cập nhật displayName trong Auth (tùy chọn nhưng nên có)
      await userCredential.user!.updateDisplayName(displayName);

      // B4: Tạo document trong collection 'users' của Firestore
      await _db.collection('users').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      // Bắt các lỗi cụ thể từ Firebase Auth để thông báo dễ hiểu hơn
      if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email này đã được sử dụng bởi một tài khoản khác.');
      }
      throw Exception('Lỗi tạo tài khoản: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Cập nhật thông tin người dùng trong Firestore
  Future<void> updateUser({
    required String uid,
    required String displayName,
    required UserRole role,
  }) {
    return _db.collection('users').doc(uid).update({
      'displayName': displayName,
      'role': role.name,
    });
  }

  /// Xoá người dùng (chỉ xoá trong Firestore)
  /// LƯU Ý: Xoá người dùng khỏi Firebase Authentication từ client là một hành động
  /// nhạy cảm và thường được thực hiện qua Cloud Functions để đảm bảo an toàn.
  /// Ở đây chúng ta chỉ xoá bản ghi trong Firestore.
  Future<void> deleteUser(String uid) {
    return _db.collection('users').doc(uid).delete();
  }
  // === QUẢN LÝ LỚP HỌC (CLASSES) ===

  /// Tạo (mở) một lớp học mới
  Future<void> createClass({
    required String courseId, // ID từ môn học đã có
    required String lecturerId, // UID của giảng viên phụ trách
    required String semester, // Ví dụ: "Học kỳ 1, 2025-2026"
    String? className, // Tên lớp cụ thể, ví dụ "L01", "L02"
  }) async {
    // Lấy thông tin của môn học và giảng viên để lưu lại
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final lecturerDoc = await _db.collection('users').doc(lecturerId).get();

    if (!courseDoc.exists || !lecturerDoc.exists) {
      throw Exception('Môn học hoặc Giảng viên không tồn tại.');
    }

    final courseData = courseDoc.data()!;
    final lecturerData = lecturerDoc.data()!;

    await _db.collection('classes').add({
      'courseId': courseId,
      'courseCode': courseData['courseCode'],
      'courseName': courseData['courseName'],
      'lecturerId': lecturerId,
      'lecturerName': lecturerData['displayName'],
      'semester': semester,
      'className': className,
      'createdAt': FieldValue.serverTimestamp(),
      // Mã tham gia sẽ được tạo bởi ClassService khi cần
      'joinCode': null,
    });
  }
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
      'isArchived': false,
    });
  }

  /// ===  Cập nhật thông tin một môn học ===
  Future<void> updateCourse({
    required String courseId,
    required String courseCode,
    required String courseName,
    required int credits,
  }) {
    return _db.collection('courses').doc(courseId).update({
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
    });
  }

  /// ===  Xoá một môn học ===
  Future<void> deleteCourse(String courseId) {
    return _db.collection('courses').doc(courseId).delete();
  }

  /// === THAY ĐỔI: Chuyển từ Xoá cứng sang Xoá mềm (Lưu trữ) ===
  /// Đánh dấu một môn học là đã được lưu trữ.
  Future<void> archiveCourse(String courseId) {
    return _db.collection('courses').doc(courseId).update({
      'isArchived': true, // Thêm một trường để đánh dấu
    });
  }

  /// === THAY ĐỔI: Lọc ra các môn học đã bị lưu trữ ===
  /// Lấy danh sách các môn học CHƯA bị lưu trữ.
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _db
        .collection('courses')
        // Query này sẽ chỉ lấy các document có isArchived != true
        // (bao gồm cả các document chưa có trường isArchived)
        .where('isArchived', isNotEqualTo: true)
        .orderBy('courseCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  // === THÊM MỚI: Hàm kiểm tra mã môn học đã tồn tại hay chưa ===
  /// Trả về `true` nếu mã môn học đã được sử dụng bởi một môn học khác.
  /// `currentCourseId` được dùng trong trường hợp Chỉnh sửa, để loại trừ chính môn học đang sửa ra khỏi
  /// việc kiểm tra.
  Future<bool> isCourseCodeTaken(String code, {String? currentCourseId}) async {
    // Luôn chuẩn hoá code trước khi query
    final normalizedCode = code.trim().toUpperCase();

    Query query = _db
        .collection('courses')
        .where('courseCode', isEqualTo: normalizedCode)
        .limit(1);

    final querySnapshot = await query.get();

    // Nếu không tìm thấy document nào, mã chắc chắn chưa tồn tại
    if (querySnapshot.docs.isEmpty) {
      return false;
    }

    // Nếu đang ở chế độ chỉnh sửa, kiểm tra xem document tìm thấy có phải là document
    // đang sửa hay không
    if (currentCourseId != null) {
      // Nếu ID của doc tìm thấy khác với ID đang sửa -> mã đã bị lấy
      return querySnapshot.docs.first.id != currentCourseId;
    }

    // Nếu đang ở chế độ tạo mới và tìm thấy document -> mã đã bị lấy
    return true;
  }
}
