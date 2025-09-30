// lib/core/data/services/courses_service.dart
import 'dart:math';

import '../models/course_model.dart';
import '../models/course_schedule_model.dart';
import '../models/rich_course_model.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';

import '../repositories/course_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';

class CoursesService {
  final CourseRepository courseRepo;
  final SessionRepository sessionRepo;
  final UserRepository userRepo;

  CoursesService({
    required this.courseRepo,
    required this.sessionRepo,
    required this.userRepo,
  });

  // ---------------- Helpers ----------------
  String _randomCode([int len = 6]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<RichCourseModel> _enrichCourseModel(CourseModel course) async {
    UserModel? lecturer;
    if (course.lecturerId.isNotEmpty) {
      lecturer = (await userRepo.getById(course.lecturerId)) as UserModel?;
    }
    return RichCourseModel(courseInfo: course, lecturer: lecturer);
  }

  Future<List<RichCourseModel>> _enrichMany(List<CourseModel> list) async {
    return Future.wait(list.map(_enrichCourseModel));
  }

  // ---------------- Queries / Streams ----------------

  // // /// Stream 1 môn học (đã enrich)
  // // Stream<RichCourseModel> watchRichCourse(String courseId) {
  // //   // yêu cầu CourseRepository có watchById
  // //   return courseRepo.watchById(courseId).asyncMap((c) async {
  // //     if (c == null) {
  // //       throw Exception('Môn học không tồn tại');
  // //     }
  // //     return _enrichCourseModel(c);
  // //   });
  // // }

  // // /// Stream tất cả môn học (đã enrich)
  // // Stream<List<RichCourseModel>> watchAllRichCourses() {
  // //   return courseRepo.watchAll().asyncMap(_enrichMany);
  // // }

  // // /// Stream các môn của 1 giảng viên (đã enrich)
  // // Stream<List<RichCourseModel>> watchRichCoursesOfLecturer(String lecturerId) {
  // //   return courseRepo.watchByLecturer(lecturerId).asyncMap(_enrichMany);
  // // }

  // // /// Stream các môn SV đã ghi danh (đã enrich)
  // // Stream<List<RichCourseModel>> watchRichEnrolledCourses(String studentId) {
  // //   // yêu cầu CourseRepository có watchByStudent (hoặc bạn map từ enrollments repo)
  // //   return courseRepo.watchByStudent(studentId).asyncMap(_enrichMany);
  // // }

  // // ---------------- Commands (mutations) ----------------

  // /// Tạo/cập nhật môn học (uỷ quyền cho repo)
  // Future<void> createCourse(CourseModel course) => courseRepo.create(course);

  // Future<void> updateCourse(String courseId, Map<String, dynamic> data) =>
  //     courseRepo.update(courseId, data);

  // Future<void> deleteCourse(String courseId) => courseRepo.delete(courseId);

  // Future<void> archiveCourse(String courseId) =>
  //     courseRepo.archive(courseId, isArchived: true);

  // Future<void> unarchiveCourse(String courseId) =>
  //     courseRepo.archive(courseId, isArchived: false);

  // Future<void> regenerateJoinCode(String courseId) async {
  //   final newCode = _randomCode();
  //   await courseRepo.update(courseId, {'joinCode': newCode});
  // }

  // ---------------- Sessions (recurring) ----------------

  /// Tạo lịch học hàng loạt dựa trên weekly schedules, dùng SessionRepository.createBatch
  Future<void> createRecurringSessions({
    required String courseCode,
    required String baseTitle,
    required String location,
    required int durationInMinutes,
    required int numberOfWeeks,
    required List<CourseSchedule> weeklySchedules,
    required DateTime semesterStartDate,
  }) async {
    // Lấy thêm thông tin course & lecturer để đổ sẵn vào session
    final course = await courseRepo.getById(courseCode);
    final String courseName = course?.courseName ?? '';
    final String lecturerId = course?.lecturerId ?? '';
    String lecturerName = '';
    if (lecturerId.isNotEmpty) {
      final u = await userRepo.getById(lecturerId);
      lecturerName = u?.displayName ?? '';
    }

    final now = DateTime.now();
    final List<SessionModel> sessions = [];

    for (int week = 0; week < numberOfWeeks; week++) {
      for (final slot in weeklySchedules) {
        // Tính ngày của tuần hiện tại
        final weekStart = semesterStartDate.add(Duration(days: week * 7));
        final offsetDays = slot.dayOfWeek - weekStart.weekday; // 1..7
        final sessionDate = weekStart.add(Duration(days: offsetDays));

        // Ghép ngày + giờ
        final startTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          slot.startTime.hour,
          slot.startTime.minute,
        );
        final endTime = startTime.add(Duration(minutes: durationInMinutes));

        sessions.add(
          SessionModel(
            id: '', // repo sẽ tạo id mới
            courseCode: courseCode,
            courseName: courseName,
            lecturerId: lecturerId,
            lecturerName: lecturerName,
            title:
                '$baseTitle - Buổi ${(week * weeklySchedules.length) + weeklySchedules.indexOf(slot) + 1}',
            description: null,
            startTime: startTime,
            endTime: endTime,
            location: location,
            type: SessionType.lecture,
            status: SessionStatus.scheduled,
            createdAt: now,
            updatedAt: null,
            totalStudents: 0,
            attendedStudents: 0,
            qrCode: null,
            attendanceStatus: const {},
          ),
        );
      }
    }

    await sessionRepo.createBatch(sessions);
  }
}
