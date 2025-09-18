class FirestoreUtils {
  static void ensureValidId(String? id, {String fieldName = 'id'}) {
    if (id == null || id.trim().isEmpty) {
      throw ArgumentError('Invalid "$fieldName": must be a non-empty string');
    }
  }
}
