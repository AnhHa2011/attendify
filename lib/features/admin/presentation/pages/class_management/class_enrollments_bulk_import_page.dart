// lib/features/admin/presentation/pages/class_management/class_enrollments_bulk_import_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';

// Sheet structure (per class):
// Row1: courseCode | lecturerEmail | semester | className (headers)
// Row2: values
// Row4: studentEmail | studentDisplayName | studentCode (headers)
// Row5+: students

const _classHeaders = ['courseCode', 'lecturerEmail', 'semester', 'className'];
const _studentHeaders = ['studentEmail', 'studentDisplayName', 'studentCode'];
const _ignoreSheets = {'README', 'LOOKUPS'};

class _StudentRow {
  final int rowIndex; // row index in sheet
  String email;
  String displayName;
  String studentCode;

  String? studentUid; // match to existing student
  bool createStudent = false; // create new user if not matched
  String? error;

  _StudentRow({
    required this.rowIndex,
    required this.email,
    required this.displayName,
    required this.studentCode,
  });
}

class _ClassSheet {
  final String sheetName;

  // class meta (row 2)
  String courseCode;
  String lecturerEmail;
  String semester;
  String className;

  // resolved ids / create flags
  String? courseId;
  String? lecturerId;
  bool createCourse = false;
  bool createLecturer = false;

  // students
  final List<_StudentRow> students;

  String? error; // class-level error

  _ClassSheet({
    required this.sheetName,
    required this.courseCode,
    required this.lecturerEmail,
    required this.semester,
    required this.className,
    required this.students,
  });
}

class ClassEnrollmentsBulkImportPage extends StatefulWidget {
  const ClassEnrollmentsBulkImportPage({super.key});

  @override
  State<ClassEnrollmentsBulkImportPage> createState() =>
      _ClassEnrollmentsBulkImportPageState();
}

