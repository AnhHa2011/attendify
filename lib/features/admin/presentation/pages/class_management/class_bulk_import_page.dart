// lib/features/admin/presentation/pages/class_bulk_import_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../../common/utils/template_downloader.dart';
import '../../../data/services/admin_service.dart';

const _expectedHeaders = [
  'courseCode',
  'lecturerEmail',
  'semester',
  'className',
];

class _ClassRow {
  final int rowIndex;
  String courseCode;
  String lecturerEmail;
  String semester;
  String className;

  String? courseId; // course đã chọn trong dropdown
  String? lecturerId; // user đã chọn trong dropdown

  bool createCourse = false; // nếu chưa có course → tạo mới
  bool createLecturer = false; // nếu chưa có giảng viên → tạo mới

  String? error;

  _ClassRow({
    required this.rowIndex,
    required this.courseCode,
    required this.lecturerEmail,
    required this.semester,
    required this.className,
    this.createCourse = false,
    this.createLecturer = false,
  });
}

class ClassBulkImportPage extends StatefulWidget {
  const ClassBulkImportPage({super.key});

  @override
  State<ClassBulkImportPage> createState() => _ClassBulkImportPageState();
}

class _ClassBulkImportPageState extends State<ClassBulkImportPage> {
  List<_ClassRow> _rows = [];
  String? _fileName;
  bool _submitting = false;
  String? _message;
  bool _allValid = false;

  bool _rowValid(_ClassRow r) {
    // yêu cầu: course đã chọn hoặc chọn "tạo mới", lecturer đã chọn hoặc tạo mới,
    // semester & className không rỗng
    final okCourse = (r.courseId != null) || r.createCourse;
    final okLecturer = (r.lecturerId != null) || r.createLecturer;
    final okSemester = r.semester.trim().isNotEmpty;
    final okName = r.className.trim().isNotEmpty;

    r.error = null;
    if (!okCourse) r.error = 'Chưa chọn Course (hoặc tạo mới).';
    if (!okLecturer) {
      r.error = (r.error == null)
          ? 'Chưa chọn Giảng viên (hoặc tạo mới).'
          : '${r.error} Chưa chọn Giảng viên (hoặc tạo mới).';
    }
    if (!okSemester) {
      r.error = (r.error == null)
          ? 'Thiếu Semester.'
          : '${r.error} Thiếu Semester.';
    }
    if (!okName) {
      r.error = (r.error == null)
          ? 'Thiếu tên lớp.'
          : '${r.error} Thiếu tên lớp.';
    }
    return r.error == null;
  }

  void _recomputeValidity() {
    for (final r in _rows) {
      _rowValid(r); // set r.error
    }
    _allValid = _rows.isNotEmpty && _rows.every(_rowValid);
  }

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _message = null;
      _fileName = null;
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
      final rows = await _parseClassesXlsx(bytes);
      setState(() {
        _rows = rows;
        _fileName = name;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    }
  }

  Future<List<_ClassRow>> _parseClassesXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('File không có sheet nào.');

