// lib/features/schedule/data/services/schedule_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleService {
  final _db = FirebaseFirestore.instance;

  // ---- Helpers ----
  DateTime? _toDT(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  List<Map<String, dynamic>> _snapToList(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs.map((d) {
      final data = d.data();
      final start = _toDT(data['startTime']);
      final end = _toDT(data['endTime']);
      return {
        'id': d.id,
        ...data,
        // UI dùng startTime/endTime
        'startTime': start,
        'endTime': end,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchByCourseCodes({
    required List<String> courseCodes,
    required DateTime from,
    required DateTime to,
  }) async {
    if (courseCodes.isEmpty) return [];

    // Firestore whereIn tối đa 10
    final chunks = <List<String>>[];
    for (var i = 0; i < courseCodes.length; i += 10) {
      chunks.add(
        courseCodes.sublist(
          i,
          i + 10 > courseCodes.length ? courseCodes.length : i + 10,
        ),
      );
    }

    final results = <Map<String, dynamic>>[];

    for (final ids in chunks) {
      final q = _db
          .collection('sessions')
          .where('courseCode', whereIn: ids)
          .where('startTime', isGreaterThanOrEqualTo: from)
          .where('startTime', isLessThan: to) // < to để không trùng biên
          .orderBy('startTime');

      final snap = await q.get();
      results.addAll(_snapToList(snap));
    }

    // Loại trùng theo id + sort theo startTime
    final map = <String, Map<String, dynamic>>{};
    for (final s in results) {
      map[s['id'] as String] = s;
    }
    final merged = map.values.toList()
      ..sort((a, b) {
        final sa =
            (a['startTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final sb =
            (b['startTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return sa.compareTo(sb);
      });

    return merged;
  }

  // ---- Giảng viên: lấy courseCode từ 'coursees' rồi query 'sessions' theo courseCode ----
  Stream<List<Map<String, dynamic>>> lecturerSessions({
    required String lecturerUid,
    required DateTime from,
    required DateTime to,
  }) {
    final courseesQ = _db
        .collection('coursees')
        .where('lecturerId', isEqualTo: lecturerUid)
        .where('isArchived', isEqualTo: false);

    return courseesQ.snapshots().asyncMap((clsSnap) async {
      final courseCodes = clsSnap.docs.map((e) => e.id).toList();
      return _fetchByCourseCodes(courseCodes: courseCodes, from: from, to: to);
    });
  }

  // ---- Sinh viên: lấy courseCode từ 'enrollments' rồi query 'sessions' theo courseCode ----
  Stream<List<Map<String, dynamic>>> studentSessions({
    required String studentId,
    required DateTime from,
    required DateTime to,
  }) {
    final enrollsQ = _db
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .limit(200);

    return enrollsQ.snapshots().asyncMap((enSnap) async {
      final courseCodes = enSnap.docs
          .map((e) => (e.data()['courseCode'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      return _fetchByCourseCodes(courseCodes: courseCodes, from: from, to: to);
    });
  }
}
