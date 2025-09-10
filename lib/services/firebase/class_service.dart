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
