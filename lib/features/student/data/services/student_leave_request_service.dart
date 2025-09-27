import 'package:attendify/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/models/leave_request_model.dart';

class StudentLeaveRequestService {
  final _col = FirebaseFirestore.instance.collection(
    FirestoreCollections.leaveRequests,
  );

  Future<String> create(LeaveRequestModel m) async {
    final doc = await _col.add(m.toFirestore());
    return doc.id;
  }

  Stream<List<LeaveRequestModel>> myRequests(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList());
  }

  Stream<List<LeaveRequestModel>> byClassAndSession(
    String classCode,
    String sessionId,
  ) {
    return _col
        .where('classCode', isEqualTo: classCode)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((s) => s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList());
  }

  // Stream đơn PENDING theo lớp (và buổi nếu chọn)
  Stream<List<LeaveRequestModel>> pendingByClass({
    required String classCode,
    String? sessionId,
  }) {
    Query q = _col
        .where('classCode', isEqualTo: classCode)
        .where('status', isEqualTo: 'pending');
    if (sessionId != null) q = q.where('sessionId', isEqualTo: sessionId);
    return q.snapshots().map(
      (s) => s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList(),
    );
  }

  // Duyệt / Từ chối
  Future<void> updateStatus({
    required String id,
    required String status, // 'approved' | 'rejected'
    required String approverId,
    String? approverNote,
  }) async {
    await _col.doc(id).update({
      'status': status,
      'approverId': approverId,
      'approverNote': approverNote,
      'updatedAt': Timestamp.now().toDate(),
    });
  }

  // NEW: lấy theo studentId + (optional) status
  Stream<List<LeaveRequestModel>> myRequestsFiltered({
    required String studentId,
    String? status, // null = all
  }) {
    Query q = _col.where('studentId', isEqualTo: studentId);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) {
      final list = s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList();
      list.sort(
        (a, b) => b.sessionDate.compareTo(a.sessionDate),
      ); // sort client
      return list;
    });
  }

  // NEW: lấy theo class + (optional) session + status
  Stream<List<LeaveRequestModel>> byClassFiltered({
    required String classCode,
    String? sessionId,
    String? status, // null = all
  }) {
    Query q = _col.where('classCode', isEqualTo: classCode);
    if (sessionId != null) q = q.where('sessionId', isEqualTo: sessionId);
    if (status != null) q = q.where('status', isEqualTo: status);

    return q.snapshots().map((s) {
      final list = s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList();
      list.sort(
        (a, b) => b.sessionDate.compareTo(a.sessionDate),
      ); // sort client
      return list;
    });
  }
}
