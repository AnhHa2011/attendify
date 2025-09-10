import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/session_model.dart';

class SessionService {
  final _db = FirebaseFirestore.instance;

  // Tạo buổi học mới
  Future<String> createSession({
    required String classId,
    required String className,
    required String classCode,
    required String lecturerId,
    required String lecturerName,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required SessionType type,
  }) async {
    final now = DateTime.now();

    final ref = await _db.collection('sessions').add({
      'classId': classId,
      'className': className,
      'classCode': classCode,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'type': type.name,
      'status': SessionStatus.upcoming.name,
      'createdAt': Timestamp.fromDate(now),
      'totalStudents': 0,
      'attendedStudents': 0,
      'isAttendanceOpen': false,
    });

    return ref.id;
  }

  // Lấy tất cả buổi học
  Stream<List<SessionModel>> allSessions() {
    return _db
        .collection('sessions')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  // Lấy buổi học của giảng viên
  Stream<List<SessionModel>> sessionsOfLecturer(String lecturerId) {
    return _db
        .collection('sessions')
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  // Lấy buổi học của lớp
  Stream<List<SessionModel>> sessionsOfClass(String classId) {
    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  // Lấy buổi học của sinh viên (từ các lớp đã đăng ký)
  Stream<List<SessionModel>> sessionsOfStudent(String studentUid) {
    // Lấy danh sách classId mà sinh viên đã đăng ký
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

          final classIds = enrollmentSnapshot.docs
              .map((doc) => doc.data()['classId'] as String)
              .toList();

          // Lấy sessions của các lớp đó
          final sessionSnapshot = await _db
              .collection('sessions')
              .where('classId', whereIn: classIds)
              .orderBy('startTime', descending: false)
              .get();

          return sessionSnapshot.docs
              .map((doc) => SessionModel.fromDoc(doc))
              .toList();
        });
  }

  // Lấy buổi học tiếp theo của user (lecturer hoặc student)
  Future<SessionModel?> getNextSession(
    String userId, {
    bool isLecturer = false,
  }) async {
    final now = DateTime.now();

    Query query;
    if (isLecturer) {
      query = _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: false)
          .limit(1);
    } else {
      // Cho student, cần lấy từ enrollments trước
      final enrollmentSnapshot = await _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .get();

      if (enrollmentSnapshot.docs.isEmpty) return null;

      final classIds = enrollmentSnapshot.docs
          .map((doc) => doc.data()['classId'] as String)
          .toList();

      if (classIds.isEmpty) return null;

      query = _db
          .collection('sessions')
          .where('classId', whereIn: classIds)
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: false)
          .limit(1);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;

    return SessionModel.fromDoc(
      snapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
    );
  }

  // Lấy buổi học hôm nay
  Stream<List<SessionModel>> getTodaySessions(
    String userId, {
    bool isLecturer = false,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (isLecturer) {
      return _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('startTime', descending: false)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
          );
    } else {
      // Cho student
      return _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final classIds = enrollmentSnapshot.docs
                .map((doc) => doc.data()['classId'] as String)
                .toList();

            if (classIds.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('classId', whereIn: classIds)
                .where(
                  'startTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
                )
                .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
                .orderBy('startTime', descending: false)
                .get();

            return sessionSnapshot.docs
                .map((doc) => SessionModel.fromDoc(doc))
                .toList();
          });
    }
  }

  // Lấy thời khóa biểu tuần
  Stream<List<SessionModel>> getWeeklySchedule(
    String userId,
    DateTime weekStart, {
    bool isLecturer = false,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));

    if (isLecturer) {
      return _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
          .orderBy('startTime', descending: false)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
          );
    } else {
      return _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final classIds = enrollmentSnapshot.docs
                .map((doc) => doc.data()['classId'] as String)
                .toList();

            if (classIds.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('classId', whereIn: classIds)
                .where(
                  'startTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
                )
                .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
                .orderBy('startTime', descending: false)
                .get();

            return sessionSnapshot.docs
                .map((doc) => SessionModel.fromDoc(doc))
                .toList();
          });
    }
  }

  // Cập nhật trạng thái buổi học
  Future<void> updateSessionStatus(
    String sessionId,
    SessionStatus status,
  ) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Mở/đóng điểm danh
  Future<void> toggleAttendance(String sessionId, bool isOpen) async {
    await _db.collection('sessions').doc(sessionId).update({
      'isAttendanceOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Xóa buổi học
  Future<void> deleteSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).delete();
  }

  // Lấy thống kê buổi học
  Future<Map<String, int>> getSessionStats(
    String userId, {
    bool isLecturer = false,
  }) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    Query query;
    if (isLecturer) {
      query = _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          );
    } else {
      // Cần implement cho student
      return {'total': 0, 'completed': 0, 'upcoming': 0, 'cancelled': 0};
    }

    final snapshot = await query.get();
    final sessions = snapshot.docs
        .map(
          (doc) => SessionModel.fromDoc(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .toList();

    return {
      'total': sessions.length,
      'completed': sessions
          .where((s) => s.status == SessionStatus.completed)
          .length,
      'upcoming': sessions
          .where((s) => s.status == SessionStatus.upcoming)
          .length,
      'cancelled': sessions
          .where((s) => s.status == SessionStatus.cancelled)
          .length,
    };
  }
}
