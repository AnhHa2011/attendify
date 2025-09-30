// lib/features/student/data/services/student_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_attendance_stats.dart';
import '../models/student_session_detail.dart';

class StudentService {
  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;
  StudentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy thống kê điểm danh tổng quan của sinh viên
  Future<StudentAttendanceStats> getAttendanceStats(String studentId) async {
    try {
      // Lấy tất cả các session mà sinh viên đã tham gia
      final attendanceQuery = await _firestore
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .get();

      int presentCount = 0;
      int absentCount = 0;
      int leaveRequestCount = 0;

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'absent';

        switch (status) {
          case 'present':
            presentCount++;
            break;
          case 'absent':
            absentCount++;
            break;
          case 'leave_approved':
            leaveRequestCount++;
            break;
        }
      }

      final totalSessions = presentCount + absentCount + leaveRequestCount;

      return StudentAttendanceStats.calculate(
        totalSessions: totalSessions,
        presentCount: presentCount,
        absentCount: absentCount,
        leaveRequestCount: leaveRequestCount,
      );
    } catch (e) {
      print('Error getting attendance stats: $e');
      return StudentAttendanceStats.empty();
    }
  }

  /// Lấy thống kê điểm danh cho một lớp cụ thể
  Future<StudentAttendanceStats> getCourseAttendanceStats(
    String studentId,
    String classCode,
  ) async {
    try {
      // Lấy tất cả sessions của lớp
      final sessionsQuery = await _firestore
          .collection('sessions')
          .where('classCode', isEqualTo: classCode)
          .get();

      final sessionIds = sessionsQuery.docs.map((doc) => doc.id).toList();

      if (sessionIds.isEmpty) {
        return StudentAttendanceStats.empty();
      }

      // Lấy attendance records của sinh viên cho các session này
      final attendanceQuery = await _firestore
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .where('sessionId', whereIn: sessionIds)
          .get();

      int presentCount = 0;
      int absentCount = 0;
      int leaveRequestCount = 0;

      // Tạo map để tracking sessions đã có attendance
      final attendedSessions = <String>{};

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final sessionId = data['sessionId'] as String? ?? '';
        final status = data['status'] as String? ?? 'absent';

        attendedSessions.add(sessionId);

        switch (status) {
          case 'present':
            presentCount++;
            break;
          case 'absent':
            absentCount++;
            break;
          case 'leave_approved':
            leaveRequestCount++;
            break;
        }
      }

      // Các sessions không có attendance record được tính là absent
      final unattendedCount = sessionIds.length - attendedSessions.length;
      absentCount += unattendedCount;

      final totalSessions = sessionIds.length;

      return StudentAttendanceStats.calculate(
        totalSessions: totalSessions,
        presentCount: presentCount,
        absentCount: absentCount,
        leaveRequestCount: leaveRequestCount,
      );
    } catch (e) {
      print('Error getting class attendance stats: $e');
      return StudentAttendanceStats.empty();
    }
  }

  /// Lấy chi tiết lịch sử điểm danh của sinh viên
  Stream<List<StudentSessionDetail>> getAttendanceHistory(String studentId) {
    return _firestore
        .collection('attendances')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<StudentSessionDetail> details = [];

          for (var doc in snapshot.docs) {
            final attendanceData = doc.data();
            final sessionId = attendanceData['sessionId'] as String? ?? '';

            if (sessionId.isEmpty) continue;

            try {
              // Lấy thông tin session
              final sessionDoc = await _firestore
                  .collection('sessions')
                  .doc(sessionId)
                  .get();

              if (!sessionDoc.exists) continue;

              final sessionData = sessionDoc.data()!;
              final classCode = sessionData['classCode'] as String? ?? '';

              if (classCode.isEmpty) continue;

              // Lấy thông tin lớp học
              final classDoc = await _firestore
                  .collection('classes')
                  .doc(classCode)
                  .get();

              if (!classDoc.exists) continue;

              final classData = classDoc.data()!;

              // Lấy thông tin giảng viên
              final lecturerId = classData['lecturerId'] as String? ?? '';
              String lecturerName = 'N/A';

              if (lecturerId.isNotEmpty) {
                final lecturerDoc = await _firestore
                    .collection('users')
                    .doc(lecturerId)
                    .get();
                if (lecturerDoc.exists) {
                  lecturerName = lecturerDoc.data()?['displayName'] ?? 'N/A';
                }
              }

              // Lấy tên môn học
              final courseCodes = List<String>.from(
                classData['courseCodes'] ?? [],
              );
              final List<String> courseNames = [];

              for (String courseCode in courseCodes) {
                final courseDoc = await _firestore
                    .collection('courses')
                    .doc(courseCode)
                    .get();
                if (courseDoc.exists) {
                  courseNames.add(courseDoc.data()?['courseName'] ?? '');
                }
              }

              final detail = StudentSessionDetail(
                sessionId: sessionId,
                classCode: classCode,
                className: classData['className'] ?? '',
                courseNames: courseNames.join(', '),
                lecturerName: lecturerName,
                startTime:
                    (sessionData['startTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                endTime:
                    (sessionData['endTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                room: sessionData['room'] ?? '',
                attendanceStatus: attendanceData['status'] ?? 'absent',
                attendanceTime: (attendanceData['timestamp'] as Timestamp?)
                    ?.toDate(),
                leaveReason: attendanceData['leaveReason'] as String?,
              );

              details.add(detail);
            } catch (e) {
              print('Error processing session $sessionId: $e');
              continue;
            }
          }

          return details;
        });
  }

  /// Lấy chi tiết lịch sử điểm danh cho một lớp cụ thể
  Stream<List<StudentSessionDetail>> getCourseAttendanceHistory(
    String studentId,
    String classCode,
  ) {
    return _firestore
        .collection('sessions')
        .where('classCode', isEqualTo: classCode)
        .orderBy('startTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<StudentSessionDetail> details = [];

          for (var sessionDoc in snapshot.docs) {
            final sessionData = sessionDoc.data();
            final sessionId = sessionDoc.id;

            try {
              // Lấy thông tin điểm danh của sinh viên cho session này
              final attendanceQuery = await _firestore
                  .collection('attendances')
                  .where('studentId', isEqualTo: studentId)
                  .where('sessionId', isEqualTo: sessionId)
                  .limit(1)
                  .get();

              String attendanceStatus = 'absent';
              DateTime? attendanceTime;
              String? leaveReason;

              if (attendanceQuery.docs.isNotEmpty) {
                final attendanceData = attendanceQuery.docs.first.data();
                attendanceStatus = attendanceData['status'] ?? 'absent';
                attendanceTime = (attendanceData['timestamp'] as Timestamp?)
                    ?.toDate();
                leaveReason = attendanceData['leaveReason'] as String?;
              }

              // Lấy thông tin lớp học
              final classDoc = await _firestore
                  .collection('classes')
                  .doc(classCode)
                  .get();

              if (!classDoc.exists) continue;

              final classData = classDoc.data()!;

              // Lấy thông tin giảng viên
              final lecturerId = classData['lecturerId'] as String? ?? '';
              String lecturerName = 'N/A';

              if (lecturerId.isNotEmpty) {
                final lecturerDoc = await _firestore
                    .collection('users')
                    .doc(lecturerId)
                    .get();
                if (lecturerDoc.exists) {
                  lecturerName = lecturerDoc.data()?['displayName'] ?? 'N/A';
                }
              }

              // Lấy tên môn học
              final courseCodes = List<String>.from(
                classData['courseCodes'] ?? [],
              );
              final List<String> courseNames = [];

              for (String courseCode in courseCodes) {
                final courseDoc = await _firestore
                    .collection('courses')
                    .doc(courseCode)
                    .get();
                if (courseDoc.exists) {
                  courseNames.add(courseDoc.data()?['courseName'] ?? '');
                }
              }

              final detail = StudentSessionDetail(
                sessionId: sessionId,
                classCode: classCode,
                className: classData['className'] ?? '',
                courseNames: courseNames.join(', '),
                lecturerName: lecturerName,
                startTime:
                    (sessionData['startTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                endTime:
                    (sessionData['endTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                room: sessionData['room'] ?? '',
                attendanceStatus: attendanceStatus,
                attendanceTime: attendanceTime,
                leaveReason: leaveReason,
              );

              details.add(detail);
            } catch (e) {
              print('Error processing session $sessionId: $e');
              continue;
            }
          }

          return details;
        });
  }

  /// Kiểm tra sinh viên có thể điểm danh cho session này không
  Future<bool> canMarkAttendance(String sessionId, String studentId) async {
    try {
      // Kiểm tra session có tồn tại và đang mở không
      final sessionDoc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) return false;

      final sessionData = sessionDoc.data()!;
      final isOpen = sessionData['isOpen'] ?? false;
      final courseCode = sessionData['courseCode'] as String? ?? '';

      if (!isOpen) return false;

      // Kiểm tra sinh viên có trong lớp không
      final enrollmentQuery = await _firestore
          .collection('enrollments')
          .where('courseCode', isEqualTo: courseCode)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (enrollmentQuery.docs.isEmpty) return false;

      // Kiểm tra đã điểm danh chưa
      final attendanceQuery = await _firestore
          .collection('attendances')
          .where('sessionId', isEqualTo: sessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      return attendanceQuery.docs.isEmpty;
    } catch (e) {
      print('Error checking attendance permission: $e');
      return false;
    }
  }

  /// Export lịch học sinh viên ra file ICS
  Future<String> exportScheduleToICS(String studentId) async {
    try {
      // Lấy tất cả các lớp mà sinh viên tham gia
      final enrollmentsQuery = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (enrollmentsQuery.docs.isEmpty) {
        throw Exception('Không có lớp học nào để xuất lịch');
      }

      final courseCodes = enrollmentsQuery.docs
          .map((doc) => doc.data()['courseCode'] as String)
          .toList();

      // Lấy tất cả sessions của các lớp này
      final List<Map<String, dynamic>> allSessions = [];

      for (String courseCode in courseCodes) {
        final sessionsQuery = await _firestore
            .collection('sessions')
            .where('courseCode', isEqualTo: courseCode)
            .get();

        for (var sessionDoc in sessionsQuery.docs) {
          final sessionData = sessionDoc.data();
          sessionData['sessionId'] = sessionDoc.id;
          sessionData['courseCode'] = courseCode;
          allSessions.add(sessionData);
        }
      }

      // Tạo nội dung ICS
      final buffer = StringBuffer();
      buffer.writeln('BEGIN:VCALENDAR');
      buffer.writeln('VERSION:2.0');
      buffer.writeln('PRODID:-//Attendify//Student Schedule//EN');
      buffer.writeln('CALSCALE:GREGORIAN');

      for (var session in allSessions) {
        final startTime = (session['startTime'] as Timestamp?)?.toDate();
        final endTime = (session['endTime'] as Timestamp?)?.toDate();
        final courseCode = session['courseCode'] as String;

        if (startTime == null || endTime == null) continue;

        // Lấy thông tin lớp học
        final courseDoc = await _firestore
            .collection('coursees')
            .doc(courseCode)
            .get();

        if (!courseDoc.exists) continue;

        final courseData = courseDoc.data()!;
        final courseName = courseData['courseName'] ?? '';
        final room = session['room'] ?? '';

        // Format datetime for ICS
        String formatDateTime(DateTime dt) {
          return dt
                  .toUtc()
                  .toIso8601String()
                  .replaceAll('-', '')
                  .replaceAll(':', '')
                  .split('.')[0] +
              'Z';
        }

        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('UID:${session['sessionId']}@attendify.app');
        buffer.writeln('DTSTAMP:${formatDateTime(DateTime.now())}');
        buffer.writeln('DTSTART:${formatDateTime(startTime)}');
        buffer.writeln('DTEND:${formatDateTime(endTime)}');
        buffer.writeln('SUMMARY:$courseCode - $courseName');
        if (room.isNotEmpty) {
          buffer.writeln('LOCATION:$room');
        }
        buffer.writeln('DESCRIPTION:Buổi học lớp $courseName');
        buffer.writeln('END:VEVENT');
      }

      buffer.writeln('END:VCALENDAR');

      return buffer.toString();
    } catch (e) {
      throw Exception('Không thể xuất lịch học: $e');
    }
  }
}
