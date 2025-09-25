import '../../../../app_imports.dart';

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
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
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
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
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
        'createdAt': FieldValue.serverTimestamp(),
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
  // === QUẢN LÝ LỚP HỌC (CLASSES) ===

  /// Tạo lịch học hàng loạt cho nhiều tuần liên tiếp
  Future<void> createRecurringSessions({
    required String classId,
    required String courseId,
    required String baseTitle,
    required String location,
    required int durationInMinutes,
    required int numberOfWeeks,
    required List<ClassSchedule> weeklySchedules,
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
          'classId': classId,
          'courseId': courseId,
          'title':
              '$baseTitle - Buổi ${(week * weeklySchedules.length) + weeklySchedules.indexOf(schedule) + 1}',
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

  // === QUẢN LÝ MÔN HỌC (COURSES) ===

  /// Tạo một môn học mới
  Future<void> createCourse({
    required String courseCode,
    required String courseName,
    required int credits,
    String? lecturerId, // NEW (optional)
    int? minStudents, // NEW (optional)
    int? maxStudents, // NEW (optional)
    List<Map<String, dynamic>>? weeklySchedule, // NEW (optional)
  }) {
    final data = <String, dynamic>{
      'courseCode': courseCode.trim().toUpperCase(),
      'courseName': courseName.trim(),
      'credits': credits,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (lecturerId != null) data['lecturerId'] = lecturerId;
    if (minStudents != null) data['minStudents'] = minStudents;
    if (maxStudents != null) data['maxStudents'] = maxStudents;
    if (weeklySchedule != null) data['weeklySchedule'] = weeklySchedule;

    return _db.collection(FirestoreCollections.courses).add(data);
  }

  /// ===  Cập nhật thông tin một môn học ===
  Future<void> updateCourse({
    required String courseId,
    required String courseCode,
    required String courseName,
    required int credits,
    String? lecturerId, // NEW (optional)
    int? minStudents, // NEW (optional)
    int? maxStudents, // NEW (optional)
    List<Map<String, dynamic>>? weeklySchedule, // NEW (optional)
  }) {
    final data = <String, dynamic>{
      'courseCode': courseCode.trim().toUpperCase(),
      'courseName': courseName.trim(),
      'credits': credits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Chỉ update các trường nếu có truyền vào (tránh xóa dữ liệu cũ)
    if (lecturerId != null) data['lecturerId'] = lecturerId;
    if (minStudents != null) data['minStudents'] = minStudents;
    if (maxStudents != null) data['maxStudents'] = maxStudents;
    if (weeklySchedule != null) data['weeklySchedule'] = weeklySchedule;

    return _db
        .collection(FirestoreCollections.courses)
        .doc(courseId)
        .update(data);
  }

  /// ===  Xoá một môn học ===
  Future<void> deleteCourse(String courseId) {
    return _db.collection('courses').doc(courseId).delete();
  }

  /// === THAY ĐỔI: Chuyển từ Xoá cứng sang Xoá mềm (Lưu trữ) ===
  /// Đánh dấu một môn học là đã được lưu trữ.
  Future<void> archiveCourse(String courseId) {
    return _db.collection('courses').doc(courseId).update({
      'isArchived': true, // Thêm một trường để đánh dấu
    });
  }

  /// === THAY ĐỔI: Lọc ra các môn học đã bị lưu trữ ===
  /// Lấy danh sách các môn học CHƯA bị lưu trữ.
  Stream<List<CourseModel>> getAllCoursesStream() {
    return _db
        .collection('courses')
        // Query này sẽ chỉ lấy các document có isArchived != true
        // (bao gồm cả các document chưa có trường isArchived)
        .where('isArchived', isNotEqualTo: true)
        .orderBy('courseCode')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  // === THÊM MỚI: Hàm kiểm tra mã môn học đã tồn tại hay chưa ===
  /// Trả về `true` nếu mã môn học đã được sử dụng bởi một môn học khác.
  /// `currentCourseId` được dùng trong trường hợp Chỉnh sửa, để loại trừ chính môn học đang sửa ra khỏi
  /// việc kiểm tra.
  Future<bool> isCourseCodeTaken(String code, {String? currentCourseId}) async {
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
    if (currentCourseId != null) {
      // Nếu ID của doc tìm thấy khác với ID đang sửa -> mã đã bị lấy
      return querySnapshot.docs.first.id != currentCourseId;
    }

    // Nếu đang ở chế độ tạo mới và tìm thấy document -> mã đã bị lấy
    return true;
  }

  /// Lấy danh sách tất cả lớp học cho Admin, đã được "làm giàu" thông tin
  Stream<List<ClassModel>> getAllClassesStream() {
    return _db
        .collection('classes')
        .where('isArchived', isEqualTo: false) // Giữ lại logic lọc
        .orderBy('createdAt', descending: true) // Giữ lại logic sắp xếp
        .snapshots()
        .asyncMap((snapshot) async {
          // Chuyển đổi DocumentSnapshot thành List<ClassModel>
          final classFutures = snapshot.docs.map((doc) async {
            final classModel = ClassModel.fromDoc(doc);

            // Chỉ làm giàu thông tin giảng viên
            try {
              final lecturerDoc = await _db
                  .collection('users')
                  .doc(classModel.lecturerId)
                  .get();

              // Sử dụng copyWith để thêm thông tin giảng viên
              return classModel.copyWith(
                lecturerName: lecturerDoc.data()?['displayName'],
              );
            } catch (e) {
              // Nếu có lỗi khi lấy thông tin GV, vẫn trả về thông tin lớp học gốc
              return classModel;
            }
          }).toList();

          // Đợi tất cả các future hoàn thành và trả về kết quả
          return Future.wait(classFutures);
        });
  }

  Future<void> createClass({
    required List<String> courseIds, // <<<--- THAY ĐỔI
    required String lecturerId,
    required String semester,
    required String className, // <<<--- Bổ sung
    required String classCode, // <<<--- Bổ sung
  }) async {
    final joinCode =
        _generateRandomCode(); // Giả sử bạn có hàm tạo mã ngẫu nhiên

    await _db.collection('classes').add({
      'courseIds': courseIds, // Lưu danh sách ID môn học
      'lecturerId': lecturerId,
      'semester': semester,
      'className': className,
      'classCode': classCode,
      'joinCode': joinCode,
      'createdAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    });
  }

  Future<void> updateClass({
    required String classId,
    required List<String> courseIds, // <<<--- THAY ĐỔI
    required String lecturerId,
    required String semester,
    required String className, // <<<--- Bổ sung
    required String classCode, // <<<--- Bổ sung
  }) async {
    await _db.collection('classes').doc(classId).update({
      'courseIds': courseIds,
      'lecturerId': lecturerId,
      'semester': semester,
      'className': className,
      'classCode': classCode,
    });
  }

  /// Lưu trữ một lớp học (xoá mềm)
  Future<void> archiveClass(String classId) {
    return _db.collection('classes').doc(classId).update({'isArchived': true});
  }

  Future<bool> isClassDuplicate({
    required String classCode,
    String? currentClassId,
  }) async {
    Query query = _db
        .collection('classes')
        .where('classCode', isEqualTo: classCode);

    // Nếu đang ở chế độ sửa, loại trừ chính lớp hiện tại ra khỏi kiểm tra
    if (currentClassId != null) {
      query = query.where(FieldPath.documentId, isNotEqualTo: currentClassId);
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

  /// Tạo nhiều lớp học từ một danh sách (dùng cho import file)
  Future<void> createClassesFromList(
    List<Map<String, dynamic>> classDataList,
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

    for (final classData in classDataList) {
      final courseCode = classData['courseCode'];
      final lecturerEmail = classData['lecturerEmail'];

      final courseId = courseMap[courseCode];
      final lecturerId = lecturerMap[lecturerEmail];

      if (courseId != null && lecturerId != null) {
        final docRef = _db.collection('classes').doc();
        batch.set(docRef, {
          'courseId': courseId,
          'lecturerId': lecturerId,
          'semester': classData['semester'],
          'className': classData['className'],
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
          'joinCode': '',
        });
      }
    }
    await batch.commit();
  }

  // === THÊM MỚI: CÁC HÀM QUẢN LÝ BUỔI HỌC (SESSIONS) ===

  /// Tạo một buổi học đơn lẻ cho một lớp học
  Future<void> createSingleSession({
    required String classId,
    required String title,
    required String courseId,
    required DateTime startTime,
    required int durationInMinutes,
    required String location,
  }) async {
    await _db.collection('sessions').add({
      'classId': classId,
      'title': title,
      'courseId': courseId,
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

  Stream<List<SessionModel>> getSessionsForClassStream(String classId) {
    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        .orderBy(
          'startTime',
          descending: false,
        ) // Sắp xếp buổi học sớm nhất lên đầu
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // === THÊM MỚI: CÁC HÀM QUẢN LÝ VIỆC GHI DANH (ENROLLMENT) ===

  /// Lấy danh sách sinh viên ĐÃ CÓ trong một lớp học
  Stream<List<UserModel>> getEnrolledStudentsStream(String classId) {
    return _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
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
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Ghi danh MỘT sinh viên vào lớp học
  Future<void> enrollSingleStudent(String classId, String studentUid) async {
    // Kiểm tra xem sinh viên đã có trong lớp chưa để tránh trùng lặp
    final existing = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Sinh viên này đã có trong lớp học.');
    }

    await _db.collection('enrollments').add({
      'classId': classId,
      'studentUid': studentUid,
      'joinDate': FieldValue.serverTimestamp(),
    });
  }

  /// Hủy ghi danh MỘT sinh viên khỏi lớp học
  Future<void> unenrollStudent(String classId, String studentUid) async {
    final snapshot = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    }
  }

  /// Ghi danh HÀNG LOẠT sinh viên từ một danh sách email (dùng cho import file)
  Future<Map<String, String>> enrollStudentsFromEmails(
    String classId,
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
          'classId': classId,
          'studentUid': studentUid,
          'joinDate': FieldValue.serverTimestamp(),
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

  /// Import classes từ danh sách: {courseCode, lecturerEmail, semester, className}
  /// Trả về: {created, skipped}
  Future<Map<String, int>> importClassesFromList(
    List<Map<String, dynamic>> classRows,
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
    for (final r in classRows) {
      final courseCode = (r['courseCode'] ?? '').toString().trim();
      final lecturerEmail = (r['lecturerEmail'] ?? '').toString().trim();
      final semester = (r['semester'] ?? '').toString().trim();
      final className = (r['className'] ?? '').toString().trim();

      final courseId = courseMap[courseCode];
      final lecturerId = lecturerMap[lecturerEmail];
      if (courseId == null || lecturerId == null || semester.isEmpty) {
        skipped++;
        continue;
      }

      final docRef = _db.collection('classes').doc();
      batch.set(docRef, {
        'courseId': courseId,
        'lecturerId': lecturerId,
        'semester': semester,
        'className': className,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'joinCode': '',
      });
      created++;
    }
    await batch.commit();
    return {'created': created, 'skipped': skipped};
  }

  // === Helpers: tra id theo code/email ===
  Future<String?> getCourseIdByCode(String courseCode) async {
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

  // === Tạo class và trả về id ===
  Future<String> createClassRaw({
    required String className,
    required String courseId,
    required String lecturerId,
    required String semester,
  }) async {
    final ref = await _db.collection('classes').add({
      'className': className,
      'courseId': courseId,
      'lecturerId': lecturerId,
      'semester': semester,
      'createdAt': FieldValue.serverTimestamp(),
      'isArchived': false,
      'joinCode': '',
    });
    return ref.id;
  }

  // === Thêm enrollment (bỏ qua nếu đã tồn tại) ===
  Future<void> addEnrollment({
    required String classId,
    required String studentUid,
  }) async {
    final q = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('studentUid', isEqualTo: studentUid)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return;
    await _db.collection('enrollments').add({
      'classId': classId,
      'studentUid': studentUid,
      'joinDate': FieldValue.serverTimestamp(),
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
