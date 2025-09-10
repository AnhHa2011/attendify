import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/class_model.dart';
import '../../services/firebase/class_service.dart';

class ClassProvider extends ChangeNotifier {
  final ClassService _svc;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ClassProvider(this._svc);

  /// Lớp của CHÍNH giảng viên đang đăng nhập
  Stream<List<ClassModel>> myClasses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _svc.classesOfLecturer(uid);
  }

  /// Lớp của một giảng viên bất kỳ (dùng cho Admin filter)
  Stream<List<ClassModel>> classesOfLecturer(String lecturerUid) {
    return _svc.classesOfLecturer(lecturerUid);
  }

  /// TẤT CẢ lớp (dùng cho Admin)
  Stream<List<ClassModel>> allClasses() => _svc.allClasses();

  /// Tạo lớp cho *giảng viên nào đó*
  Future<String> createForLecturer({
    required String lecturerId,
    required String lecturerName,
    required String lecturerEmail,
    required String className,
    required String classCode,
    required List<ClassSchedule> schedules,
    required int maxAbsences,
  }) {
    return _svc.createClass(
      lecturerId: lecturerId,
      lecturerName: lecturerName,
      lecturerEmail: lecturerEmail,
      className: className,
      classCode: classCode,
      schedules: schedules,
      maxAbsences: maxAbsences,
    );
  }

  Stream<ClassModel> classDetail(String classId) => _svc.classStream(classId);
  Stream<List<Map<String, dynamic>>> members(String classId) =>
      _svc.membersStream(classId);
  Future<void> regenerateJoinCode(String classId) =>
      _svc.regenerateJoinCode(classId);

  /// 🔧 BỔ SUNG: Xoá sinh viên khỏi lớp (để ClassDetailPage gọi được)
  Future<void> removeMember(String classId, String uid) =>
      _svc.removeMember(classId, uid);

  // Dành cho Admin UI
  Stream<List<Map<String, String>>> lecturers() => _svc.lecturersStream();
}
