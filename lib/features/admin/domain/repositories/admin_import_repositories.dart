// lib/features/admin/domain/repositories/admin_import_repositories.dart
abstract class AdminImportRepositories {
  Future<void> upsertSubject({
    required String courseId,
    required String courseCode,
    required String courseName,
    int? credits,
  });

  Future<void> upsertClass({
    required String classId,
    required String courseId,
    required String className,
    String? lecturerId,
    int? maxAbsence,
    String? semester,
  });

  Future<void> upsertSession({
    required String sessionId,
    required String classId,
    required DateTime startTime,
    DateTime? endTime,
    String? room,
  });
}
