// lib/core/data/repositories/session_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../services/firestore_service.dart';

class SessionRepository {
  final FirestoreService _firestore;

  SessionRepository(this._firestore);

  final String collectionName = "sessions";

  /// Tạo session mới
  Future<void> create(SessionModel session) async {
    await _firestore.setDocument(
      "$collectionName/${session.id}",
      session.toMap(),
    );
  }

  /// Lấy 1 session theo id

  Future<SessionModel?> getById(String sessionCode) async {
    final doc = await _firestore.getDocumentById(collectionName, sessionCode);
    if (!doc.exists) return null;
    return SessionModel.fromDoc(doc);
  }

  /// Stream toàn bộ sessions của course
  Stream<List<SessionModel>> getByCourse(String courseCode) {
    return _firestore
        .streamQuery(collectionName, field: "courseCode", isEqualTo: courseCode)
        .map((snap) => snap.docs.map((d) => SessionModel.fromDoc(d)).toList());
  }

  /// Update 1 session
  Future<void> update(String id, Map<String, dynamic> data) async {
    await _firestore.updateDocument("$collectionName/$id", data);
  }

  /// Xoá session
  Future<void> delete(String id) async {
    await _firestore.deleteDocument("$collectionName/$id");
  }

  /// Archive session
  Future<void> archive(String id, bool archive) async {
    await _firestore.archiveDocument("$collectionName/$id", archive);
  }

  Future<void> createBatch(List<SessionModel> sessions) async {
    final batch = _firestore.batch();

    for (final session in sessions) {
      final newDoc = _firestore.collection(collectionName).doc();

      batch.set(newDoc, {
        'courseCode': session.courseCode,
        'courseName': session.courseName,
        'lecturerId': session.lecturerId,
        'lecturerName': session.lecturerName,
        'title': session.title,
        'description': session.description,
        'startTime': Timestamp.fromDate(session.startTime),
        'endTime': Timestamp.fromDate(session.endTime),
        'location': session.location,
        'type': session.type.name, // enum -> string
        'status': session.status.name, // enum -> string
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'totalStudents': session.totalStudents,
        'attendedStudents': session.attendedStudents,
        'isAttendanceOpen': session.isAttendanceOpen,
        'qrCode': session.qrCode,
        'attendanceStatus': session.attendanceStatus,
      });
    }

    await batch.commit();
  }
}
