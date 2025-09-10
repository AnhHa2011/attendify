import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/class_model.dart';
import '../../services/firebase/class_service.dart';

class StudentClassProvider extends ChangeNotifier {
  final ClassService _svc;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StudentClassProvider(this._svc);

  Stream<List<ClassModel>> myEnrolledClasses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _svc.classesOfStudent(uid);
  }
}
