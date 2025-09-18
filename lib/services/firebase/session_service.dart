import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/session_model.dart';

class SessionService {
  final _db = FirebaseFirestore.instance;

  // // Tạo buổi học mới
  // Future<String> createSession({
  //   required String classId,
  //   required String className,
  //   required String classCode,
  //   required String lecturerId,
  //   required String lecturerName,
  //   required String title,
  //   String? description,
  //   required DateTime startTime,
  //   required DateTime endTime,
  //   required String location,
  //   required SessionType type,
  // }) async {
  //   final now = DateTime.now();

  //   final ref = await _db.collection('sessions').add({
  //     'classId': classId,
  //     'className': className,
  //     'classCode': classCode,
  //     'lecturerId': lecturerId,
  //     'lecturerName': lecturerName,
  //     'title': title,
  //     'description': description,
  //     'startTime': Timestamp.fromDate(startTime),
  //     'endTime': Timestamp.fromDate(endTime),
  //     'location': location,
  //     'type': type.name,
  //     'status': SessionStatus.upcoming.name,
  //     'createdAt': Timestamp.fromDate(now),
  //     'totalStudents': 0,
  //     'attendedStudents': 0,
  //     'isAttendanceOpen': false,
  //   });

  //   return ref.id;
  // }

  // Tạo buổi học mới
  Future<String> createSession({
    required String classId,
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
      // === CÁC TRƯỜNG BỊ LOẠI BỎ ===
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'type': type.name,
      'status': SessionStatus.upcoming.name,
      'createdAt': Timestamp.fromDate(now),
      'isAttendanceOpen': false,
    });

    return ref.id;
  }

  // /// Lấy danh sách các buổi học ĐÃ ĐƯỢỢC LÊN LỊCH (chưa bắt đầu) của một lớp
  // Stream<List<SessionModel>> getScheduledSessionsForClass(String classId) {
  //   return _db
  //       .collection('sessions')
  //       .where('classId', isEqualTo: classId)
  //       // Chỉ lấy những buổi có trạng thái là 'scheduled'
  //       .where('status', isEqualTo: SessionStatus.scheduled.name)
  //       .orderBy('startTime') // Sắp xếp theo thời gian bắt đầu
  //       .snapshots()
  //       .map(
  //         (snapshot) => snapshot.docs
  //             .map((doc) => SessionModel.fromFirestore(doc))
  //             .toList(),
  //       );
  // }

  // /// Kích hoạt trạng thái điểm danh cho một buổi học cụ thể
  // Future<void> startAttendanceForSession(String sessionId) async {
  //   try {
  //     await _db.collection('sessions').doc(sessionId).update({
  //       // Chuyển trạng thái sang 'đang diễn ra'
  //       'status': SessionStatus.inProgress.name,
  //       // Có thể lưu lại thời gian bắt đầu thực tế nếu cần
  //       'actualStartTime': FieldValue.serverTimestamp(),
  //     });
  //   } catch (e) {
  //     throw Exception('Không thể bắt đầu buổi học: $e');
  //   }
  // }

  /// Ghi nhận điểm danh cho sinh viên
  Future<void> markAttendance({
    required String
    classId, // Vẫn cần classId để kiểm tra logic sau này nếu muốn
    required String sessionId,
    required String studentId,
  }) async {
    try {
      // SỬA LỖI: Đường dẫn đúng là collection 'sessions' ở cấp cao nhất
      final sessionRef = _db.collection('sessions').doc(sessionId);

      final sessionSnap = await sessionRef.get();

      if (!sessionSnap.exists) {
        throw Exception("Buổi học không tồn tại!");
      }

      final data = sessionSnap.data() as Map<String, dynamic>;

      // Kiểm tra xem điểm danh có đang mở không
      if (data['isAttendanceOpen'] != true) {
        throw Exception("Giảng viên chưa mở điểm danh cho buổi học này.");
      }

      // (Tùy chọn) Kiểm tra buổi học còn hiệu lực
      if (data.containsKey('endTime')) {
        final endTime = (data['endTime'] as Timestamp).toDate();
        if (DateTime.now().isAfter(endTime)) {
          throw Exception("Đã hết thời gian điểm danh!");
        }
      }

      // Lưu điểm danh vào sub-collection 'attendances' của buổi học
      await sessionRef.collection('attendances').doc(studentId).set({
        'studentId': studentId,
        'attendTime': FieldValue.serverTimestamp(),
        'status': 'present',
      });
    } catch (e) {
      // Ném lại lỗi để UI có thể bắt và hiển thị
      rethrow;
    }
  }

  /// Cập nhật trạng thái điểm danh của một sinh viên
  Future<void> updateAttendanceStatus({
    required String sessionId,
    required String studentId,
    required String newStatus,
  }) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .doc(studentId)
        .update({'status': newStatus});
  }

  // Thêm hàm điểm danh thủ công
  Future<void> addManualAttendance({
    required String sessionId,
    required String studentId,
  }) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'attendTime': FieldValue.serverTimestamp(),
          'status': 'present', // Mặc định là có mặt
        }, SetOptions(merge: true));
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

  /// Lấy danh sách sinh viên đã điểm danh cho một buổi học cụ thể
  Stream<List<Map<String, dynamic>>> getAttendanceList(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .orderBy(
          'attendTime',
          descending: false,
        ) // Sắp xếp theo thời gian điểm danh
        .snapshots()
        .map((snapshot) {
          // Lấy dữ liệu từ mỗi document điểm danh
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // THÊM THÔNG TIN CỦA SINH VIÊN VÀO ĐÂY (SẼ LÀM Ở BƯỚC NÂNG CẤP)
            // Hiện tại, chúng ta chỉ lấy dữ liệu gốc
            return data;
          }).toList();
        });
  }

  /// Lấy danh sách sinh viên đã điểm danh (kèm thông tin chi tiết của sinh viên)
  Stream<List<Map<String, dynamic>>> getRichAttendanceList(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .orderBy('attendTime', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            return []; // Trả về danh sách rỗng nếu chưa có ai điểm danh
          }

          // Tạo một danh sách các "công việc" cần làm: lấy thông tin user cho mỗi studentId
          final userFutures = snapshot.docs.map((doc) async {
            final attendanceData = doc.data();
            final studentId = attendanceData['studentId'];

            try {
              // Lấy thông tin từ collection 'users'
              final userDoc = await _db
                  .collection('users')
                  .doc(studentId)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                // Gộp thông tin điểm danh và thông tin user lại với nhau
                return {
                  ...attendanceData,
                  'studentName': userData['displayName'],
                  'studentEmail': userData['email'],
                };
              }
            } catch (e) {
              // Bỏ qua nếu không tìm thấy user, tránh làm crash cả stream
              print('Error fetching user $studentId: $e');
            }
            // Trả về dữ liệu gốc nếu không tìm thấy user
            return attendanceData;
          }).toList();

          // Chạy tất cả các "công việc" song song và đợi kết quả
          return await Future.wait(userFutures);
        });
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
