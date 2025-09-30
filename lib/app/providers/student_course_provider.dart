import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/data/models/course_model.dart';
import '../../core/data/services/courses_service.dart';

class StudentCourseProvider extends ChangeNotifier {
  final CourseService _svc;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StudentCourseProvider(this._svc);

  Stream<List<CourseModel>> myEnrolledCoursees() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _svc.coursesOfStudent(uid);
  }
}