class _ClassEnrollmentsBulkImportPageState
    extends State<ClassEnrollmentsBulkImportPage> {
  List<_ClassSheet> _sheets = [];
  String? _fileName;
  bool _submitting = false;
  String? _message;
  bool _allValid = false;

  // ===== Validation =====
  bool _validStudent(_StudentRow s) {
    final okEmail = s.email.trim().isNotEmpty;
    final okMap = (s.studentUid != null) || s.createStudent;
    s.error = null;
    if (!okEmail) s.error = 'Thiếu email sinh viên.';
    if (!okMap) {
      s.error = (s.error == null)
          ? 'Chưa chọn SV hoặc đánh dấu "Tạo SV mới".'
          : '${s.error} Chưa chọn SV hoặc đánh dấu "Tạo SV mới".';
    }
    return s.error == null;
  }

  bool _validClass(_ClassSheet c) {
    final okCourse = (c.courseId != null) || c.createCourse;
    final okLecturer = (c.lecturerId != null) || c.createLecturer;
    final okSemester = c.semester.trim().isNotEmpty;
    final okName = c.className.trim().isNotEmpty;

    c.error = null;
    if (!okCourse) c.error = 'Chưa chọn Course (hoặc tạo mới).';
    if (!okLecturer) {
      c.error = (c.error == null)
          ? 'Chưa chọn Giảng viên (hoặc tạo mới).'
          : '${c.error} Chưa chọn Giảng viên (hoặc tạo mới).';
    }
    if (!okSemester) {
      c.error = (c.error == null)
          ? 'Thiếu Semester.'
          : '${c.error} Thiếu Semester.';
    }
    if (!okName) {
      c.error = (c.error == null)
          ? 'Thiếu tên lớp.'
          : '${c.error} Thiếu tên lớp.';
    }

    // students
    final okStudents = c.students.isNotEmpty && c.students.every(_validStudent);
    if (!okStudents) {
      c.error = (c.error == null)
          ? 'Danh sách sinh viên có dòng chưa hợp lệ.'
          : '${c.error} Danh sách sinh viên có dòng chưa hợp lệ.';
    }
    return c.error == null;
  }

  void _recomputeValidity() {
    for (final s in _sheets) {
      for (final st in s.students) {
        _validStudent(st);
      }
      _validClass(s);
    }
    _allValid = _sheets.isNotEmpty && _sheets.every(_validClass);
  }

  // ===== File pick & parse =====
  Future<void> _pickFile() async {
    setState(() {
      _sheets = [];
      _message = null;
      _fileName = null;
      _allValid = false;
    });
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null) {
      return;
    }
    final bytes = res.files.single.bytes!;
    final name = res.files.single.name;

    try {
      final parsed = await _parseWorkbook(bytes);
      setState(() {
        _sheets = parsed;
        _fileName = name;
        _recomputeValidity();
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_ClassSheet>> _parseWorkbook(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('Workbook không có sheet dữ liệu.');
    }
    final out = <_ClassSheet>[];

    for (final entry in excel.tables.entries) {
      final sheetName = entry.key.toString().trim();
      if (_ignoreSheets.contains(sheetName.toUpperCase())) continue;
      final tb = entry.value;
      if (tb.rows.isEmpty) continue;

      // Validate class headers row (row 1)
      final headerRow = tb.rows.first
          .map((c) => (c?.value?.toString() ?? '').trim())
          .toList();
      final normalized = headerRow.map((h) => h.toLowerCase()).toList();
      for (final h in _classHeaders) {
        if (!normalized.contains(h.toLowerCase())) {
          // allow empty sheet to be skipped silently
          continue;
        }
      }

      // Values row (row 2)
      final values = <String, String>{};
      for (
        var j = 0;
        j < headerRow.length &&
            j < (tb.rows.length >= 2 ? tb.rows[1].length : 0);
        j++
      ) {
        final key = headerRow[j];
        if (key.isEmpty) continue;
        values[key] = (tb.rows[1][j]?.value?.toString() ?? '').trim();
      }
      final courseCode = (values['courseCode'] ?? '').trim();
      final lecturerMail = (values['lecturerEmail'] ?? '').trim();
      final semester = (values['semester'] ?? '').trim();
      final className = (values['className'] ?? '').trim();
      if ([
        courseCode,
        lecturerMail,
        semester,
        className,
      ].every((e) => e.isEmpty)) {
        // empty sheet -> skip
        continue;
      }

      // Student header at row 4
      if (tb.rows.length < 4) {
        throw Exception(
          'Sheet "$sheetName" thiếu phần danh sách sinh viên (từ hàng 4).',
        );
      }
      final stuHeader = tb.rows[3]
          .map((c) => (c?.value?.toString() ?? '').trim())
          .toList();
      final stuNorm = stuHeader.map((h) => h.toLowerCase()).toList();
      for (final h in _studentHeaders) {
        if (!stuNorm.contains(h.toLowerCase())) {
          throw Exception('Sheet "$sheetName" thiếu cột sinh viên: $h');
        }
      }

      // Students from row 5+
      final students = <_StudentRow>[];
      for (var i = 4; i < tb.rows.length; i++) {
        final row = tb.rows[i];
        if (row.isEmpty) continue;
        final map = <String, dynamic>{};
        for (var j = 0; j < stuHeader.length && j < row.length; j++) {
          final key = stuHeader[j];
          if (key.isEmpty) continue;
          map[key] = row[j]?.value;
        }
        final email = (map['studentEmail'] ?? '').toString().trim();
        final name = (map['studentDisplayName'] ?? '').toString().trim();
        final code = (map['studentCode'] ?? '').toString().trim();
        if ([email, name, code].every((x) => x.isEmpty)) {
          continue; // skip empty line
        }
        students.add(
          _StudentRow(
            rowIndex: i + 1,
            email: email,
            displayName: name,
            studentCode: code,
          ),
        );
      }

      out.add(
        _ClassSheet(
          sheetName: sheetName,
          courseCode: courseCode,
          lecturerEmail: lecturerMail,
          semester: semester,
          className: className,
          students: students,
        ),
      );
    }
    return out;
  }

  // ===== create dialogs (course/lecturer/student) =====
  Future<void> _createCourseDialog(_ClassSheet c) async {
    final codeCtrl = TextEditingController(text: c.courseCode);
    final nameCtrl = TextEditingController();
    final creditsCtrl = TextEditingController(text: '3');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo môn học mới'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'courseCode'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'courseName'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              TextFormField(
                controller: creditsCtrl,
                decoration: const InputDecoration(labelText: 'credits'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Nhập số' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final admin = context.read<AdminService>();
      await admin.createCourse(
        courseCode: codeCtrl.text.trim(),
        courseName: nameCtrl.text.trim(),
        credits: int.parse(creditsCtrl.text.trim()),
      );
      setState(() {
        c.courseCode = codeCtrl.text.trim();
        c.createCourse = false;
        _recomputeValidity();
      });
    }
  }

  Future<void> _createLecturerDialog(_ClassSheet c) async {
    final emailCtrl = TextEditingController(text: c.lecturerEmail);
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo giảng viên mới'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Email không hợp lệ'
                    : null,
              ),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'displayName'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'mật khẩu tạm'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? '≥ 6 ký tự' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final admin = context.read<AdminService>();
      await admin.createNewUser(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        displayName: nameCtrl.text.trim(),
        role: UserRole.lecture,
      );
      setState(() {
        c.lecturerEmail = emailCtrl.text.trim();
        c.createLecturer = false;
        _recomputeValidity();
      });
    }
  }

  Future<void> _createStudentDialog(_StudentRow s) async {
    final emailCtrl = TextEditingController(text: s.email);
    final nameCtrl = TextEditingController(text: s.displayName);
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo sinh viên mới'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Email không hợp lệ'
                    : null,
              ),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'displayName'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'mật khẩu tạm'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? '≥ 6 ký tự' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final admin = context.read<AdminService>();
      await admin.createNewUser(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        displayName: nameCtrl.text.trim(),
        role: UserRole.student,
      );
      setState(() {
        s.email = emailCtrl.text.trim();
        s.displayName = nameCtrl.text.trim();
        s.createStudent = false;
        _recomputeValidity();
      });
    }
  }

  // ===== Submit =====
  Future<void> _submit(
    List<CourseModel> courses,
    List<UserModel> lecturers,
    List<UserModel> students,
  ) async {
    _recomputeValidity();
    setState(() {});
    if (!_allValid) {
      setState(() {
        _message =
            'Có sheet/dòng chưa hợp lệ. Hãy sửa hoặc xoá trước khi import.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    final admin = context.read<AdminService>();

    try {
      for (final sheet in _sheets) {
        // resolve course & lecturer ids (mapping theo current lists)
        if (sheet.courseId == null) {
          final ci = courses.indexWhere(
            (c) =>
                c.courseCode.toUpperCase().trim() ==
                sheet.courseCode.toUpperCase().trim(),
          );
          if (ci != -1) sheet.courseId = courses[ci].id;
        }
        if (sheet.lecturerId == null) {
          final ui = lecturers.indexWhere(
            (u) =>
                u.email.toLowerCase().trim() ==
                sheet.lecturerEmail.toLowerCase().trim(),
          );
          if (ui != -1) sheet.lecturerId = lecturers[ui].uid;
        }

        // ensure course/lecturer exist if "create" flags are set
        if (sheet.courseId == null && sheet.createCourse) {
          await admin.createCourse(
            courseCode: sheet.courseCode,
            courseName: sheet.className,
            credits: 3,
          );
          sheet.courseId = await admin.getCourseIdByCode(sheet.courseCode);
        }
        if (sheet.lecturerId == null && sheet.createLecturer) {
          // không tạo thêm ở đây vì đã có dialog tạo GV; fallback: tìm lại UID theo email
          sheet.lecturerId = await admin.getUserIdByEmail(sheet.lecturerEmail);
        }

        // 1) create class, get classId
        final classId = await admin.createClassRaw(
          className: sheet.className,
          courseId: sheet.courseId!,
          lecturerId: sheet.lecturerId!,
          semester: sheet.semester,
        );

        // 2) resolve students (and create if asked)
        for (final s in sheet.students) {
          if (s.studentUid == null) {
            final ui = students.indexWhere(
              (u) =>
                  u.email.toLowerCase().trim() == s.email.toLowerCase().trim(),
            );
            if (ui != -1) s.studentUid = students[ui].uid;
          }
          if (s.studentUid == null && s.createStudent) {
            // đã có dialog tạo; fallback: lookup theo email
            s.studentUid = await admin.getUserIdByEmail(s.email);
          }
          if (s.studentUid != null) {
            await admin.addEnrollment(
              classId: classId,
              studentUid: s.studentUid!,
            );
          }
        }
      }
      setState(() {
        _message = 'Import thành công: ${_sheets.length} lớp + enrollments.';
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi khi import: $e';
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import lớp + enrollments (Excel, multi-sheet)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CourseModel>>(
          stream: admin.getAllCoursesStream(),
          builder: (_, courseSnap) {
            final courses = courseSnap.data ?? [];

            // auto-match courseId
            for (final s in _sheets) {
              if (s.courseId == null) {
                final i = courses.indexWhere(
                  (c) =>
                      c.courseCode.toUpperCase().trim() ==
                      s.courseCode.toUpperCase().trim(),
                );
                if (i >= 0) s.courseId = courses[i].id;
              }
            }

            return StreamBuilder<List<UserModel>>(
              stream: admin.getAllLecturersStream(),
              builder: (_, lecSnap) {
                final lecturers = lecSnap.data ?? [];

                for (final s in _sheets) {
                  if (s.lecturerId == null) {
                    final i = lecturers.indexWhere(
                      (u) =>
                          u.email.toLowerCase().trim() ==
                          s.lecturerEmail.toLowerCase().trim(),
                    );
                    if (i >= 0) s.lecturerId = lecturers[i].uid;
                  }
                }

                return StreamBuilder<List<UserModel>>(
                  stream: admin.getUsersStreamByRole(UserRole.student),
                  builder: (_, stuSnap) {
                    final students = stuSnap.data ?? [];

                    // auto-match students
                    for (final sheet in _sheets) {
                      for (final st in sheet.students) {
                        if (st.studentUid == null && st.email.isNotEmpty) {
                          final idx = students.indexWhere(
                            (u) =>
                                u.email.toLowerCase().trim() ==
                                st.email.toLowerCase().trim(),
                          );
                          if (idx >= 0) st.studentUid = students[idx].uid;
                        }
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mỗi sheet là 1 lớp: Row1 headers, Row2 values, Row4 headers SV, Row5+ danh sách SV.',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Chọn file .xlsx'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed:
                                  (_sheets.isNotEmpty &&
                                      _allValid &&
                                      !_submitting)
                                  ? () => _submit(courses, lecturers, students)
                                  : null,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: _submitting
                                  ? const Text('Đang nhập...')
                                  : const Text('Thực hiện'),
                            ),
                          ],
                        ),
                        if (_fileName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'File: $_fileName',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _message!,
                            style: TextStyle(
                              color: _message!.startsWith('Lỗi')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Expanded(
                          child: _sheets.isEmpty
                              ? const Center(
                                  child: Text('Chưa có dữ liệu xem trước'),
                                )
                              : ListView.separated(
                                  itemCount: _sheets.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final cs = _sheets[i];
                                    return Card(
                                      elevation: 0,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.class_outlined,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${cs.sheetName}: ${cs.className} — ${cs.semester}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Xoá sheet',
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _sheets.removeAt(i);
                                                      _recomputeValidity();
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // Course resolve
                                            Row(
                                              children: [
                                                const Text('Course: '),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: DropdownButtonFormField<String?>(
                                                    initialValue: cs.courseId,
                                                    isExpanded: true,
                                                    items:
                                                        <
                                                          DropdownMenuItem<
                                                            String?
                                                          >
                                                        >[
                                                          const DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: null,
                                                            child: Text(
                                                              '— Chưa chọn —',
                                                            ),
                                                          ),
                                                          ...courses.map(
                                                            (c) =>
                                                                DropdownMenuItem<
                                                                  String?
                                                                >(
                                                                  value: c.id,
                                                                  child: Text(
                                                                    '${c.courseCode} — ${c.courseName}',
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                    onChanged: (val) {
                                                      setState(() {
                                                        cs.courseId = val;
                                                        cs.createCourse = false;
                                                        _recomputeValidity();
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  selected: cs.createCourse,
                                                  label: const Text(
                                                    'Tạo course mới',
                                                  ),
                                                  onSelected: (v) async {
                                                    if (v) {
                                                      await _createCourseDialog(
                                                        cs,
                                                      );
                                                    } else {
                                                      setState(
                                                        () => cs.createCourse =
                                                            false,
                                                      );
                                                    }
                                                    _recomputeValidity();
                                                  },
                                                ),
                                              ],
                                            ),
                                            // Lecturer resolve
                                            Row(
                                              children: [
                                                const Text('Giảng viên: '),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: DropdownButtonFormField<String?>(
                                                    initialValue: cs.lecturerId,
                                                    isExpanded: true,
                                                    items:
                                                        <
                                                          DropdownMenuItem<
                                                            String?
                                                          >
                                                        >[
                                                          const DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: null,
                                                            child: Text(
                                                              '— Chưa chọn —',
                                                            ),
                                                          ),
                                                          ...lecturers.map(
                                                            (u) =>
                                                                DropdownMenuItem<
                                                                  String?
                                                                >(
                                                                  value: u.uid,
                                                                  child: Text(
                                                                    '${u.displayName} — ${u.email}',
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                    onChanged: (val) {
                                                      setState(() {
                                                        cs.lecturerId = val;
                                                        cs.createLecturer =
                                                            false;
                                                        _recomputeValidity();
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  selected: cs.createLecturer,
                                                  label: const Text(
                                                    'Tạo giảng viên mới',
                                                  ),
                                                  onSelected: (v) async {
                                                    if (v) {
                                                      await _createLecturerDialog(
                                                        cs,
                                                      );
                                                    } else {
                                                      setState(
                                                        () =>
                                                            cs.createLecturer =
                                                                false,
                                                      );
                                                    }
                                                    _recomputeValidity();
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            if (cs.error != null)
                                              Text(
                                                cs.error!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            ExpansionTile(
                                              leading: const Icon(
                                                Icons.people_outline,
                                              ),
                                              title: Text(
                                                'Danh sách sinh viên (${cs.students.length})',
                                              ),
                                              children: [
                                                ...cs.students.asMap().entries.map((
                                                  e,
                                                ) {
                                                  final st = e.value;
                                                  return ListTile(
                                                    contentPadding:
                                                        const EdgeInsets.only(
                                                          left: 12,
                                                          right: 0,
                                                        ),
                                                    title: Text(
                                                      '${st.rowIndex}. ${st.email}  ${st.displayName.isNotEmpty ? "— ${st.displayName}" : ""}',
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Text(
                                                              'Khớp với: ',
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Flexible(
                                                              child: DropdownButtonFormField<String?>(
                                                                initialValue: st
                                                                    .studentUid,
                                                                isExpanded:
                                                                    true,
                                                                items:
                                                                    <
                                                                      DropdownMenuItem<
                                                                        String?
                                                                      >
                                                                    >[
                                                                      const DropdownMenuItem<
                                                                        String?
                                                                      >(
                                                                        value:
                                                                            null,
                                                                        child: Text(
                                                                          '— Chưa chọn —',
                                                                        ),
                                                                      ),
                                                                      ...students.map(
                                                                        (u) =>
                                                                            DropdownMenuItem<
                                                                              String?
                                                                            >(
                                                                              value: u.uid,
                                                                              child: Text(
                                                                                '${u.displayName} — ${u.email}',
                                                                              ),
                                                                            ),
                                                                      ),
                                                                    ],
                                                                onChanged: (val) {
                                                                  setState(() {
                                                                    st.studentUid =
                                                                        val;
                                                                    st.createStudent =
                                                                        false;
                                                                    _recomputeValidity();
                                                                  });
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            FilterChip(
                                                              selected: st
                                                                  .createStudent,
                                                              label: const Text(
                                                                'Tạo SV mới',
                                                              ),
                                                              onSelected: (v) async {
                                                                if (v) {
                                                                  await _createStudentDialog(
                                                                    st,
                                                                  );
                                                                } else {
                                                                  setState(
                                                                    () => st.createStudent =
                                                                        false,
                                                                  );
                                                                }
                                                                _recomputeValidity();
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                        if (st.error != null)
                                                          Text(
                                                            st.error!,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                    trailing: IconButton(
                                                      tooltip: 'Xoá SV',
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          cs.students.removeAt(
                                                            e.key,
                                                          );
                                                          _recomputeValidity();
                                                        });
                                                      },
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
