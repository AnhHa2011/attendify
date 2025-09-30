import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../models/user_model.dart';

class SessionService {
  final _db = FirebaseFirestore.instance;

  // Tạo buổi học mới - Updated to match exact SessionModel requirements
  Future<String> createSession({
    required String courseCode,
    String? courseName,
    String? lecturerId,
    String? lecturerName,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required SessionType type,
  }) async {
    final now = DateTime.now();

    final ref = await _db.collection('sessions').add({
      'courseCode': courseCode,
      'courseName': courseName ?? '',
      'lecturerId': lecturerId ?? '',
      'lecturerName': lecturerName ?? '',
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'type': type.name,
      'status': SessionStatus.scheduled.name,
      'createdAt': Timestamp.fromDate(now),
      'totalStudents': 0,
      'attendedStudents': 0,
      'isOpen': false, // Match SessionModel field name
      'qrCode': null,
      'attendanceStatus': <String, String>{},
    });

    return ref.id;
  }

  /// Lấy danh sách các buổi học ĐÃ ĐƯỢC LÊN LỊCH của một lớp
  Stream<List<SessionModel>> getScheduledSessionsForCourse(String courseCode) {
    return _db
        .collection('sessions')
        .where('courseCode', isEqualTo: courseCode)
        .where('status', isEqualTo: SessionStatus.scheduled.name)
        .orderBy('startTime')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  /// Kích hoạt điểm danh và đặt thời gian tự động đóng
  Future<void> startAttendanceForSession(String sessionId) async {
    final autoCloseTime = DateTime.now().add(const Duration(hours: 2));

    await _db.collection('sessions').doc(sessionId).update({
      'status': SessionStatus.inProgress.name,
      'actualStartTime': Timestamp.now().toDate(),
      'isOpen': true, // Use isOpen field name
      'attendanceAutoCloseTime': Timestamp.fromDate(autoCloseTime),
    });
  }

  /// Lấy các buổi học có thể điểm danh
  Stream<List<SessionModel>> getAttendableSessionsForCourse(String courseCode) {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _db
        .collection('sessions')
        .where('courseCode', isEqualTo: courseCode)
        .where(
          'status',
          whereIn: [
            SessionStatus.scheduled.name,
            SessionStatus.inProgress.name,
          ],
        )
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  /// Lắng nghe thay đổi của một buổi học cụ thể
  Stream<SessionModel> getSessionStream(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => SessionModel.fromDoc(doc));
  }

  /// Bật/tắt điểm danh cho buổi học
  Future<void> toggleAttendance(String sessionId, bool isOpen) {
    return _db.collection('sessions').doc(sessionId).update({
      'isOpen': isOpen, // Use exact field name from SessionModel
    });
  }

  /// Ghi nhận điểm danh cho sinh viên khi quét QR
  Future<void> markAttendance({
    required String sessionId,
    required String studentId,
  }) async {
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();

    if (!sessionDoc.exists) {
      throw Exception('Buổi học không tồn tại.');
    }

    final sessionData = sessionDoc.data()!;
    // Check isOpen field (supporting fallback for old data)
    final isAttendanceOpen =
        sessionData['isOpen'] ??
        sessionData['isAttendanceOpen'] ??
        sessionData['attendanceOpen'] ??
        false;

    if (!isAttendanceOpen) {
      throw Exception('Giảng viên chưa mở hoặc đã đóng điểm danh.');
    }

    // Kiểm tra thời gian hết hạn
    final autoCloseTimestamp =
        sessionData['attendanceAutoCloseTime'] as Timestamp?;
    if (autoCloseTimestamp != null &&
        DateTime.now().isAfter(autoCloseTimestamp.toDate())) {
      await sessionRef.update({'isOpen': false});
      throw Exception('Đã hết thời gian điểm danh cho buổi học này.');
    }

    // Kiểm tra đã điểm danh chưa
    final attendanceQuery = await _db
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (attendanceQuery.docs.isNotEmpty) {
      throw Exception('Bạn đã điểm danh cho buổi học này rồi.');
    }

    // Tạo bản ghi điểm danh
    await _db.collection('attendance').add({
      'sessionId': sessionId,
      'studentId': studentId,
      'status': 'present',
      'timestamp': Timestamp.now().toDate(),
      'method': 'qr_code',
    });

    // Cập nhật subcollection để backward compatibility
    await sessionRef.collection('attendees').doc(studentId).set({
      'studentId': studentId,
      'timestamp': Timestamp.now().toDate(),
      'status': 'present',
      'method': 'qr_code',
    });
  }

  /// Thêm điểm danh thủ công
  Future<void> addManualAttendance({
    required String sessionId,
    required String studentId,
  }) async {
    // Thêm vào collection chính
    await _db.collection('attendance').add({
      'sessionId': sessionId,
      'studentId': studentId,
      'status': 'present',
      'timestamp': Timestamp.now().toDate(),
      'method': 'manual',
    });

    // Cập nhật subcollection
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'timestamp': Timestamp.now().toDate(),
          'status': 'present',
          'method': 'manual',
        });
  }

  /// Lấy danh sách sinh viên đã điểm danh với thông tin đầy đủ
  Stream<List<Map<String, dynamic>>> getRichAttendanceList(String sessionId) {
    return _db
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];

          final studentIds = snapshot.docs
              .map((doc) => doc.data()['studentId'] as String)
              .toSet()
              .toList();

          if (studentIds.isEmpty) return [];

          final userDocs = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();

          final userMap = {
            for (var doc in userDocs.docs) doc.id: UserModel.fromDoc(doc),
          };

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final studentId = data['studentId'] as String;
            final student = userMap[studentId];
            return {
              'studentId': studentId,
              'displayName': student?.displayName ?? 'N/A',
              'email': student?.email ?? 'N/A',
              'timestamp': data['timestamp'],
              'status': data['status'],
              'method': data['method'],
            };
          }).toList();
        });
  }

  /// Cập nhật trạng thái điểm danh
  Future<void> updateAttendanceStatus({
    required String sessionId,
    required String studentId,
    required String newStatus,
  }) async {
    // Cập nhật trong collection chính
    final attendanceQuery = await _db
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (attendanceQuery.docs.isNotEmpty) {
      await attendanceQuery.docs.first.reference.update({
        'status': newStatus,
        'timestamp': Timestamp.now().toDate(),
      });
    } else {
      await _db.collection('attendance').add({
        'sessionId': sessionId,
        'studentId': studentId,
        'status': newStatus,
        'timestamp': Timestamp.now().toDate(),
        'method': 'manual',
      });
    }

    // Cập nhật subcollection
    final attendeeRef = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .doc(studentId);

    await attendeeRef.set({
      'status': newStatus,
      'studentId': studentId,
      'timestamp': Timestamp.now().toDate(),
      'method': 'manual',
    }, SetOptions(merge: true));
  }

  // /// Lấy danh sách TẤT CẢ sinh viên trong lớp với trạng thái điểm danh
  // Stream<List<Map<String, dynamic>>> getFullStudentListWithStatus({
  //   required String sessionId,
  //   required String courseCode,
  // }) {
  //   // Lắng nghe attendance records
  //   final attendeesStream = _db
  //       .collection('attendances')
  //       .where('sessionId', isEqualTo: sessionId)
  //       .snapshots();

  //   // Lấy danh sách sinh viên trong lớp
  //   final allStudentsFuture = _db
  //       .collection('enrollments')
  //       .where('courseCode', isEqualTo: courseCode)
  //       .get()
  //       .then((snapshot) async {
  //         if (snapshot.docs.isEmpty) {
  //           // Fallback to courseCode
  //           final fallbackSnapshot = await _db
  //               .collection('enrollments')
  //               .where('courseCode', isEqualTo: courseCode)
  //               .get();
  //           snapshot = fallbackSnapshot;
  //         }

  //         if (snapshot.docs.isEmpty) return <UserModel>[];

  //         final studentIds = snapshot.docs
  //             .map(
  //               (doc) =>
  //                   doc.data()['studentId'] as String? ??
  //                   doc.data()['studentId'] as String? ??
  //                   '',
  //             )
  //             .where((id) => id.isNotEmpty)
  //             .toList();

  //         if (studentIds.isEmpty) return <UserModel>[];

  //         final studentsSnapshot = await _db
  //             .collection('users')
  //             .where(FieldPath.documentId, whereIn: studentIds)
  //             .get();

  //         return studentsSnapshot.docs
  //             .map((doc) => UserModel.fromDoc(doc))
  //             .toList();
  //       });

  //   // Kết hợp dữ liệu
  //   return attendeesStream.asyncMap((attendeesSnapshot) async {
  //     final allStudents = await allStudentsFuture;
  //     final attendedMap = <String, Map<String, dynamic>>{};

  //     for (var doc in attendeesSnapshot.docs) {
  //       final data = doc.data();
  //       final studentId = data['studentId'] as String;
  //       attendedMap[studentId] = data;
  //     }

  //     final fullList = allStudents.map((student) {
  //       final attendanceData = attendedMap[student.uid];
  //       return {
  //         'uid': student.uid,
  //         'displayName': student.displayName,
  //         'email': student.email,
  //         'status': attendanceData?['status'] ?? 'absent',
  //         'timestamp': attendanceData?['timestamp'],
  //         'method': attendanceData?['method'],
  //       };
  //     }).toList();

  //     // Sắp xếp: có mặt trước, tên theo thứ tự
  //     fullList.sort((a, b) {
  //       if (a['status'] != 'absent' && b['status'] == 'absent') return -1;
  //       if (a['status'] == 'absent' && b['status'] != 'absent') return 1;
  //       return (a['displayName'] as String).compareTo(
  //         b['displayName'] as String,
  //       );
  //     });

  //     return fullList;
  //   });
  // }

  /// Lấy danh sách TẤT CẢ sinh viên trong lớp với trạng thái điểm danh
  Stream<List<Map<String, dynamic>>> getFullStudentListWithStatus({
    required String sessionId,
    required String courseCode,
  }) {
    // SỬA LỖI 1: Đổi tên collection từ 'attendances' thành 'attendance' cho đúng
    final attendeesStream = _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots();

    // Tối ưu: Lấy danh sách sinh viên của lớp một lần duy nhất
    final Future<List<UserModel>> allStudentsFuture = _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .get()
        .then((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) {
            return <UserModel>[]; // Không có sinh viên nào đăng ký
          }

          // Rút gọn: Lấy danh sách studentId một cách an toàn
          final studentIds = enrollmentSnapshot.docs
              .map((doc) => doc.data()['studentId'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toList();

          if (studentIds.isEmpty) {
            return <UserModel>[];
          }

          // Lấy thông tin user từ danh sách Ids
          final studentsSnapshot = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();

          return studentsSnapshot.docs
              .map((doc) => UserModel.fromDoc(doc))
              .toList();
        });

    // Kết hợp dữ liệu: Giữ nguyên logic kết hợp và sắp xếp của bạn vì nó đã tốt
    return attendeesStream.asyncMap((attendeesSnapshot) async {
      final allStudents = await allStudentsFuture;
      if (allStudents.isEmpty) return [];

      final attendedMap = <String, Map<String, dynamic>>{};

      for (var doc in attendeesSnapshot.docs) {
        final data = doc.data();
        if (data['studentId'] is String) {
          attendedMap[data['studentId']] = data;
        }
      }

      final fullList = allStudents.map((student) {
        final attendanceData = attendedMap[student.uid];
        return {
          'uid': student.uid,
          'displayName': student.displayName,
          'email': student.email,
          'status': attendanceData?['status'] ?? 'absent',
          'timestamp': attendanceData?['timestamp'],
          'method': attendanceData?['method'],
        };
      }).toList();

      // Giữ nguyên logic sắp xếp của bạn
      fullList.sort((a, b) {
        final statusA = a['status'] as String;
        final statusB = b['status'] as String;
        final displayNameA = a['displayName'] as String;
        final displayNameB = b['displayName'] as String;

        if (statusA != 'absent' && statusB == 'absent') return -1;
        if (statusA == 'absent' && statusB != 'absent') return 1;
        return displayNameA.compareTo(displayNameB);
      });

      return fullList;
    });
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

  /// Lấy danh sách điểm danh cho buổi học
  Stream<List<Map<String, dynamic>>> getAttendanceList(String sessionId) {
    return _db
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];

          final studentIds = snapshot.docs
              .map((doc) => doc.data()['studentId'] as String)
              .toSet()
              .toList();

          if (studentIds.isEmpty) return [];

          final userDocs = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();

          final userMap = {
            for (var doc in userDocs.docs) doc.id: UserModel.fromDoc(doc),
          };

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final studentId = data['studentId'] as String;
            final student = userMap[studentId];
            return {
              'studentId': studentId,
              'displayName': student?.displayName ?? 'N/A',
              'email': student?.email ?? 'N/A',
              'status': data['status'],
              'timestamp': data['timestamp'],
              'method': data['method'],
            };
          }).toList();
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
  Stream<List<SessionModel>> sessionsOfCourse(String courseCode) {
    return _db
        .collection('sessions')
        .where('courseCode', isEqualTo: courseCode)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  // Lấy buổi học của sinh viên
  Stream<List<SessionModel>> sessionsOfStudent(String studentId) {
    return _db
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) {
            // Fallback to studentId
            final fallbackSnapshot = await _db
                .collection('enrollments')
                .where('studentId', isEqualTo: studentId)
                .get();
            enrollmentSnapshot = fallbackSnapshot;
          }

          if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

          final courseCodes = enrollmentSnapshot.docs
              .map((doc) => doc.data()['courseCode'] as String? ?? '')
              .where((code) => code.isNotEmpty)
              .toList();

          if (courseCodes.isEmpty) return <SessionModel>[];

          // Query sessions using courseCode field
          final sessionSnapshot = await _db
              .collection('sessions')
              .where('courseCode', whereIn: courseCodes)
              .orderBy('startTime', descending: false)
              .get();

          return sessionSnapshot.docs
              .map((doc) => SessionModel.fromDoc(doc))
              .toList();
        });
  }

  // Lấy buổi học tiếp theo
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
      final enrollmentSnapshot = await _db
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .get();

      if (enrollmentSnapshot.docs.isEmpty) {
        final fallbackSnapshot = await _db
            .collection('enrollments')
            .where('studentId', isEqualTo: userId)
            .get();

        if (fallbackSnapshot.docs.isEmpty) return null;
      }

      final courseCodes = enrollmentSnapshot.docs
          .map((doc) => doc.data()['courseCode'] as String? ?? '')
          .where((code) => code.isNotEmpty)
          .toList();

      if (courseCodes.isEmpty) return null;

      query = _db
          .collection('sessions')
          .where('courseCode', whereIn: courseCodes)
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
      return _db
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) {
              final fallbackSnapshot = await _db
                  .collection('enrollments')
                  .where('studentId', isEqualTo: userId)
                  .get();
              enrollmentSnapshot = fallbackSnapshot;
            }

            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final courseCodes = enrollmentSnapshot.docs
                .map((doc) => doc.data()['courseCode'] as String? ?? '')
                .where((code) => code.isNotEmpty)
                .toList();

            if (courseCodes.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('courseCode', whereIn: courseCodes)
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
          .where('studentId', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) {
              final fallbackSnapshot = await _db
                  .collection('enrollments')
                  .where('studentId', isEqualTo: userId)
                  .get();
              enrollmentSnapshot = fallbackSnapshot;
            }

            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final courseCodes = enrollmentSnapshot.docs
                .map((doc) => doc.data()['courseCode'] as String? ?? '')
                .where((code) => code.isNotEmpty)
                .toList();

            if (courseCodes.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('courseCode', whereIn: courseCodes)
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
      'updatedAt': Timestamp.now().toDate(),
    });
  }

  // Xóa buổi học
  Future<void> deleteSession(String sessionId) async {
    // Xóa attendance records liên quan
    final attendanceSnapshot = await _db
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .get();

    final batch = _db.batch();
    for (var doc in attendanceSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Xóa session
    batch.delete(_db.collection('sessions').doc(sessionId));

    await batch.commit();
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
          .where((s) => s.status == SessionStatus.scheduled)
          .length,
      'cancelled': sessions
          .where((s) => s.status == SessionStatus.cancelled)
          .length,
    };
  }
}
