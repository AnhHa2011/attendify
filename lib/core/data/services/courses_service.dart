import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/rich_course_model.dart';
import '../models/user_model.dart';
import '../models/course_schedule_model.dart';

/// Một "View Model" chứa thông tin đầy đủ của một môn học để hiển thị trên UI.

class CourseService {
  final _db = FirebaseFirestore.instance;

  String _randomCode([int len = 6]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // Hàm này nhận vào một CourseModel gốc và trả về một RichCourseModel đầy đủ thông tin.
  Future<RichCourseModel> _enrichCourseModel(CourseModel courseModel) async {
    // 1. Lấy thông tin giảng viên
    UserModel? lecturer;
    try {
      final lecturerDoc = await _db
          .collection('users')
          .doc(courseModel.lecturerId)
          .get();
      if (lecturerDoc.exists) {
        lecturer = UserModel.fromDoc(lecturerDoc);
      }
    } catch (e) {
      // Bỏ qua lỗi nếu không tìm thấy giảng viên
    }

    // 3. Trả về model đã được làm giàu
    return RichCourseModel(courseInfo: courseModel, lecturer: lecturer);
  }

  /// === NÂNG CẤP: TẠO LỊCH HỌC HÀNG LOẠT DỰA TRÊN THỜI KHÓA BIỂU HÀNG TUẦN ===
  Future<void> createRecurringSessions({
    required String courseCode,
    required String baseTitle,
    required String location,
    required int durationInMinutes,
    required int numberOfWeeks,
    required List<CourseSchedule> weeklySchedules, // <<<--- Dùng model mới
    required DateTime semesterStartDate, // Ngày bắt đầu của học kỳ
  }) async {
    final batch = _db.batch();

    // Lặp qua từng tuần trong tổng số tuần
    for (int week = 0; week < numberOfWeeks; week++) {
      // Lặp qua từng lịch học trong tuần (ví dụ: Thứ 2 và Thứ 4)
      for (final schedule in weeklySchedules) {
        // Tính toán ngày chính xác của buổi học trong tuần hiện tại
        DateTime sessionDate = semesterStartDate.add(Duration(days: week * 7));
        // Tìm đến đúng ngày trong tuần (ví dụ: Thứ 2)
        sessionDate = sessionDate.add(
          Duration(days: schedule.dayOfWeek - sessionDate.weekday),
        );

        // Ghép ngày và giờ
        final startTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          schedule.startTime.hour,
          schedule.startTime.minute,
        );

        final docRef = _db.collection('sessions').doc();
        batch.set(docRef, {
          'courseCode': courseCode,
          'title':
              '$baseTitle - Buổi ${(week * weeklySchedules.length) + weeklySchedules.indexOf(schedule) + 1}',
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(
            startTime.add(Duration(minutes: durationInMinutes)),
          ),
          'location': location,
          'status': 'scheduled',
          'type': 'lecture',
          'attendanceOpen': false,
        });
      }
    }

    await batch.commit();
  }

  Future<void> enrollStudent({
    required String joinCode,
    required String studentUid,
    required String studentName,
    required String studentEmail,
  }) async {
    // 1. Tìm môn học có mã tham gia tương ứng
    final courseQuery = await _db
        .collection('courses')
        .where('joinCode', isEqualTo: joinCode.trim())
        .limit(1)
        .get();

    if (courseQuery.docs.isEmpty) {
      throw Exception('Mã tham gia không hợp lệ hoặc môn học không tồn tại.');
    }

    final courseDoc = courseQuery.docs.first;
    final courseCode = courseDoc.id;

    final existingEnrollmentQuery = await _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    // Nếu đã tìm thấy bản ghi enrollment, nghĩa là sinh viên đã ở trong môn
    if (existingEnrollmentQuery.docs.isNotEmpty) {
      throw Exception('Bạn đã tham gia môn học này rồi.');
    }
    // =================================================================

    // 2. Nếu chưa tham gia, tạo một bản ghi mới trong collection 'enrollments'
    await _db.collection('enrollments').add({
      'courseCode': courseCode,
      'courseName': courseDoc.data()['courseName'],
      'studentUid': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'joinDate': Timestamp.now().toDate(),
    });
  }

