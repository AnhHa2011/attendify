import '../../../../app_imports.dart';

class CourseEnrollmentModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;
  final String courseCode; // Tên môn học, ví dụ: "Lớp Tín chỉ IT - K15"
  final DateTime joinDate; // Mã môn học, ví dụ: "LTC_IT_K15_01"
  final String studentUid;
  final DateTime createdAt;
  final bool isArchived;

  CourseEnrollmentModel({
    required this.id,
    required this.courseCode, // <-- Giờ là trường bắt buộc
    required this.joinDate, // <-- Thêm mới để định danh môn
    required this.studentUid,
    required this.createdAt,
    required this.isArchived,
  });

  // Factory constructor để tạo instance từ Firestore document
  factory CourseEnrollmentModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CourseEnrollmentModel(
      id: doc.id,
      // Đọc danh sách ID môn học từ Firestore
      courseCode: d['courseCode'] ?? '', // Tên môn
      joinDate: ((d['v'] as Timestamp?) ?? Timestamp.now()).toDate(), // Mã môn
      studentUid: d['studentUid'] ?? '',
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isArchived: d['isArchived'] ?? false,
    );
  }

  // Hàm để chuyển đổi model thành Map để ghi vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'joinDate': Timestamp.fromDate(joinDate),
      'studentUid': studentUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
    };
  }

  // Hàm copyWith để tạo instance mới với một số trường thay đổi
  CourseEnrollmentModel copyWith({
    String? id,
    String? courseCode,
    DateTime? joinDate,
    String? studentUid,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return CourseEnrollmentModel(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      joinDate: joinDate ?? this.joinDate,
      studentUid: studentUid ?? this.studentUid,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
