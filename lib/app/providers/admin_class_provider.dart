import 'package:flutter/material.dart';
import '../../data/models/class_model.dart';
import '../../services/firebase/classes/class_service.dart';

class AdminClassProvider extends ChangeNotifier {
  final ClassService _svc;
  AdminClassProvider(this._svc);

  Stream<List<ClassModel>> allClasses() => _svc.allClasses();
  Stream<List<ClassModel>> classesOfLecturer(String lecturerUid) =>
      _svc.classesOfLecturer(lecturerUid);

  Stream<List<Map<String, String>>> lecturers() => _svc.lecturersStream();
}
