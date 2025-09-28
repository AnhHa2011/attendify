import '../../../core/data/models/course_model.dart';
import '../../constants/firestore_collections.dart';
import '../services/firestore_service.dart';

class CourseRepository {
  final FirestoreService _firestore;
  CourseRepository(this._firestore);
  final String collectionName = FirestoreCollections.courses;
  // Lấy tất cả course
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _firestore.streamCollection(collectionName).map((snap) {
      return snap.docs.map((d) => CourseModel.fromDoc(d)).toList();
    });
  }

  Future<CourseModel?> getById(String courseCode) async {
    final doc = await _firestore.getDocumentById(collectionName, courseCode);
    if (!doc.exists) return null;
    return CourseModel.fromDoc(doc);
  }

  // Lấy course theo giảng viên
  Stream<List<CourseModel>> getByLecturer(String lecturerId) {
    return _firestore
        .streamQuery(collectionName, field: "lecturerId", isEqualTo: lecturerId)
        .map((snapshot) {
          return snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList();
        });
  }

  // Thêm mới
  Future<void> create(CourseModel course) async {
    await _firestore.setDocument(
      "$collectionName/${course.id}", // path
      course.toMap(), // dữ liệu
      merge: false, // overwrite hoàn toàn (default)
    );
  }

  // Cập nhật
  Future<void> update(String id, Map<String, dynamic> data) async {
    await _firestore.updateDocument("$collectionName/$id", data);
  }

  Future<void> delete(String id) async {
    await _firestore.deleteDocument("$collectionName/$id");
  }

  Future<void> archive(String id, bool archive) async {
    await _firestore.archiveDocument("$collectionName/$id", archive);
  }
}
