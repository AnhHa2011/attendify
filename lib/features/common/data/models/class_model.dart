import '../../../../app_imports.dart';

class ClassModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;

  // THAY ĐỔI CỐT LÕI: Thay vì 1 courseId, giờ là danh sách các courseIds
  final List<String> courseIds;

  final String lecturerId;
  final String semester;
  final String className; // Tên lớp học, ví dụ: "Lớp Tín chỉ IT - K15"
  final String classCode; // Mã lớp học, ví dụ: "LTC_IT_K15_01"
  final String joinCode;
  final DateTime createdAt;
  final bool isArchived;

  // === Dữ liệu "làm giàu" (lấy từ các collection khác) ===
  final String? lecturerName;

  ClassModel({
    required this.id,
    required this.courseIds, // <-- THAY ĐỔI
    required this.lecturerId,
    required this.semester,
    required this.className, // <-- Giờ là trường bắt buộc
    required this.classCode, // <-- Thêm mới để định danh lớp
    required this.joinCode,
    required this.createdAt,
    required this.isArchived,
    this.lecturerName,
  });

  // Factory constructor để tạo instance từ Firestore document
  factory ClassModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      // Đọc danh sách ID môn học từ Firestore
      courseIds: List<String>.from(d['courseIds'] ?? []),
      lecturerId: d['lecturerId'] ?? '',
      semester: d['semester'] ?? '',
      className: d['className'] ?? '', // Tên lớp
      classCode: d['classCode'] ?? '', // Mã lớp
      joinCode: d['joinCode'] ?? '',
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isArchived: d['isArchived'] ?? false,
      // lecturerName có thể được thêm vào sau khi fetch thông tin giảng viên
    );
  }

  // Hàm để chuyển đổi model thành Map để ghi vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseIds': courseIds,
      'lecturerId': lecturerId,
      'semester': semester,
      'className': className,
      'classCode': classCode,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
      'lecturerName': lecturerName, // Lưu sẵn tên GV để đọc nhanh
    };
  }

  // Hàm copyWith để tạo instance mới với một số trường thay đổi
  ClassModel copyWith({
    String? id,
    List<String>? courseIds,
    String? lecturerId,
    String? semester,
    String? className,
    String? classCode,
    String? joinCode,
    DateTime? createdAt,
    bool? isArchived,
    String? lecturerName,
  }) {
    return ClassModel(
      id: id ?? this.id,
      courseIds: courseIds ?? this.courseIds,
      lecturerId: lecturerId ?? this.lecturerId,
      semester: semester ?? this.semester,
      className: className ?? this.className,
      classCode: classCode ?? this.classCode,
      joinCode: joinCode ?? this.joinCode,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      lecturerName: lecturerName ?? this.lecturerName,
    );
  }
}
