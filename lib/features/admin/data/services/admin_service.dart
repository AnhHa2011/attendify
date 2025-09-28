import '../../../../app_imports.dart';
import '../../../../core/data/models/class_model.dart';
import '../../../../core/data/models/course_model.dart';
import '../../../../core/data/models/course_schedule_model.dart';
import '../../../../core/data/models/lecturer_lite.dart';
import '../../../../core/data/models/session_model.dart';
import '../../../../core/data/models/user_model.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ───────────────────────────
  // QUẢN LÝ NGƯỜI DÙNG (USERS)
  // ───────────────────────────

  /// Chỉ Admin mới được phép gửi email đặt lại mật khẩu cho user khác.
  /// Kiểm tra role của currentUser trong Firestore: users/{uid}.role == 'admin'
  Future<void> sendPasswordResetForUserAsAdmin(String targetEmail) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    // check role from Firestore
    final meDoc = await _db.collection('users').doc(current.uid).get();
    final role = (meDoc.data()?['role'] ?? '').toString().toLowerCase();

    if (role != 'admin' && role != 'it') {
      // tùy cách đặt tên role, ở đây cho phép 'admin' hoặc 'it'
      throw Exception('Chỉ Admin mới có quyền gửi email đặt lại mật khẩu.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: targetEmail.trim());
    } on FirebaseAuthException catch (e) {
      // Firebase có thể không ném lỗi nếu email không tồn tại (tránh dò tài khoản),
      // nhưng nếu có lỗi khác thì surface ra:
      throw Exception('Gửi email reset thất bại: ${e.message}');
    } catch (_) {
      throw Exception('Đã có lỗi khi gửi email đặt lại mật khẩu.');
    }
  }

  /// Send reset password email to a user
  Future<void> sendPasswordResetForUser(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Hàm này trả về đúng kiểu List<UserModel>.
  Stream<List<UserModel>> getUsersStreamByRole(UserRole role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role.toKey())
        .snapshots()
        .map(
          (snapshot) =>
              // Chuyển đổi mỗi document thành một đối tượng UserModel
              snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList(),
        );
  }

  /// Lấy danh sách tất cả giảng viên (sử dụng hàm trên)
  // Stream<List<UserModel>> getAllLecturersStream() {
  //   return getUsersStreamByRole(UserRole.lecture);
  // }

  Stream<List<UserModel>> getAllLecturersStream() {
    return _db
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'lecture')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList(),
        );
  }

  /// Lấy danh sách tất cả sinh viên (sử dụng hàm trên)
  Stream<List<UserModel>> getAllStudentsStream() {
    return getUsersStreamByRole(UserRole.student);
  }

  /// Tạo một người dùng mới (bao gồm cả Auth và Firestore)
  Future<void> createNewUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      // B1: Tạo người dùng trong Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // B2: Lấy UID từ người dùng vừa tạo
      String uid = userCredential.user!.uid;

      // B3: Cập nhật displayName trong Auth (tùy chọn nhưng nên có)
      await userCredential.user!.updateDisplayName(displayName);

      // B4: Tạo document trong collection 'users' của Firestore
      await _db.collection('users').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'role': role.toKey(),
        'createdAt': Timestamp.now().toDate(),
      });
    } on FirebaseAuthException catch (e) {
      // Bắt các lỗi cụ thể từ Firebase Auth để thông báo dễ hiểu hơn
      if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email này đã được sử dụng bởi một tài khoản khác.');
      }
      throw Exception('Lỗi tạo tài khoản: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Cập nhật thông tin người dùng trong Firestore
  Future<void> updateUser({
    required String uid,
    required String displayName,
    required UserRole role,
  }) {
    return _db.collection('users').doc(uid).update({
      'displayName': displayName,
      'role': role.toKey(),
    });
  }

  /// Xoá người dùng (chỉ xoá trong Firestore)
  /// LƯU Ý: Xoá người dùng khỏi Firebase Authentication từ client là một hành động
  /// nhạy cảm và thường được thực hiện qua Cloud Functions để đảm bảo an toàn.
  /// Ở đây chúng ta chỉ xoá bản ghi trong Firestore.
  Future<void> deleteUser(String uid) {
    return _db.collection('users').doc(uid).delete();
  }
  // === QUẢN LÝ lớp HỌC (COURSES) ===

  /// Tạo lịch học hàng loạt cho nhiều tuần liên tiếp
  Future<void> createRecurringSessions({
    required String courseCode,
    required String location,
    required int durationInMinutes,
    required int numberOfWeeks,
    required List<CourseSchedule> weeklySchedules,
    required DateTime semesterStartDate,
  }) async {
    final batch = _db.batch();

    for (int week = 0; week < numberOfWeeks; week++) {
      for (final schedule in weeklySchedules) {
        DateTime sessionDate = semesterStartDate.add(Duration(days: week * 7));
        sessionDate = sessionDate.add(
          Duration(days: schedule.dayOfWeek - sessionDate.weekday),
        );

        final startTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          schedule.startTime.hour,
          schedule.startTime.minute,
        );

        final docRef = _db.collection('sessions').doc();
        batch.set(docRef, {
          'courseCode': courseCode,
          'title':
              'Buổi ${(week * weeklySchedules.length) + weeklySchedules.indexOf(schedule) + 1}',
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(
            startTime.add(Duration(minutes: durationInMinutes)),
          ),
          'location': location,
          'status': 'scheduled',
          'type': 'lecture',
          'attendanceOpen': false,
        });
      }
    }

    await batch.commit();
  }

  // === THÊM HÀM MỚI NÀY VÀO ===
  /// Lấy danh sách thông tin chi tiết của các môn học dựa vào danh sách ID
  Future<List<CourseModel>> getCoursesByIds(List<String> ids) async {
    // Nếu danh sách ID rỗng, trả về danh sách rỗng để tránh lỗi truy vấn
    if (ids.isEmpty) return [];

    // Firestore cho phép truy vấn tối đa 30 item trong mệnh đề 'whereIn'
    // Nếu có thể có nhiều hơn, bạn cần chia nhỏ ra thành nhiều truy vấn
    final snapshot = await _db
        .collection('courses')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    return snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList();
  }

  // === QUẢN LÝ lớp HỌC (COURSES) ===

  /// Tạo một lớp học mới
  /// Tạo 1 lớp học mới theo schema của ClassModel
  Future<String> createClass({
    required String classCode,
    required String className,
    int minStudents = 10,
    int maxStudents = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    List<String> enrolledStudents = const [],
    bool isArchived = false,
  }) async {
    final data =
        <String, dynamic>{
          'classCode': classCode.trim().toUpperCase(),
          'className': className.trim(),
          'isArchived': isArchived,
          'minStudents': minStudents,
          'maxStudents': maxStudents,
          'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
          'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
          'enrolledStudents': enrolledStudents,
          'description': description,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        }..removeWhere(
          (k, v) => v == null,
        ); // bỏ các key null để Firestore gọn gàng

    final docRef = await _db.collection(FirestoreCollections.classes).add(data);
    return docRef.id;
  }

  /// Cập nhật thông tin lớp học theo document id (ClassModel.id)
  Future<void> updateClass({
    required String id, // document id
    String? classCode, // nếu đổi mã lớp
    String? className,
    bool? isArchived,
    int? minStudents,
    int? maxStudents,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    List<String>? enrolledStudents, // tuỳ nhu cầu cập nhật danh sách
  }) async {
    final data = <String, dynamic>{
      if (classCode != null) 'classCode': classCode.trim().toUpperCase(),
      if (className != null) 'className': className.trim(),
      if (isArchived != null) 'isArchived': isArchived,
      if (minStudents != null) 'minStudents': minStudents,
      if (maxStudents != null) 'maxStudents': maxStudents,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate),
      if (description != null) 'description': description,
      if (enrolledStudents != null) 'enrolledStudents': enrolledStudents,
      'updatedAt': Timestamp.now(),
    };

    await _db.collection(FirestoreCollections.classes).doc(id).update(data);
  }

  Future<void> deleteClass(String classCode) {
    return _db.collection(FirestoreCollections.classes).doc(classCode).delete();
  }

  /// === THAY ĐỔI: Chuyển từ Xoá cứng sang Xoá mềm (Lưu trữ) ===
  /// Đánh dấu một lớp học là đã được lưu trữ.
  Future<void> archiveClass(String classCode) {
    return _db.collection(FirestoreCollections.classes).doc(classCode).update({
      'isArchived': true, // Thêm một trường để đánh dấu
    });
  }

  /// === THAY ĐỔI: Lọc ra các lớp học đã bị lưu trữ ===
  /// Lấy danh sách các lớp học CHƯA bị lưu trữ.
  Stream<List<ClassModel>> getAllClassStream() {
    return _db
        .collection('classes')
        // Query này sẽ chỉ lấy các document có isArchived != true
        // (bao gồm cả các document chưa có trường isArchived)
        .where('isArchived', isNotEqualTo: true)
        .orderBy('classCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ClassModel.fromDoc(doc)).toList(),
        );
  }

  // === THÊM MỚI: Hàm kiểm tra mã lớp học đã tồn tại hay chưa ===
  /// Trả về `true` nếu mã lớp học đã được sử dụng bởi một lớp học khác.
  /// `currentclassCode` được dùng trong trường hợp Chỉnh sửa, để loại trừ chính lớp học đang sửa ra khỏi
  /// việc kiểm tra.
  Future<bool> isClassCodeTaken(String code, {String? currentclassCode}) async {
    // Luôn chuẩn hoá code trước khi query
    final normalizedCode = code.trim().toUpperCase();

    Query query = _db
        .collection('classes')
        .where('classCode', isEqualTo: normalizedCode)
        .limit(1);

    final querySnapshot = await query.get();

    // Nếu không tìm thấy document nào, mã chắc chắn chưa tồn tại
    if (querySnapshot.docs.isEmpty) {
      return false;
    }

    // Nếu đang ở chế độ chỉnh sửa, kiểm tra xem document tìm thấy có phải là document
    // đang sửa hay không
    if (currentclassCode != null) {
      // Nếu ID của doc tìm thấy khác với ID đang sửa -> mã đã bị lấy
      return querySnapshot.docs.first.id != currentclassCode;
    }

    // Nếu đang ở chế độ tạo mới và tìm thấy document -> mã đã bị lấy
    return true;
  }

  Future<bool> isCourseCodeTaken(
    String code, {
    String? currentcourseCode,
  }) async {
    // Luôn chuẩn hoá code trước khi query
    final normalizedCode = code.trim().toUpperCase();

    Query query = _db
        .collection('courses')
        .where('courseCode', isEqualTo: normalizedCode)
        .limit(1);

    final querySnapshot = await query.get();

    // Nếu không tìm thấy document nào, mã chắc chắn chưa tồn tại
    if (querySnapshot.docs.isEmpty) {
      return false;
    }

    // Nếu đang ở chế độ chỉnh sửa, kiểm tra xem document tìm thấy có phải là document
    // đang sửa hay không
    if (currentcourseCode != null) {
      // Nếu ID của doc tìm thấy khác với ID đang sửa -> mã đã bị lấy
      return querySnapshot.docs.first.id != currentcourseCode;
    }

    // Nếu đang ở chế độ tạo mới và tìm thấy document -> mã đã bị lấy
    return true;
  }

  /// Lấy danh sách tất cả môn học cho Admin, đã được "làm giàu" thông tin
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _db
        .collection('courses')
        .where('isArchived', isEqualTo: false) // Giữ lại logic lọc
        .snapshots()
        .asyncMap((snapshot) async {
          // Chuyển đổi DocumentSnapshot thành List<CourseModel>
          final courseFutures = snapshot.docs.map((doc) async {
            final courseModel = CourseModel.fromDoc(doc);

            // Chỉ làm giàu thông tin giảng viên
            try {
              final lecturerDoc = await _db
                  .collection('users')
                  .doc(courseModel.lecturerId)
                  .get();

              // Sử dụng copyWith để thêm thông tin giảng viên
              // return courseModel.copyWith(
              //   lecturerName: lecturerDoc.data()?['displayName'],
              // );
              return courseModel;
            } catch (e) {
              // Nếu có lỗi khi lấy thông tin GV, vẫn trả về thông tin môn học gốc
              return courseModel;
            }
          }).toList();

          // Đợi tất cả các future hoàn thành và trả về kết quả
          return Future.wait(courseFutures);
        });
  }

  /// Lấy danh sách tất cả môn học cho Admin, đã được "làm giàu" thông tin
  Stream<List<ClassModel>> getAllClassesStream() {
    return _db
        .collection('classes')
        .where('isArchived', isEqualTo: false) // Giữ lại logic lọc
        .orderBy('createdAt', descending: true) // Giữ lại logic sắp xếp
        .snapshots()
        .asyncMap((snapshot) async {
          // Chuyển đổi DocumentSnapshot thành List<ClassModel>
          final classFutures = snapshot.docs.map((doc) async {
            return ClassModel.fromDoc(doc);
          }).toList();

          // Đợi tất cả các future hoàn thành và trả về kết quả
          return Future.wait(classFutures);
        });
  }

  Future<void> createCourse({
    required String? lecturerId,
    required String courseName, // Tên môn học, ví dụ: "môn Tín chỉ IT - K15"
    required String courseCode, // Mã môn học, ví dụ: "LTC_IT_K15_01"
    required String joinCode,
    required int? credits,
    required String? semester,
    required String? description,
    required int? totalStudents,
    required int? minStudents,
    required int? maxStudents,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final joinCode =
        _generateRandomCode(); // Giả sử bạn có hàm tạo mã ngẫu nhiên

    await _db.collection('courses').add({
      'lecturerId': lecturerId,
      'courseName': courseName,
      'courseCode': courseCode,
      'joinCode': joinCode,
      'credits': credits,
      'semester': semester,
      'description': description,
      'totalStudents': totalStudents,
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'startDate': startDate,
      'endDate': endDate,
      'createdAt': Timestamp.now().toDate(),
      'updatedAt': Timestamp.now().toDate(),
      'isArchived': false,
    });
  }

  Future<void> updateCourse({
    required String id,
    required String? lecturerId,
    required String courseName, // Tên môn học, ví dụ: "môn Tín chỉ IT - K15"
    required String courseCode, // Mã môn học, ví dụ: "LTC_IT_K15_01"
    required String joinCode,
    required int? credits,
    required String? semester,
    required String? description,
    required int? minStudents,
    required int? maxStudents,
    required DateTime? startDate,
    required DateTime? endDate, // <<<--- Bổ sung
  }) async {
    await _db.collection('courses').doc(id).update({
      'lecturerId': lecturerId,
      'courseName': courseName,
      'courseCode': courseCode,
      'joinCode': joinCode,
      'credits': credits,
      'semester': semester,
      'description': description,
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'startDate': startDate,
      'endDate': endDate,
      'updatedAt': Timestamp.now().toDate(),
    });
  }

  /// Lưu trữ một môn học (xoá mềm)
  Future<void> archiveCourse(String courseCode) {
    return _db.collection('courses').doc(courseCode).update({
      'isArchived': true,
      'updatedAt': Timestamp.now().toDate(),
    });
  }

  Future<bool> isCourseDuplicate({
    required String courseCode,
    String? currentcourseCode,
  }) async {
    Query query = _db
        .collection('courses')
        .where('courseCode', isEqualTo: courseCode);

    // Nếu đang ở chế độ sửa, loại trừ chính môn hiện tại ra khỏi kiểm tra
    if (currentcourseCode != null) {
      query = query.where(
        FieldPath.documentId,
        isNotEqualTo: currentcourseCode,
      );
    }

    final snapshot = await query.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  // Bạn có thể cần thêm hàm này nếu chưa có
  String _generateRandomCode([int len = 6]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Tạo nhiều môn học từ một danh sách (dùng cho import file)
  Future<void> createcoursesFromList(
    List<Map<String, dynamic>> courseDataList,
  ) async {
    final batch = _db.batch();

    // Để tối ưu, lấy tất cả môn học và giảng viên về 1 lần để tra cứu
    final coursesSnapshot = await _db.collection('courses').get();
    final lecturersSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'lecture')
        .get();

    final courseMap = {
      for (var doc in coursesSnapshot.docs) doc.data()['courseCode']: doc.id,
    };
    final lecturerMap = {
      for (var doc in lecturersSnapshot.docs) doc.data()['email']: doc.id,
    };

    for (final courseData in courseDataList) {
      final courseCode = courseData['courseCode'];
      final lecturerEmail = courseData['lecturerEmail'];

      final lecturerId = lecturerMap[lecturerEmail];

      if (courseCode != null && lecturerId != null) {
        final docRef = _db.collection('courses').doc();
        batch.set(docRef, {
          'courseCode': courseCode,
          'lecturerId': lecturerId,
          'semester': courseData['semester'],
          'courseName': courseData['courseName'],
          'isArchived': false,
          'createdAt': Timestamp.now().toDate(),
          'joinCode': '',
        });
      }
    }
    await batch.commit();
  }

  // === THÊM MỚI: CÁC HÀM QUẢN LÝ BUỔI HỌC (SESSIONS) ===

  /// Tạo một buổi học đơn lẻ cho một môn học
  Future<void> createSingleSession({
    required String courseCode,
    required DateTime startTime,
    required int durationInMinutes,
    required String location,
  }) async {
    await _db.collection('sessions').add({
      'courseCode': courseCode,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(
        startTime.add(Duration(minutes: durationInMinutes)),
      ),
      'location': location,
      'status': 'scheduled', // Trạng thái ban đầu
      'type': 'lecture',
      'attendanceOpen': false,
    });
  }

  Stream<List<SessionModel>> getSessionsForCourseStream(String courseCode) {
    return _db
        .collection('sessions')
        .where('courseCode', isEqualTo: courseCode)
        .orderBy(
          'startTime',
          descending: false,
        ) // Sắp xếp buổi học sớm nhất lên đầu
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList(),
        );
  }

  // === THÊM MỚI: CÁC HÀM QUẢN LÝ VIỆC GHI DANH (ENROLLMENT) ===

  /// Lấy danh sách sinh viên ĐÃ CÓ trong một môn học
  Stream<List<UserModel>> getEnrolledStudentsStream(String courseCode) {
    return _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];
          final studentIds = snapshot.docs
              .map((doc) => doc['studentUid'] as String)
              .toList();
          final studentsSnapshot = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();
          return studentsSnapshot.docs
              .map((doc) => UserModel.fromDoc(doc))
              .toList();
        });
  }

  /// Ghi danh MỘT sinh viên vào môn học
  Future<void> enrollSingleStudent(String courseCode, String studentUid) async {
    // Kiểm tra xem sinh viên đã có trong môn chưa để tránh trùng lặp
    final existing = await _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Sinh viên này đã có trong môn học.');
    }

    await _db.collection('enrollments').add({
      'courseCode': courseCode,
      'studentUid': studentUid,
      'joinDate': Timestamp.now().toDate(),
    });
  }

  /// Hủy ghi danh MỘT sinh viên khỏi môn học
  Future<void> unenrollStudent(String courseCode, String studentUid) async {
    final snapshot = await _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    }
  }

  /// Ghi danh HÀNG LOẠT sinh viên từ một danh sách email (dùng cho import file)
  Future<Map<String, String>> enrollStudentsFromEmails(
    String courseCode,
    List<String> emails,
  ) async {
    final batch = _db.batch();
    Map<String, String> results = {'success': '', 'failed': ''};
    List<String> successEmails = [];
    List<String> failedEmails = [];

    // Lấy tất cả sinh viên có email trong danh sách
    final usersSnapshot = await _db
        .collection('users')
        .where('email', whereIn: emails)
        .get();
    final studentMap = {
      for (var doc in usersSnapshot.docs) doc.data()['email']: doc.id,
    };

    for (final email in emails) {
      final studentUid = studentMap[email];
      if (studentUid != null) {
        // Tạo một document mới trong collection 'enrollments'
        final docRef = _db.collection('enrollments').doc();
        batch.set(docRef, {
          'courseCode': courseCode,
          'studentUid': studentUid,
          'joinDate': Timestamp.now().toDate(),
        });
        successEmails.add(email);
      } else {
        failedEmails.add(email);
      }
    }

    await batch.commit();
    results['success'] = successEmails.join(', ');
    results['failed'] = failedEmails.join(', ');
    return results;
  }

  /// Import (upsert) courses từ danh sách: {courseCode, courseName, credits}
  /// Trả về: {created, updated, skipped}
  Future<Map<String, int>> importCoursesFromList(
    List<Map<String, dynamic>> courseRows,
  ) async {
    int created = 0, updated = 0, skipped = 0;
    final snapshot = await _db.collection('courses').get();
    final map = {
      for (var d in snapshot.docs) (d.data()['courseCode'] ?? ''): d.id,
    };

    final batch = _db.batch();
    for (final r in courseRows) {
      final code = (r['courseCode'] ?? '').toString().trim();
      final name = (r['courseName'] ?? '').toString().trim();
      final credits = r['credits'] is int
          ? r['credits']
          : int.tryParse('${r['credits']}');
      if (code.isEmpty || name.isEmpty || credits == null) {
        skipped++;
        continue;
      }

      final existingId = map[code];
      if (existingId != null && existingId.toString().isNotEmpty) {
        final docRef = _db.collection('courses').doc(existingId);
        batch.update(docRef, {
          'courseCode': code,
          'courseName': name,
          'credits': credits,
        });
        updated++;
      } else {
        final docRef = _db.collection('courses').doc();
        batch.set(docRef, {
          'courseCode': code,
          'courseName': name,
          'credits': credits,
          'isArchived': false,
        });
        created++;
      }
    }
    await batch.commit();
    return {'created': created, 'updated': updated, 'skipped': skipped};
  }

  /// Import courses từ danh sách: {courseCode, lecturerEmail, semester, courseName}
  /// Trả về: {created, skipped}
  Future<Map<String, int>> importcoursesFromList(
    List<Map<String, dynamic>> courseRows,
  ) async {
    int created = 0, skipped = 0;

    final coursesSnapshot = await _db.collection('courses').get();
    final lecturersSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'lecture')
        .get();

    final courseMap = {
      for (var doc in coursesSnapshot.docs) doc.data()['courseCode']: doc.id,
    };
    final lecturerMap = {
      for (var doc in lecturersSnapshot.docs) doc.data()['email']: doc.id,
    };

    final batch = _db.batch();
    for (final r in courseRows) {
      final courseCode = (r['courseCode'] ?? '').toString().trim();
      final lecturerEmail = (r['lecturerEmail'] ?? '').toString().trim();
      final semester = (r['semester'] ?? '').toString().trim();
      final courseName = (r['courseName'] ?? '').toString().trim();

      final lecturerId = lecturerMap[lecturerEmail];
      if (courseCode == null || lecturerId == null || semester.isEmpty) {
        skipped++;
        continue;
      }

      final docRef = _db.collection('courses').doc();
      batch.set(docRef, {
        'courseCode': courseCode,
        'lecturerId': lecturerId,
        'semester': semester,
        'courseName': courseName,
        'isArchived': false,
        'createdAt': Timestamp.now().toDate(),
        'joinCode': '',
      });
      created++;
    }
    await batch.commit();
    return {'created': created, 'skipped': skipped};
  }

  // === Helpers: tra id theo code/email ===
  Future<String?> getcourseCodeByCode(String courseCode) async {
    final snap = await _db
        .collection('courses')
        .where('courseCode', isEqualTo: courseCode)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<String?> getUserIdByEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id; // hoặc 'uid' tuỳ schema; nếu docId==uid thì OK
  }

  // === Tạo course và trả về id ===
  Future<String> createCourseRaw({
    required String courseName,
    required String courseCode,
    required String lecturerId,
    required String semester,
  }) async {
    final ref = await _db.collection('courses').add({
      'courseName': courseName,
      'courseCode': courseCode,
      'lecturerId': lecturerId,
      'semester': semester,
      'createdAt': Timestamp.now().toDate(),
      'isArchived': false,
      'joinCode': '',
    });
    return ref.id;
  }

  // === Thêm enrollment (bỏ qua nếu đã tồn tại) ===
  Future<void> addEnrollment({
    required String courseCode,
    required String studentUid,
  }) async {
    final q = await _db
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return;
    await _db.collection('enrollments').add({
      'courseCode': courseCode,
      'studentUid': studentUid,
      'joinDate': Timestamp.now().toDate(),
    });
  }

  /// Lấy danh sách giảng viên (một lần) cho dropdown
  Future<List<LecturerLite>> fetchLecturers() async {
    final snap = await _db
        .collection(FirestoreCollections.users) // hoặc 'users'
        .where('role', isEqualTo: 'lecture')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      final displayName = (data['displayName'] ?? data['email'] ?? 'Giảng viên')
          .toString();
      final email = (data['email'] ?? '').toString();
      return LecturerLite(uid: d.id, displayName: displayName, email: email);
    }).toList();
  }
}
