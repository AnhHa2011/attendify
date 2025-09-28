// lib/features/admin/domain/repositories/admin_import_repositories.dart
abstract class AdminImportRepositories {
  Future<void> upsertSubject({
    required String courseCode,
    required String courseName,
    int? credits,
  });

  Future<void> upsertClass({
    required String classCode,
    required String courseCode,
    required String className,
    String? lecturerId,
    int? maxAbsence,
    String? semester,
  });

  Future<void> upsertSession({
    required String sessionId,
    required String classCode,
    required DateTime startTime,
    DateTime? endTime,
    String? room,
  });
}
