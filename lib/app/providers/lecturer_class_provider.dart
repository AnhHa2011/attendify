import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/data/models/class_model.dart';
import '../../core/data/services/class_service.dart';

class LecturerClassProvider extends ChangeNotifier {
  final ClassService _svc;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  LecturerClassProvider(this._svc);

  Stream<List<ClassModel>> myClasses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _svc.classesOfLecturer(uid);
  }
}
