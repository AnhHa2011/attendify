import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  WriteBatch batch() => _db.batch();

  // === Collection & Document Reference ===
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _db.collection(path);
  }

  DocumentReference<Map<String, dynamic>> doc(String path) {
    return _db.doc(path);
  }

  // === CRUD cơ bản ===
  Future<void> setDocument(
    String path,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    final ref = _db.doc(path);
    await ref.set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(String path, Map<String, dynamic> data) async {
    final ref = _db.doc(path);
    await ref.update(data);
  }

  Future<void> deleteDocument(String path) async {
    final ref = _db.doc(path);
    await ref.delete();
  }

  // Archive document (set isArchived = true)
  Future<void> archiveDocument(String path, bool archive) async {
    final ref = _db.doc(path);
    await ref.update({"isArchived": archive});
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocumentByPath(
    String path,
  ) async {
    final ref = _db.doc(path);
    return await ref.get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocumentById(
    String collection,
    String id,
  ) async {
    final ref = _db.collection(collection).doc(id);
    return await ref.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(String path) async {
    final ref = _db.collection(path);
    return await ref.get();
  }

  // === Stream (real-time) ===
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument(String path) {
    return _db.doc(path).snapshots();
  }

  /// Watch doc bằng collection + id (an toàn hơn)
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocumentById(
    String collection,
    String id,
  ) {
    return _db.collection(collection).doc(id).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(String path) {
    return _db.collection(path).snapshots();
  }

  // === Query với điều kiện ===
  Future<QuerySnapshot<Map<String, dynamic>>> queryCollection(
    String path, {
    String? field,
    dynamic isEqualTo,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> ref = _db.collection(path);
    if (field != null && isEqualTo != null) {
      ref = ref.where(field, isEqualTo: isEqualTo);
    }
    if (limit != null) ref = ref.limit(limit);
    return await ref.get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamQuery(
    String path, {
    String? field,
    dynamic isEqualTo,
  }) {
    Query<Map<String, dynamic>> ref = _db.collection(path);
    if (field != null && isEqualTo != null) {
      ref = ref.where(field, isEqualTo: isEqualTo);
    }
    return ref.snapshots();
  }

  Future<void> runBatch(Future<void> Function(WriteBatch batch) handler) async {
    final batch = _db.batch();
    await handler(batch);
    await batch.commit();
  }
}
