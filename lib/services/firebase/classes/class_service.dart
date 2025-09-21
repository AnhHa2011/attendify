import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/course_model.dart';
import '../../../data/models/user_model.dart';

class ClassService {
  final _db = FirebaseFirestore.instance;

  String _randomCode([int len = 6]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // // Tạo lớp (admin chọn GV hoặc GV tự tạo cho mình)
  // Future<String> createClass({
  //   required String lecturerId,
  //   required String lecturerName,
  //   required String lecturerEmail,
  //   required String className,
  //   required String classCode,
  //   required List<ClassSchedule> schedules,
  //   required int maxAbsences,
  // }) async {
  //   final joinCode = _randomCode();
  //   final now = DateTime.now();

  //   final ref = await _db.collection('classes').add({
  //     'className': className,
  //     'classCode': classCode,
  //     'lecturerId': lecturerId,
  //     'lecturerName': lecturerName,
  //     'lecturerEmail': lecturerEmail,
  //     'schedules': schedules.map((e) => e.toMap()).toList(),
  //     'maxAbsences': maxAbsences,
  //     'joinCode': joinCode,
  //     'createdAt': now, // hiển thị tức thì
  //     'createdAtServer': FieldValue.serverTimestamp(),
  //   });
  //   return ref.id;
  // }

  Future<void> enrollStudent({
    required String joinCode,
    required String studentUid,
    required String studentName,
    required String studentEmail,
  }) async {
    // 1. Tìm lớp học có mã tham gia tương ứng
    final classQuery = await _db
        .collection('classes')
        .where('joinCode', isEqualTo: joinCode.trim())
        .limit(1)
        .get();

    if (classQuery.docs.isEmpty) {
      throw Exception('Mã tham gia không hợp lệ hoặc lớp học không tồn tại.');
    }

    final classDoc = classQuery.docs.first;
    final classId = classDoc.id;

    final existingEnrollmentQuery = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    // Nếu đã tìm thấy bản ghi enrollment, nghĩa là sinh viên đã ở trong lớp
    if (existingEnrollmentQuery.docs.isNotEmpty) {
      throw Exception('Bạn đã tham gia lớp học này rồi.');
    }
    // =================================================================

    // 2. Nếu chưa tham gia, tạo một bản ghi mới trong collection 'enrollments'
    await _db.collection('enrollments').add({
      'classId': classId,
      'className': classDoc.data()['className'],
      'studentUid': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'joinDate': FieldValue.serverTimestamp(),
    });
  }

  /// Lấy danh sách sinh viên đã tham gia lớp, bao gồm cả ID của bản ghi enrollment
  Future<List<Map<String, dynamic>>> getEnrolledStudents(String classId) async {
    final List<Map<String, dynamic>> students = [];
    try {
      // 1. Lấy tất cả các bản ghi enrollment của lớp học
      final enrollmentsQuery = await _db
          .collection('enrollments')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in enrollmentsQuery.docs) {
        final data = doc.data();
        // 2. Thêm thông tin sinh viên VÀ ID của enrollment vào danh sách
        students.add({
          // QUAN TRỌNG: Thêm dòng này để lấy ID cho việc xoá
          'enrollmentId': doc.id,
          'displayName': data['studentName'],
          'email': data['studentEmail'],
          'uid': data['studentUid'], // Có thể cần dùng sau này
        });
      }
    } catch (e) {
      print('Error getting enrolled students: $e');
      // Trả về danh sách rỗng nếu có lỗi
    }
    return students;
  }

  /// Xoá một sinh viên khỏi lớp học dựa trên ID của bản ghi enrollment
  Future<void> removeStudentFromClass(String enrollmentId) async {
    try {
      await _db.collection('enrollments').doc(enrollmentId).delete();
    } catch (e) {
      // Ném ra lỗi để UI có thể bắt và hiển thị thông báo
      throw Exception('Đã xảy ra lỗi khi xoá sinh viên: $e');
    }
  }

