import 'package:cloud_firestore/cloud_firestore.dart';
import 'leave_request_model.dart';

class LeaveRequestRemoteDataSource {
  static const _colName = 'leave_requests';
  final _fs = FirebaseFirestore.instance;
  CollectionReference get _col => _fs.collection(_colName);

  // ... các hàm khác giữ nguyên

  /// Cập nhật trạng thái leave + (tuỳ) ghi attendance bằng 1 batch
  Future<void> updateStatusAndAttendance({
    required LeaveRequestModel req,
    required bool approve, // true=approved, false=rejected
    required String approverId,
    String? approverNote,
  }) async {
    final batch = _fs.batch();

    // 1) Update leave_requests/{id}
    final leaveRef = _col.doc(req.id);
    batch.update(leaveRef, {
      'status': approve ? 'approved' : 'rejected',
      'approverId': approverId,
      'approverNote': approverNote,
      'updatedAt': Timestamp.now().toDate(),
    });

    // 2) Nếu approved → đánh dấu attendance = excused
    final attRef = _fs
        .collection('courses')
        .doc(req.courseCode)
        .collection('sessions')
        .doc(req.sessionId)
        .collection('attendances')
        .doc(req.studentId);

    if (approve) {
      batch.set(attRef, {
        'status': 'excused',
        'source': 'leave_request',
        'note': approverNote ?? 'Đơn xin nghỉ đã duyệt',
        'updatedAt': Timestamp.now().toDate(),
      }, SetOptions(merge: true));
    } else {
      // Rejected: chỉ ghi nguồn & note (không đổi status hiện có)
      batch.set(attRef, {
        'source': 'leave_request',
        'note': approverNote ?? 'Đơn xin nghỉ bị từ chối',
        'updatedAt': Timestamp.now().toDate(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
