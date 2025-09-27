import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/models/User_model.dart';
import '../../constants/firestore_collections.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestore;
  UserRepository(this._firestore);
  final String collectionName = FirestoreCollections.users;
  // Lấy tất cả User
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore.streamCollection(collectionName).map((snap) {
      return snap.docs.map((d) => UserModel.fromDoc(d)).toList();
    });
  }

  Future<UserModel?> getById(String userId) async {
    final doc = await _firestore.getDocumentById(collectionName, userId);
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  // Thêm mới
  Future<void> createUser(UserModel user) async {
    await _firestore.setDocument(
      "$collectionName/${user.uid}", // path
      user.toMap(), // dữ liệu
      merge: false, // overwrite hoàn toàn (default)
    );
  }

  // Cập nhật
  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await _firestore.updateDocument("$collectionName/$id", data);
  }

  Future<void> deleteUser(String id) async {
    await _firestore.deleteDocument("$collectionName/$id");
  }

  Future<void> archiveUser(String id, bool archive) async {
    await _firestore.archiveDocument("$collectionName/$id", archive);
  }
}