  /// Lấy danh sách sinh viên đã ghi danh vào môn, bao gồm cả thông tin chi tiết.
  Future<List<Map<String, dynamic>>> getEnrolledStudents(
    String courseCode,
  ) async {
    // 1. Lấy tất cả các bản ghi enrollment của môn học
    final enrollmentsQuery = await _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .get();

    if (enrollmentsQuery.docs.isEmpty) {
      return []; // Trả về danh sách rỗng nếu không có sinh viên nào
    }

    // 2. Lấy ra danh sách các studentUid
    final studentUids = enrollmentsQuery.docs
        .map((doc) => doc.data()['studentUid'] as String)
        .toList();

    // Lấy ID của bản ghi enrollment để dùng cho việc xoá
    final enrollmentIds = {
      for (var doc in enrollmentsQuery.docs) doc.data()['studentUid']: doc.id,
    };

    if (studentUids.isEmpty) {
      return [];
    }

    // 3. Dùng danh sách studentUids để lấy thông tin chi tiết từ collection 'users'
    // Firestore cho phép query tối đa 30 item trong một lệnh 'whereIn'
    final usersSnapshot = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: studentUids)
        .get();

    // 4. Chuyển đổi kết quả thành danh sách Map mong muốn
    return usersSnapshot.docs.map((userDoc) {
      final userData = userDoc.data();
      return {
        'uid': userDoc.id,
        'displayName': userData['displayName'] ?? 'N/A',
        'email': userData['email'] ?? 'N/A',
        // Thêm enrollmentId vào map để logic Xoá có thể hoạt động
        'enrollmentId': enrollmentIds[userDoc.id],
      };
    }).toList();
  }

  /// Xoá một sinh viên khỏi môn học dựa trên ID của bản ghi enrollment
  Future<void> removeStudentFromCourse(String enrollmentId) async {
    try {
      await _db.collection('enrollments').doc(enrollmentId).delete();
    } catch (e) {
      // Ném ra lỗi để UI có thể bắt và hiển thị thông báo
      throw Exception('Đã xảy ra lỗi khi xoá sinh viên: $e');
    }
  }

  /// Lấy tổng số sinh viên đã tham gia một môn học
  Future<int> getEnrolledStudentCount(String courseCode) async {
    try {
      final snapshot = await _db
          .collection('enrollments')
          .where('courseCode', isEqualTo: courseCode)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting student count: $e');
      return 0;
    }
  }

  // /// Lắng nghe MỘT môn học và "làm giàu" nó với thông tin môn học + giảng viên
  // Stream<CourseModel> getRichCourseStream(String courseCode) {
  //   // 1. Lắng nghe document course cụ thể
  //   return _db.collection('courses').doc(courseCode).snapshots().asyncMap((
  //     courseDoc,
  //   ) async {
  //     if (!courseDoc.exists) {
  //       throw Exception('môn học không tồn tại!');
  //     }

  //     final courseModel = CourseModel.fromDoc(courseDoc);

  //     try {
  //       // 2. Lấy thông tin môn học (một lần)
  //       final courseDoc = await _db
  //           .collection('courses')
  //           .doc(courseModel.courseCode)
  //           .get();
  //       final courseData = courseDoc.data();

  //       // 3. Lấy thông tin giảng viên (một lần)
  //       final lecturerDoc = await _db
  //           .collection('users')
  //           .doc(courseModel.lecturerId)
  //           .get();
  //       final lecturerData = lecturerDoc.data();

  //       // 4. Trả về model đã được "làm giàu" bằng hàm copyWith
  //       return courseModel.copyWith(
  //         courseName: courseData?['courseName'],
  //         courseCode: courseData?['courseCode'],
  //         lecturerName: lecturerData?['displayName'],
  //       );
  //     } catch (e) {
  //       print('Error enriching course $courseCode: $e');
  //       // Trả về dữ liệu gốc nếu có lỗi (ví dụ: môn học bị xóa)
  //       return courseModel;
  //     }
  //   });
  // }

  /// Lắng nghe MỘT môn học và trả về Stream của RichCourseModel
  Stream<RichCourseModel> getRichCourseStream(String dataId) {
    return _db.collection('courses').doc(dataId).snapshots().asyncMap((
      courseDoc,
    ) async {
      if (!courseDoc.exists) {
        throw Exception('môn học không tồn tại!');
      }
      final courseModel = CourseModel.fromDoc(courseDoc);
      // Gọi hàm helper để làm giàu dữ liệu
      return await _enrichCourseModel(courseModel);
    });
  }

  // /// Lấy danh sách môn học của MỘT giảng viên
  // Stream<List<CourseModel>> getRichCoursesStreamForLecturer(String lecturerId) {
  //   return _db
  //       .collection('courses')
  //       .where('lecturerId', isEqualTo: lecturerId)
  //       .where('isArchived', isEqualTo: false)
  //       // .orderBy('createdAt', descending: true) // (tuỳ, nếu field tồn tại)
  //       .snapshots()
  //       .asyncMap((courseSnapshot) async {
  //         final courses = courseSnapshot.docs
  //             .map((doc) => CourseModel.fromDoc(doc))
  //             .toList();
  //         if (courses.isEmpty) return [];

  //         final richCourseFutures = courses.map((courseModel) async {
  //           try {
  //             final courseDoc = await _db
  //                 .collection('courses')
  //                 .doc(courseModel.courseCode)
  //                 .get();
  //             final lecturerDoc = await _db
  //                 .collection('users')
  //                 .doc(courseModel.lecturerId)
  //                 .get();
  //             return courseModel.copyWith(
  //               courseName: courseDoc.data()?['courseName'],
  //               courseCode: courseDoc.data()?['courseCode'],
  //               lecturerName: lecturerDoc.data()?['displayName'],
  //             );
  //           } catch (_) {
  //             return courseModel;
  //           }
  //         }).toList();
  //         return Future.wait(richCourseFutures);
  //       });
  // }

  /// Lấy danh sách môn học của MỘT giảng viên
  Stream<List<RichCourseModel>> getRichCoursesStreamForLecturer(
    String lecturerId,
  ) {
    return _db
        .collection('courses')
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .asyncMap((courseSnapshot) async {
          final courseModels = courseSnapshot.docs
              .map((doc) => CourseModel.fromDoc(doc))
              .toList();
          if (courseModels.isEmpty) return [];

          // Dùng hàm helper để làm giàu cho mỗi môn học
          final richCourseFutures = courseModels
              .map((model) => _enrichCourseModel(model))
              .toList();
          return Future.wait(richCourseFutures);
        });
  }

  // /// Lấy danh sách các môn học đã "làm giàu" mà MỘT sinh viên đã tham gia
  // Stream<List<CourseModel>> getRichEnrolledcoursesStream(String studentId) {
  //   // 1. Lắng nghe collection 'enrollments' để tìm các môn của sinh viên
  //   return _db
  //       .collection('enrollments')
  //       .where('studentId', isEqualTo: studentId)
  //       .snapshots()
  //       .asyncMap((enrollmentSnapshot) async {
  //         if (enrollmentSnapshot.docs.isEmpty) {
  //           return []; // Sinh viên này chưa tham gia môn nào
  //         }

  //         // 2. Lấy ra danh sách các courseCode
  //         final courseCodes = enrollmentSnapshot.docs
  //             .map((doc) => doc.data()['courseCode'] as String)
  //             .toList();

  //         if (courseCodes.isEmpty) {
  //           return [];
  //         }

  //         // 3. Lấy thông tin chi tiết cho từng môn học
  //         // Chúng ta sẽ lấy dữ liệu từ collection 'courses' nơi mà ID nằm trong danh sách courseCodes
  //         final courseQuery = await _db
  //             .collection('courses')
  //             .where(FieldPath.documentId, whereIn: courseCodes)
  //             .get();

  //         final courses = courseQuery.docs
  //             .map((doc) => CourseModel.fromDoc(doc))
  //             .toList();

  //         // 4. "Làm giàu" dữ liệu cho từng môn (giống như các hàm trước)
  //         final richCourseFutures = courses.map((courseModel) async {
  //           try {
  //             final courseDoc = await _db
  //                 .collection('courses')
  //                 .doc(courseModel.courseCode)
  //                 .get();
  //             final lecturerDoc = await _db
  //                 .collection('users')
  //                 .doc(courseModel.lecturerId)
  //                 .get();
  //             return courseModel.copyWith(
  //               courseName: courseDoc.data()?['courseName'],
  //               courseCode: courseDoc.data()?['courseCode'],
  //               lecturerName: lecturerDoc.data()?['displayName'],
  //             );
  //           } catch (e) {
  //             return courseModel; // Trả về dữ liệu gốc nếu có lỗi
  //           }
  //         }).toList();

  //         return await Future.wait(richCourseFutures);
  //       });
  // }

  // /// Lấy danh sách môn học đã được "làm giàu" với thông tin môn học và giảng viên
  // Stream<List<CourseModel>> getRichcoursesStream() {
  //   // 1. Lắng nghe sự thay đổi từ collection 'courses'
  //   return _db.collection('courses').snapshots().asyncMap((
  //     courseSnapshot,
  //   ) async {
  //     final courses = courseSnapshot.docs
  //         .map((doc) => CourseModel.fromDoc(doc))
  //         .toList();

  //     if (courses.isEmpty) {
  //       return []; // Trả về danh sách rỗng nếu không có môn nào
  //     }

  //     // 2. Tạo một danh sách các "công việc" cần làm
  //     final richCourseFutures = courses.map((courseModel) async {
  //       try {
  //         // Lấy thông tin môn học
  //         final courseDoc = await _db
  //             .collection('courses')
  //             .doc(courseModel.courseCode)
  //             .get();
  //         final courseData = courseDoc.data();

  //         // Lấy thông tin giảng viên
  //         final lecturerDoc = await _db
  //             .collection('users')
  //             .doc(courseModel.lecturerId)
  //             .get();
  //         final lecturerData = lecturerDoc.data();

  //         // 3. Dùng hàm copyWith để tạo ra một CourseModel mới với dữ liệu đã làm giàu
  //         return courseModel.copyWith(
  //           courseName: courseData?['courseName'],
  //           courseCode: courseData?['courseCode'],
  //           lecturerName: lecturerData?['displayName'],
  //         );
  //       } catch (e) {
  //         // Nếu có lỗi (ví dụ: courseCode không tồn tại), trả về model gốc
  //         print('Error enriching course ${courseModel.id}: $e');
  //         return courseModel;
  //       }
  //     }).toList();

  //     // 4. Chạy tất cả các "công việc" song song và trả về kết quả
  //     return await Future.wait(richCourseFutures);
  //   });
  // }

  /// Lấy TẤT CẢ danh sách môn học đã được "làm giàu"
  Stream<List<RichCourseModel>> getRichcoursesStream() {
    return _db.collection('courses').snapshots().asyncMap((
      courseSnapshot,
    ) async {
      final courseModels = courseSnapshot.docs
          .map((doc) => CourseModel.fromDoc(doc))
          .toList();
      if (courseModels.isEmpty) return [];

      // Dùng hàm helper để làm giàu cho mỗi môn học
      final richCourseFutures = courseModels
          .map((model) => _enrichCourseModel(model))
          .toList();
      return await Future.wait(richCourseFutures);
    });
  }

  /// Lấy danh sách các môn học đã "làm giàu" mà MỘT sinh viên đã tham gia
  Stream<List<RichCourseModel>> getRichEnrolledCoursesStream(String studentId) {
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentId)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) return [];

          final courseCodes = enrollmentSnapshot.docs
              .map((doc) => doc.data()['courseCode'] as String)
              .toSet()
              .toList();
          if (courseCodes.isEmpty) return [];

          final courseQuery = await _db
              .collection('courses')
              .where(FieldPath.documentId, whereIn: courseCodes)
              .get();
          final courseModels = courseQuery.docs
              .map((doc) => CourseModel.fromDoc(doc))
              .toList();

          // Dùng hàm helper để làm giàu cho mỗi môn học
          final richCourseFutures = courseModels
              .map((model) => _enrichCourseModel(model))
              .toList();
          return await Future.wait(richCourseFutures);
        });
  }

  // Hàm mới để lấy danh sách tất cả môn học
  Stream<List<CourseModel>>? getAllCoursesStream() {
    return _db
        .collection('courses')
        // SỬA DÒNG NÀY:
        // .where('isArchived', isNotEqualTo: true) // Dòng cũ
        .where('isArchived', whereIn: [null, false]) // Dòng mới
        .orderBy('courseCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  // Bạn có thể giữ lại hàm tạo mã ngẫu nhiên này
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  // === Streams cho Admin/Lecturer/Student ===
  Stream<List<CourseModel>> allcourses() {
    return _db
        .collection('courses')
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CourseModel.fromDoc(d)).toList());
  }

  Stream<List<CourseModel>> coursesOfLecturer(String lecturerUid) {
    return _db
        .collection('courses')
        .where('lecturerId', isEqualTo: lecturerUid)
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CourseModel.fromDoc(d)).toList());
  }

  /// Student: lấy các môn mà SV đã enroll (collection 'enrollments')
  /// enrollments doc: { courseCode, studentUid, joinedAt }
  Stream<List<CourseModel>> coursesOfStudent(String studentUid) {
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .asyncMap((enrollSnap) async {
          final futures = enrollSnap.docs.map((e) async {
            final courseCode = (e.data()['courseCode'] as String);
            final cDoc = await _db.collection('courses').doc(courseCode).get();
            if (!cDoc.exists) return null;
            return CourseModel.fromDoc(cDoc);
          });
          final list = await Future.wait(futures);
          return list.whereType<CourseModel>().toList();
        });
  }

  // Chi tiết môn & members
  Stream<CourseModel> courseStream(String courseCode) => _db
      .collection('courses')
      .doc(courseCode)
      .snapshots()
      .map(CourseModel.fromDoc);

  Stream<List<Map<String, dynamic>>> membersStream(String courseCode) {
    return _db
        .collection('courses')
        .doc(courseCode)
        .collection('members')
        // .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> removeMember(String courseCode, String uid) async {
    await _db
        .collection('courses')
        .doc(courseCode)
        .collection('members')
        .doc(uid)
        .delete();
  }

  Future<void> regenerateJoinCode(String courseCode) async {
    await _db.collection('courses').doc(courseCode).update({
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