  /// Lấy tổng số sinh viên đã tham gia một lớp học
  Future<int> getEnrolledStudentCount(String classId) async {
    try {
      final snapshot = await _db
          .collection('enrollments')
          .where('classId', isEqualTo: classId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting student count: $e');
      return 0;
    }
  }

  /// Lắng nghe MỘT lớp học và "làm giàu" nó với thông tin môn học + giảng viên
  Stream<ClassModel> getRichClassStream(String classId) {
    // 1. Lắng nghe document class cụ thể
    return _db.collection('classes').doc(classId).snapshots().asyncMap((
      classDoc,
    ) async {
      if (!classDoc.exists) {
        throw Exception('Lớp học không tồn tại!');
      }

      final classModel = ClassModel.fromDoc(classDoc);

      try {
        // 2. Lấy thông tin môn học (một lần)
        final courseDoc = await _db
            .collection('courses')
            .doc(classModel.courseId)
            .get();
        final courseData = courseDoc.data();

        // 3. Lấy thông tin giảng viên (một lần)
        final lecturerDoc = await _db
            .collection('users')
            .doc(classModel.lecturerId)
            .get();
        final lecturerData = lecturerDoc.data();

        // 4. Trả về model đã được "làm giàu" bằng hàm copyWith
        return classModel.copyWith(
          courseName: courseData?['courseName'],
          courseCode: courseData?['courseCode'],
          lecturerName: lecturerData?['displayName'],
        );
      } catch (e) {
        print('Error enriching class $classId: $e');
        // Trả về dữ liệu gốc nếu có lỗi (ví dụ: môn học bị xóa)
        return classModel;
      }
    });
  }

  /// Lấy danh sách lớp học đã được "làm giàu" của MỘT giảng viên
  Stream<List<ClassModel>> getRichClassesStreamForLecturer(String lecturerId) {
    return _db
        .collection('classes')
        .where('isArchived', isEqualTo: false) // Lọc theo giảng viên
        .snapshots()
        .asyncMap((classSnapshot) async {
          // Đoạn code "làm giàu" dữ liệu giống hệt hàm getRichClassesStream()
          final classes = classSnapshot.docs
              .map((doc) => ClassModel.fromDoc(doc))
              .toList();
          if (classes.isEmpty) return [];

          final richClassFutures = classes.map((classModel) async {
            try {
              final courseDoc = await _db
                  .collection('courses')
                  .doc(classModel.courseId)
                  .get();
              final lecturerDoc = await _db
                  .collection('users')
                  .doc(classModel.lecturerId)
                  .get();
              return classModel.copyWith(
                courseName: courseDoc.data()?['courseName'],
                courseCode: courseDoc.data()?['courseCode'],
                lecturerName: lecturerDoc.data()?['displayName'],
              );
            } catch (e) {
              return classModel;
            }
          }).toList();
          return await Future.wait(richClassFutures);
        });
  }

  /// Lấy danh sách các lớp học đã "làm giàu" mà MỘT sinh viên đã tham gia
  Stream<List<ClassModel>> getRichEnrolledClassesStream(String studentId) {
    // 1. Lắng nghe collection 'enrollments' để tìm các lớp của sinh viên
    return _db
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) {
            return []; // Sinh viên này chưa tham gia lớp nào
          }

          // 2. Lấy ra danh sách các classId
          final classIds = enrollmentSnapshot.docs
              .map((doc) => doc.data()['classId'] as String)
              .toList();

          if (classIds.isEmpty) {
            return [];
          }

          // 3. Lấy thông tin chi tiết cho từng lớp học
          // Chúng ta sẽ lấy dữ liệu từ collection 'classes' nơi mà ID nằm trong danh sách classIds
          final classQuery = await _db
              .collection('classes')
              .where(FieldPath.documentId, whereIn: classIds)
              .get();

          final classes = classQuery.docs
              .map((doc) => ClassModel.fromDoc(doc))
              .toList();

          // 4. "Làm giàu" dữ liệu cho từng lớp (giống như các hàm trước)
          final richClassFutures = classes.map((classModel) async {
            try {
              final courseDoc = await _db
                  .collection('courses')
                  .doc(classModel.courseId)
                  .get();
              final lecturerDoc = await _db
                  .collection('users')
                  .doc(classModel.lecturerId)
                  .get();
              return classModel.copyWith(
                courseName: courseDoc.data()?['courseName'],
                courseCode: courseDoc.data()?['courseCode'],
                lecturerName: lecturerDoc.data()?['displayName'],
              );
            } catch (e) {
              return classModel; // Trả về dữ liệu gốc nếu có lỗi
            }
          }).toList();

          return await Future.wait(richClassFutures);
        });
  }

  // Hàm mới để lấy danh sách tất cả môn học
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _db
        .collection('courses')
        // SỬA DÒNG NÀY:
        // .where('isArchived', isNotEqualTo: true) // Dòng cũ
        .where('isArchived', whereIn: [null, false]) // Dòng mới
        .orderBy('courseCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  // Sửa lại hàm createClass để nhận ID thay vì tên
  Future<String> createClass({
    required String courseId, // THAY ĐỔI
    required String lecturerId, // THAY ĐỔI
    required String semester, // THAY ĐỔI
    required List<ClassSchedule> schedules,
    required int maxAbsences,
  }) async {
    final now = DateTime.now();
    // Tạo mã tham gia ngẫu nhiên
    final joinCode = _generateRandomCode(6);

    final ref = await _db.collection('classes').add({
      'courseId': courseId,
      'lecturerId': lecturerId,
      'semester': semester,
      'schedules': schedules.map((e) => e.toMap()).toList(),
      'maxAbsences': maxAbsences,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(now),
    });

    return ref.id;
  }

  // Bạn có thể giữ lại hàm tạo mã ngẫu nhiên này
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  /// Lấy danh sách lớp học đã được "làm giàu" với thông tin môn học và giảng viên
  Stream<List<ClassModel>> getRichClassesStream() {
    // 1. Lắng nghe sự thay đổi từ collection 'classes'
    return _db.collection('classes').snapshots().asyncMap((
      classSnapshot,
    ) async {
      final classes = classSnapshot.docs
          .map((doc) => ClassModel.fromDoc(doc))
          .toList();

      if (classes.isEmpty) {
        return []; // Trả về danh sách rỗng nếu không có lớp nào
      }

      // 2. Tạo một danh sách các "công việc" cần làm
      final richClassFutures = classes.map((classModel) async {
        try {
          // Lấy thông tin môn học
          final courseDoc = await _db
              .collection('courses')
              .doc(classModel.courseId)
              .get();
          final courseData = courseDoc.data();

          // Lấy thông tin giảng viên
          final lecturerDoc = await _db
              .collection('users')
              .doc(classModel.lecturerId)
              .get();
          final lecturerData = lecturerDoc.data();

          // 3. Dùng hàm copyWith để tạo ra một ClassModel mới với dữ liệu đã làm giàu
          return classModel.copyWith(
            courseName: courseData?['courseName'],
            courseCode: courseData?['courseCode'],
            lecturerName: lecturerData?['displayName'],
          );
        } catch (e) {
          // Nếu có lỗi (ví dụ: courseId không tồn tại), trả về model gốc
          print('Error enriching class ${classModel.id}: $e');
          return classModel;
        }
      }).toList();

      // 4. Chạy tất cả các "công việc" song song và trả về kết quả
      return await Future.wait(richClassFutures);
    });
  }

  // === Streams cho Admin/Lecturer/Student ===
  Stream<List<ClassModel>> allClasses() {
    return _db
        .collection('classes')
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClassModel.fromDoc(d)).toList());
  }

  Stream<List<ClassModel>> classesOfLecturer(String lecturerUid) {
    return _db
        .collection('classes')
        .where('lecturerId', isEqualTo: lecturerUid)
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClassModel.fromDoc(d)).toList());
  }

  /// Student: lấy các lớp mà SV đã enroll (collection 'enrollments')
  /// enrollments doc: { classId, studentUid, joinedAt }
  Stream<List<ClassModel>> classesOfStudent(String studentUid) {
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .asyncMap((enrollSnap) async {
          final futures = enrollSnap.docs.map((e) async {
            final classId = (e.data()['classId'] as String);
            final cDoc = await _db.collection('classes').doc(classId).get();
            if (!cDoc.exists) return null;
            return ClassModel.fromDoc(cDoc);
          });
          final list = await Future.wait(futures);
          return list.whereType<ClassModel>().toList();
        });
  }

  // Chi tiết lớp & members
  Stream<ClassModel> classStream(String classId) => _db
      .collection('classes')
      .doc(classId)
      .snapshots()
      .map(ClassModel.fromDoc);

  Stream<List<Map<String, dynamic>>> membersStream(String classId) {
    return _db
        .collection('classes')
        .doc(classId)
        .collection('members')
        // .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> removeMember(String classId, String uid) async {
    await _db
        .collection('classes')
        .doc(classId)
        .collection('members')
        .doc(uid)
        .delete();
  }

  Future<void> regenerateJoinCode(String classId) async {
    await _db.collection('classes').doc(classId).update({
      'joinCode': _randomCode(),
    });
  }

  // Admin filter: danh sách giảng viên (users.role == 'lecture')
  Stream<List<Map<String, String>>> lecturersStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'lecture')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final m = d.data();
            return {
              'uid': d.id,
              'name': (m['displayName'] ?? '') as String,
              'email': (m['email'] ?? '') as String,
            };
          }).toList(),
        );
  }
}
