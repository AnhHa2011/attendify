import 'package:flutter/material.dart';

import '../../core/data/models/course_model.dart';
import '../../core/data/services/courses_service.dart';

class AdminCourseProvider extends ChangeNotifier {
  final CourseService _svc;
  AdminCourseProvider(this._svc);

  Stream<List<CourseModel>> courseesOfLecturer(String lecturerUid) =>
      _svc.coursesOfLecturer(lecturerUid);

  Stream<List<Map<String, String>>> lecturers() => _svc.lecturersStream();
}
