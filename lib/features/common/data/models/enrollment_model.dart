import '../../../../app_imports.dart';

class EnrollmentModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;
  final String classId; // Tên lớp học, ví dụ: "Lớp Tín chỉ IT - K15"
  final DateTime joinDate; // Mã lớp học, ví dụ: "LTC_IT_K15_01"
  final String studentUid;
  final DateTime createdAt;
  final bool isArchived;

  EnrollmentModel({
    required this.id,
    required this.classId, // <-- Giờ là trường bắt buộc
    required this.joinDate, // <-- Thêm mới để định danh lớp
    required this.studentUid,
    required this.createdAt,
    required this.isArchived,
  });

  // Factory constructor để tạo instance từ Firestore document
  factory EnrollmentModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EnrollmentModel(
      id: doc.id,
      // Đọc danh sách ID môn học từ Firestore
      classId: d['classId'] ?? '', // Tên lớp
      joinDate: ((d['v'] as Timestamp?) ?? Timestamp.now()).toDate(), // Mã lớp
      studentUid: d['studentUid'] ?? '',
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isArchived: d['isArchived'] ?? false,
    );
  }

  // Hàm để chuyển đổi model thành Map để ghi vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'joinDate': Timestamp.fromDate(joinDate),
      'studentUid': studentUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
    };
  }

  // Hàm copyWith để tạo instance mới với một số trường thay đổi
  EnrollmentModel copyWith({
    String? id,
    String? classId,
    DateTime? joinDate,
    String? studentUid,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      joinDate: joinDate ?? this.joinDate,
      studentUid: studentUid ?? this.studentUid,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
