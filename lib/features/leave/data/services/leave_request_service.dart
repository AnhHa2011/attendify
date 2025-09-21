import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class LeaveRequestService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Tạo request + upload ảnh (bytes) → lưu URL vào Firestore
  /// [files] là danh sách tuple (bytes, suggestedName)
  Future<String> createLeaveRequest({
    required String studentUid,
    required String studentName,
    required String studentEmail,
    required String classId,
    required String sessionId,
    required String reason,
    required List<(Uint8List bytes, String fileName)> files,
  }) async {
    // 1) Tạo doc trước (để có requestId)
    final docRef = await _db.collection('leave_requests').add({
      'studentUid': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'classId': classId,
      'sessionId': sessionId,
      'reason': reason,
      'attachmentUrls': [],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final requestId = docRef.id;

    // 2) Upload từng file lên Storage theo path cố định
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final (bytes, rawName) = files[i];
      final safeName = rawName.isEmpty ? 'evidence_$i.jpg' : rawName;
      final ref = _storage.ref().child(
        'leave_requests/$studentUid/$requestId/$safeName',
      );

      await ref.putData(
        bytes,
        SettableMetadata(contentType: _guessContentType(safeName)),
      );
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    // 3) cập nhật URL vào doc
    await docRef.update({'attachmentUrls': urls});

    return requestId;
  }

  Stream<List<Map<String, dynamic>>> myLeaveRequests(String studentUid) {
    return _db
        .collection('leave_requests')
        .where('studentUid', isEqualTo: studentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => (d.data()..['id'] = d.id)).toList(),
        );
  }

  String _guessContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