    // Ưu tiên sheet Classes/Class
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'classes' || lk == 'class') {
        tb = excel.tables[key];
        break;
      }
    }
    if (tb == null || tb.rows.isEmpty) throw Exception('Sheet rỗng.');

    final headerRow = tb.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    final normalized = headerRow.map((h) => h.toLowerCase()).toList();
    for (final h in _expectedHeaders) {
      if (!normalized.contains(h.toLowerCase())) {
        throw Exception('Thiếu cột bắt buộc: $h');
      }
    }

    final out = <_ClassRow>[];
    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      if (row.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue;
      }

      final map = <String, dynamic>{};
      for (var j = 0; j < headerRow.length && j < row.length; j++) {
        final key = headerRow[j];
        final val = row[j]?.value;
        if (key.isNotEmpty) map[key] = val;
      }

      final courseCode = (map['courseCode'] ?? '').toString().trim();
      final lecturerEmail = (map['lecturerEmail'] ?? '').toString().trim();
      final semester = (map['semester'] ?? '').toString().trim();
      final className = (map['className'] ?? '').toString().trim();

      if (courseCode.isEmpty || lecturerEmail.isEmpty || semester.isEmpty) {
        continue;
      }

      out.add(
        _ClassRow(
          rowIndex: i,
          courseCode: courseCode,
          lecturerEmail: lecturerEmail,
          semester: semester,
          className: className,
        ),
      );
    }
    return out;
  }

  Future<void> _createCourseDialog(_ClassRow r) async {
    final codeCtrl = TextEditingController(text: r.courseCode);
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
        r.courseCode = codeCtrl.text.trim();
        r.createCourse = false;
      });
    }
  }

  Future<void> _createLecturerDialog(_ClassRow r) async {
    final emailCtrl = TextEditingController(text: r.lecturerEmail);
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
        role: UserRole.lecture, // theo code hiện có: 'lecture'
      );
      setState(() {
        r.lecturerEmail = emailCtrl.text.trim();
        r.createLecturer = false;
      });
    }
  }

  Future<void> _submit(
    List<CourseModel> allCourses,
    List<UserModel> lecturers,
  ) async {
    if (_rows.isEmpty) return;

    for (final r in _rows) {
      r.error = null;
      final okCourse = (r.courseId != null) || (!r.createCourse);
      final okLecturer = (r.lecturerId != null) || (!r.createLecturer);
      if (!okCourse || !okLecturer) {
        r.error = 'Chưa chọn Course/User hoặc tạo mới.';
      }
    }
    setState(() {});
    if (_rows.any((e) => e.error != null)) return;

    // Chuẩn hóa lại courseCode / lecturerEmail theo lựa chọn dropdown (để backend map chính xác)
    for (final r in _rows) {
      if (r.courseId != null) {
        final ci = allCourses.indexWhere(
          (e) => e.id == r.courseId,
        ); // nếu model của bạn dùng field khác, đổi 'id' cho đúng
        if (ci != -1) {
          r.courseCode = allCourses[ci].courseCode;
        }
      }
      if (r.lecturerId != null) {
        final ui = lecturers.indexWhere(
          (e) => e.uid == r.lecturerId,
        ); // nếu model của bạn dùng field khác, đổi 'uid' cho đúng
        if (ui != -1) {
          r.lecturerEmail = lecturers[ui].email;
        }
      }
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final admin = context.read<AdminService>();
      // Tận dụng createClassesFromList có sẵn trong AdminService
      final payload = _rows
          .map(
            (r) => {
              'courseCode': r.courseCode,
              'lecturerEmail': r.lecturerEmail,
              'semester': r.semester,
              'className': r.className,
            },
          )
          .toList();

      await admin.createClassesFromList(payload);
      setState(() {
        _message = 'Tạo lớp học thành công.';
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi: $e';
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm lớp học từ Excel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CourseModel>>(
          stream: admin.getAllCoursesStream(),
          builder: (_, courseSnap) {
            final courses = courseSnap.data ?? [];

            // Auto-match course theo courseCode
            for (final r in _rows) {
              if (r.courseId == null) {
                final i = courses.indexWhere(
                  (c) =>
                      c.courseCode.toUpperCase().trim() ==
                      r.courseCode.toUpperCase().trim(),
                );
                if (i >= 0) r.courseId = courses[i].id;
              }
            }

            return StreamBuilder<List<UserModel>>(
              stream: admin.getAllLecturersStream(),
              builder: (_, lecSnap) {
                final lecturers = lecSnap.data ?? [];

                // Auto-match giảng viên theo email
                for (final r in _rows) {
                  if (r.lecturerId == null) {
                    final i = lecturers.indexWhere(
                      (u) =>
                          u.email.toLowerCase().trim() ==
                          r.lecturerEmail.toLowerCase().trim(),
                    );
                    if (i >= 0) r.lecturerId = lecturers[i].uid;
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⬇️ Thay vì Text 'Yêu cầu header', đưa 2 nút tải template
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Tải template lớp (.xlsx)'),
                          onPressed: () => TemplateDownloader.download('class'),
                        ),
                      ],
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
                              (_rows.isNotEmpty && _allValid && !_submitting)
                              ? () => _submit(courses, lecturers)
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
                      child: _rows.isEmpty
                          ? const Center(
                              child: Text('Chưa có dữ liệu xem trước'),
                            )
                          : ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final r = _rows[i];
                                return ListTile(
                                  leading: const Icon(Icons.school_outlined),
                                  title: Text(
                                    '${r.rowIndex}. ${r.className} — ${r.semester}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Resolver: COURSE
                                      Row(
                                        children: [
                                          const Text('Course: '),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: DropdownButtonFormField<String?>(
                                              initialValue: r.courseId,
                                              isExpanded: true,
                                              items: <DropdownMenuItem<String?>>[
                                                const DropdownMenuItem<String?>(
                                                  value: null,
                                                  child: Text('— Chưa chọn —'),
                                                ),
                                                ...courses.map(
                                                  (
                                                    c,
                                                  ) => DropdownMenuItem<String?>(
                                                    value: c.id,
                                                    child: Text(
                                                      '${c.courseCode} — ${c.courseName}',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  r.courseId = val;
                                                  r.createCourse = false;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            selected: r.createCourse,
                                            label: const Text('Tạo course mới'),
                                            onSelected: (v) async {
                                              if (v) {
                                                await _createCourseDialog(r);
                                              } else {
                                                setState(
                                                  () => r.createCourse = false,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      // Resolver: LECTURER
                                      Row(
                                        children: [
                                          const Text('Giảng viên: '),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: DropdownButtonFormField<String?>(
                                              initialValue: r.lecturerId,
                                              isExpanded: true,
                                              items: <DropdownMenuItem<String?>>[
                                                const DropdownMenuItem<String?>(
                                                  value: null,
                                                  child: Text('— Chưa chọn —'),
                                                ),
                                                ...lecturers.map(
                                                  (
                                                    u,
                                                  ) => DropdownMenuItem<String?>(
                                                    value: u.uid,
                                                    child: Text(
                                                      '${u.displayName} — ${u.email}',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  r.lecturerId = val;
                                                  r.createLecturer = false;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          FilterChip(
                                            selected: r.createLecturer,
                                            label: const Text(
                                              'Tạo giảng viên mới',
                                            ),
                                            onSelected: (v) async {
                                              if (v) {
                                                await _createLecturerDialog(r);
                                              } else {
                                                setState(
                                                  () =>
                                                      r.createLecturer = false,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      if (r.error != null)
                                        Text(
                                          r.error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
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
        ),
      ),
    );
  }
}
