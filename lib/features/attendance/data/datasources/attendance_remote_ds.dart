import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceRemoteDS {
  final _fs = FirebaseFirestore.instance;

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;
  // Lấy tất cả sessions của lớp + status của 1 SV
  Future<
    List<({String sessionId, DateTime start, String name, AttendanceModel att})>
  >
  historyForStudentInClass({
    required String classCode,
    required String studentId,
  }) async {
    final sSnap = await _fs
        .collection('sessions')
        .where('classCode', isEqualTo: classCode)
        .get();

    final items =
        <
          ({String sessionId, DateTime start, String name, AttendanceModel att})
        >[];

    for (final s in sSnap.docs) {
      final m = s.data();
      final start = (m['startTime'] as Timestamp?)?.toDate() ?? DateTime(0);
      final name = (m['name'] ?? 'Buổi ${m['order'] ?? ''}').toString();
      final attSnap = await _fs
          .collection('classes')
          .doc(classCode)
          .collection('sessions')
          .doc(s.id)
          .collection('attendances')
          .doc(studentId)
          .get();
      final att = AttendanceModel.fromMap(attSnap.data());
      items.add((sessionId: s.id, start: start, name: name, att: att));
    }

    // sort theo thời gian
    items.sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  Future<List<Map<String, dynamic>>> historyForStudent({
    required String classCode,
    required String studentId,
  }) async {
    final now = DateTime.now();

    // 1) Lấy tất cả sessions của lớp
    final sSnap = await _fs
        .collection('sessions')
        .where('classCode', isEqualTo: classCode)
        .orderBy('startTime')
        .get();

    // 2) Lấy tất cả đơn xin nghỉ của SV trong lớp này
    final leaveSnap = await _fs
        .collection('leave_requests')
        .where('studentId', isEqualTo: studentId)
        .where('classCode', isEqualTo: classCode)
        .get();

    final leaveSessionIds = leaveSnap.docs
        .map((d) => d['sessionId'] as String)
        .toSet();

    final results = <Map<String, dynamic>>[];
    for (final s in sSnap.docs) {
      final m = s.data();
      final start = (m['startTime'] as Timestamp?)?.toDate() ?? DateTime(0);

      // Điều kiện lọc
      final isPast = !start.isAfter(now); // buổi đã qua
      final hasLeave = leaveSessionIds.contains(s.id); // có đơn xin nghỉ

      if (isPast || hasLeave) {
        final attSnap = await _fs
            .collection('classes')
            .doc(classCode)
            .collection('sessions')
            .doc(s.id)
            .collection('attendances')
            .doc(studentId)
            .get();

        final att = attSnap.exists
            ? AttendanceModel.fromDoc(attSnap)
            : AttendanceModel(status: 'absent');

        results.add({
          'sessionId': s.id,
          'sessionName': m['name'] ?? 'Buổi ${m['order'] ?? ''}',
          'startTime': start,
          'attendance': att,
        });
      }
    }

    results.sort((a, b) => a['startTime'].compareTo(b['startTime']));
    return results;
  }
}
