import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String status; // present|late|absent|excused
  final String? source;
  final String? note;
  final DateTime? updatedAt;

  AttendanceModel({
    required this.status,
    this.source,
    this.note,
    this.updatedAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic>? m) => AttendanceModel(
    status: (m?['status'] ?? 'absent') as String,
    source: m?['source'] as String?,
    note: m?['note'] as String?,
    updatedAt: (m?['updatedAt'] as Timestamp?)?.toDate(),
  );
  factory AttendanceModel.fromDoc(DocumentSnapshot doc) =>
      AttendanceModel.fromMap(doc.data() as Map<String, dynamic>?);
}
