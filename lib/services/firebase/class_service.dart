import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/class_model.dart';

class ClassService {
  final _db = FirebaseFirestore.instance;

  String _randomCode([int len = 6]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // Tạo lớp (admin chọn GV hoặc GV tự tạo cho mình)
  Future<String> createClass({
    required String lecturerId,
    required String lecturerName,
    required String lecturerEmail,
    required String className,
    required String classCode,
    required List<ClassSchedule> schedules,
    required int maxAbsences,
  }) async {
    final joinCode = _randomCode();
    final now = DateTime.now();

    final ref = await _db.collection('classes').add({
      'className': className,
      'classCode': classCode,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'lecturerEmail': lecturerEmail,
      'schedules': schedules.map((e) => e.toMap()).toList(),
      'maxAbsences': maxAbsences,
      'joinCode': joinCode,
      'createdAt': now, // hiển thị tức thì
      'createdAtServer': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> enrollStudent({
    required String joinCode,
    required String studentUid,
    required String studentName,
    required String studentEmail,
  }) async {
    // 1. Tìm lớp học có mã tham gia tương ứng
    final classQuery = await _db
        .collection('classes')
        .where('joinCode', isEqualTo: joinCode.trim())
        .limit(1)
        .get();

    if (classQuery.docs.isEmpty) {
      throw Exception('Mã tham gia không hợp lệ hoặc lớp học không tồn tại.');
    }

    final classDoc = classQuery.docs.first;
    final classId = classDoc.id;

    // 2. Tạo một bản ghi trong collection 'enrollments'
    // Đường dẫn: enrollments/{enrollment_id}
    // Dùng doc().set() để tự sinh ID cho bản ghi enrollment
    await _db.collection('enrollments').add({
      'classId': classId,
      'className': classDoc
          .data()['className'], // Lưu thêm thông tin lớp để dễ truy vấn
      'studentUid': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'joinDate': FieldValue.serverTimestamp(),
    });
  }

  /// Lấy tổng số sinh viên đã tham gia một lớp học
  Future<int> getEnrolledStudentCount(String classId) async {
    try {
      final snapshot = await _db
          .collection('enrollments')
          .where('classId', isEqualTo: classId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting student count: $e');
      return 0;
    }
  }

  // Lấy danh sách chi tiết các sinh viên đã tham gia lớp
  Future<List<Map<String, dynamic>>> getEnrolledStudents(String classId) async {
    final enrollmentSnap = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .get();
    if (enrollmentSnap.docs.isEmpty) return [];

    final userFutures = enrollmentSnap.docs.map((doc) async {
      final studentId = doc.data()['studentUid'];
      final userDoc = await _db.collection('users').doc(studentId).get();
      return userDoc.exists ? userDoc.data()! : null;
    }).toList();

    final users = await Future.wait(userFutures);
    return users
        .where((user) => user != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // === Streams cho Admin/Lecturer/Student ===
  Stream<List<ClassModel>> allClasses() {
    return _db
        .collection('classes')
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClassModel.fromDoc(d)).toList());
  }

  Stream<List<ClassModel>> classesOfLecturer(String lecturerUid) {
    return _db
        .collection('classes')
        .where('lecturerId', isEqualTo: lecturerUid)
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClassModel.fromDoc(d)).toList());
  }

  /// Student: lấy các lớp mà SV đã enroll (collection 'enrollments')
  /// enrollments doc: { classId, studentUid, joinedAt }
  Stream<List<ClassModel>> classesOfStudent(String studentUid) {
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .asyncMap((enrollSnap) async {
          final futures = enrollSnap.docs.map((e) async {
            final classId = (e.data()['classId'] as String);
            final cDoc = await _db.collection('classes').doc(classId).get();
            if (!cDoc.exists) return null;
            return ClassModel.fromDoc(cDoc);
          });
          final list = await Future.wait(futures);
          return list.whereType<ClassModel>().toList();
        });
  }

  // Chi tiết lớp & members
  Stream<ClassModel> classStream(String classId) => _db
      .collection('classes')
      .doc(classId)
      .snapshots()
      .map(ClassModel.fromDoc);

  Stream<List<Map<String, dynamic>>> membersStream(String classId) {
    return _db
        .collection('classes')
        .doc(classId)
        .collection('members')
        // .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> removeMember(String classId, String uid) async {
    await _db
        .collection('classes')
        .doc(classId)
        .collection('members')
        .doc(uid)
        .delete();
  }

  Future<void> regenerateJoinCode(String classId) async {
    await _db.collection('classes').doc(classId).update({
      'joinCode': _randomCode(),
    });
  }

  // Admin filter: danh sách giảng viên (users.role == 'lecture')
  Stream<List<Map<String, String>>> lecturersStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'lecture')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final m = d.data();
            return {
              'uid': d.id,
              'name': (m['displayName'] ?? '') as String,
              'email': (m['email'] ?? '') as String,
            };
          }).toList(),
        );
  }
}
