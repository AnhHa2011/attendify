import '../../../../app_imports.dart';

class ClassModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;
  final String className; // Tên lớp học, ví dụ: "Lớp Tín chỉ IT - K15"
  final String classCode; // Mã lớp học, ví dụ: "LTC_IT_K15_01"
  final String joinCode;
  final DateTime createdAt;
  final bool isArchived;
  final int academicYearStart;
  final int academicYearEnd;

  ClassModel({
    required this.id,
    required this.className, // <-- Giờ là trường bắt buộc
    required this.classCode, // <-- Thêm mới để định danh lớp
    required this.joinCode,
    required this.createdAt,
    required this.isArchived,
    required this.academicYearStart,
    required this.academicYearEnd,
  });

  // Factory constructor để tạo instance từ Firestore document
  factory ClassModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      // Đọc danh sách ID môn học từ Firestore
      className: d['className'] ?? '', // Tên lớp
      classCode: d['classCode'] ?? '', // Mã lớp
      joinCode: d['joinCode'] ?? '',
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isArchived: d['isArchived'] ?? false,
      academicYearStart: d['academicYearStart'] ?? 1990,
      academicYearEnd: d['academicYearEnd'] ?? 1990,
    );
  }

  // Hàm để chuyển đổi model thành Map để ghi vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'classCode': classCode,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
      'academicYearStart': academicYearStart,
      'academicYearEnd': academicYearEnd,
    };
  }

  // Hàm copyWith để tạo instance mới với một số trường thay đổi
  ClassModel copyWith({
    String? id,
    String? className,
    String? classCode,
    String? joinCode,
    DateTime? createdAt,
    bool? isArchived,
    int? academicYearStart,
    int? academicYearEnd,
  }) {
    return ClassModel(
      id: id ?? this.id,
      className: className ?? this.className,
      classCode: classCode ?? this.classCode,
      joinCode: joinCode ?? this.joinCode,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      academicYearStart: academicYearStart ?? this.academicYearStart,
      academicYearEnd: academicYearEnd ?? this.academicYearEnd,
    );
  }
}
