// lib/features/admin/presentation/pages/class_enrollments_bulk_import_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../../../common/data/models/class_model.dart';
import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../../common/utils/template_downloader.dart';
import '../../../data/services/admin_service.dart';

/// Mô tả một dòng trong Excel với format:
/// className, courseCode, lecturerEmail, semester, studentEmails (phân cách bằng dấu ;)
class _ClassEnrollmentRow {
  final int rowIndex;
  String className;
  String courseCode;
  String lecturerEmail;
  String semester;
  List<String> studentEmails;

  String? classId; // sẽ được resolve sau khi tạo lớp hoặc tìm thấy lớp existing
  String? courseId;
  String? lecturerId;

  bool createClass = false;
  bool createCourse = false;
  bool createLecturer = false;
  String? error;

  _ClassEnrollmentRow({
    required this.rowIndex,
    required this.className,
    required this.courseCode,
    required this.lecturerEmail,
    required this.semester,
    required this.studentEmails,
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
  List<_ClassEnrollmentRow> _rows = [];
  String? _fileName;
  bool _submitting = false;
  String? _message;

  final _expectedHeaders = [
    'className',
    'courseCode',
    'lecturerEmail',
    'semester',
    'studentEmails',
  ];

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _message = null;
      _fileName = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }

    final bytes = result.files.first.bytes!;
    final name = result.files.first.name;

    try {
      final rows = await _parseExcel(bytes);
      setState(() {
        _rows = rows;
        _fileName = name;
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi đọc file: ${e.toString()}';
      });
    }
  }

  Future<List<_ClassEnrollmentRow>> _parseExcel(Uint8List bytes) async {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('File không hợp lệ hoặc không phải Excel (.xlsx)');
    }

    if (excel.tables.isEmpty) {
      throw Exception('File không chứa sheet nào');
    }

    // Tìm sheet có tên phù hợp hoặc lấy sheet đầu tiên
    Sheet? sheet = excel.tables.values.first;
    for (final entry in excel.tables.entries) {
      final name = entry.key.toLowerCase();
      if (name.contains('class') || name.contains('enrollment')) {
        sheet = entry.value;
        break;
      }
    }

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('Sheet trống hoặc không có dữ liệu');
    }

    // Đọc header row
    final headerRow = sheet.rows.first
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();

    // Kiểm tra các cột bắt buộc
    for (final requiredHeader in _expectedHeaders) {
      if (!headerRow.any(
        (h) => h.toLowerCase() == requiredHeader.toLowerCase(),
      )) {
        throw Exception('Thiếu cột bắt buộc: $requiredHeader');
      }
    }

    final rows = <_ClassEnrollmentRow>[];

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => cell?.value?.toString().trim().isEmpty ?? true)) {
        continue; // Skip empty rows
      }

      final rowData = <String, String>{};
      for (int j = 0; j < headerRow.length && j < row.length; j++) {
        final header = headerRow[j];
        final value = row[j]?.value?.toString().trim() ?? '';
        if (header.isNotEmpty) {
          rowData[header] = value;
        }
      }

      final className = rowData['className'] ?? '';
      final courseCode = rowData['courseCode'] ?? '';
      final lecturerEmail = rowData['lecturerEmail'] ?? '';
      final semester = rowData['semester'] ?? '';
      final studentEmailsRaw = rowData['studentEmails'] ?? '';

      if (className.isEmpty ||
          courseCode.isEmpty ||
          lecturerEmail.isEmpty ||
          semester.isEmpty) {
        continue; // Skip incomplete rows
      }

      // Parse student emails (separated by semicolon)
      final studentEmails = studentEmailsRaw
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.contains('@'))
          .toList();

      rows.add(
        _ClassEnrollmentRow(
          rowIndex: i + 1,
          className: className,
          courseCode: courseCode,
          lecturerEmail: lecturerEmail,
          semester: semester,
          studentEmails: studentEmails,
        ),
      );
    }

    return rows;
  }

  void _autoMatch(
    List<CourseModel> courses,
    List<UserModel> lecturers,
    List<ClassModel> classes,
  ) {
    for (final row in _rows) {
      // Auto-match course
      if (row.courseId == null) {
        final course = courses.firstWhere(
          (c) => c.courseCode.toUpperCase() == row.courseCode.toUpperCase(),
          orElse: () => CourseModel.empty(),
        );
        if (course.id.isNotEmpty) {
          row.courseId = course.id;
        }
      }

      // Auto-match lecturer
      if (row.lecturerId == null) {
        final lecturer = lecturers.firstWhere(
          (l) => l.email.toLowerCase() == row.lecturerEmail.toLowerCase(),
          orElse: () => UserModel(
            uid: '',
            email: '',
            displayName: '',
            role: UserRole.unknown,
          ),
        );
        if (lecturer.uid.isNotEmpty) {
          row.lecturerId = lecturer.uid;
        }
      }

      // Auto-match existing class (by className + semester + courseCode)
      if (row.classId == null) {
        final existingClass = classes.firstWhere(
          (c) =>
              c.className.toLowerCase() == row.className.toLowerCase() &&
              c.semester.toLowerCase() == row.semester.toLowerCase(),
          orElse: () => ClassModel(
            id: '',
            courseIds: [],
            lecturerId: '',
            semester: '',
            className: '',
            classCode: '',
            joinCode: '',
            createdAt: DateTime.now(),
            isArchived: false,
          ),
        );
        if (existingClass.id.isNotEmpty) {
          row.classId = existingClass.id;
        }
      }
    }
  }

  Future<void> _submit(
    List<CourseModel> courses,
    List<UserModel> lecturers,
    List<ClassModel> classes,
  ) async {
    if (_rows.isEmpty) return;

    // Validate all rows
    for (final row in _rows) {
      row.error = null;
      final needsCourse = row.courseId == null && !row.createCourse;
      final needsLecturer = row.lecturerId == null && !row.createLecturer;
      final needsClass = row.classId == null && !row.createClass;

      if (needsCourse || needsLecturer || needsClass) {
        final missing = <String>[];
        if (needsCourse) missing.add('Course');
        if (needsLecturer) missing.add('Lecturer');
        if (needsClass) missing.add('Class');
        row.error = 'Cần chọn hoặc tạo mới: ${missing.join(', ')}';
      }

      if (row.studentEmails.isEmpty) {
        row.error = (row.error?.isEmpty ?? true)
            ? 'Không có email sinh viên nào'
            : '${row.error}. Không có email sinh viên nào';
      }
    }

    setState(() {});
    if (_rows.any((r) => r.error != null)) return;

    setState(() {
      _submitting = true;
      _message = null;
    });

    final admin = context.read<AdminService>();
    int classesCreated = 0;
    int enrollmentsCreated = 0;
    int coursesCreated = 0;
    int lecturersCreated = 0;

    try {
      for (final row in _rows) {
        // Step 1: Create course if needed
        if (row.createCourse) {
          await admin.createCourse(
            courseCode: row.courseCode,
            courseName: '${row.courseCode} Course', // Default name
            credits: 3, // Default credits
          );
          coursesCreated++;

          // Re-fetch to get the new course ID
          final newCourse = await admin.getCourseIdByCode(row.courseCode);
          row.courseId = newCourse;
        }

        // Step 2: Create lecturer if needed
        if (row.createLecturer) {
          await admin.createNewUser(
            email: row.lecturerEmail,
            password: 'TempPass123!', // Temporary password
            displayName: row.lecturerEmail.split(
              '@',
            )[0], // Use email prefix as name
            role: UserRole.lecture,
          );
          lecturersCreated++;

          // Re-fetch to get the new lecturer ID
          final newLecturer = await admin.getUserIdByEmail(row.lecturerEmail);
          row.lecturerId = newLecturer;
        }

        // Step 3: Create class if needed
        if (row.createClass && row.courseId != null && row.lecturerId != null) {
          final classId = await admin.createClassRaw(
            className: row.className,
            courseId: row.courseId!,
            lecturerId: row.lecturerId!,
            semester: row.semester,
          );
          row.classId = classId;
          classesCreated++;
        }

        // Step 4: Enroll students
        if (row.classId != null) {
          for (final email in row.studentEmails) {
            final studentId = await admin.getUserIdByEmail(email);
            if (studentId != null) {
              await admin.addEnrollment(
                classId: row.classId!,
                studentUid: studentId,
              );
              enrollmentsCreated++;
            }
          }
        }
      }

      setState(() {
        _message =
            'Hoàn thành!\n'
            'Tạo mới: $coursesCreated courses, $lecturersCreated lecturers, $classesCreated classes\n'
            'Ghi danh: $enrollmentsCreated students';
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi: ${e.toString()}';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Import Lớp học + Ghi danh'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CourseModel>>(
          stream: admin.getAllCoursesStream(),
          builder: (context, courseSnapshot) {
            final courses = courseSnapshot.data ?? [];

            return StreamBuilder<List<UserModel>>(
              stream: admin.getAllLecturersStream(),
              builder: (context, lecturerSnapshot) {
                final lecturers = lecturerSnapshot.data ?? [];

                return StreamBuilder<List<ClassModel>>(
                  stream: admin.getAllClassesStream(),
                  builder: (context, classSnapshot) {
                    final classes = classSnapshot.data ?? [];

                    // Auto-match data
                    _autoMatch(courses, lecturers, classes);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Template download button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Tải template (.xlsx)'),
                          onPressed: () =>
                              TemplateDownloader.download('class_enroll'),
                        ),

                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Chọn file Excel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: (_rows.isNotEmpty && !_submitting)
                                  ? () => _submit(courses, lecturers, classes)
                                  : null,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload),
                              label: Text(
                                _submitting ? 'Đang xử lý...' : 'Thực hiện',
                              ),
                            ),
                          ],
                        ),

                        // Status messages
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

                        const SizedBox(height: 16),

                        // Data preview
                        Expanded(
                          child: _rows.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Chưa có dữ liệu.\nChọn file Excel để xem trước.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _rows.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(),
                                  itemBuilder: (context, index) {
                                    final row = _rows[index];
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${row.rowIndex}. ${row.className} (${row.semester})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Course selection
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 100,
                                                  child: Text('Môn học:'),
                                                ),
                                                Expanded(
                                                  child:
                                                      DropdownButtonFormField<
                                                        String?
                                                      >(
                                                        value: row.courseId,
                                                        items: [
                                                          const DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: null,
                                                            child: Text(
                                                              '-- Chọn môn học --',
                                                            ),
                                                          ),
                                                          ...courses.map(
                                                            (c) =>
                                                                DropdownMenuItem<
                                                                  String?
                                                                >(
                                                                  value: c.id,
                                                                  child: Text(
                                                                    '${c.courseCode} - ${c.courseName}',
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                        onChanged: (value) {
                                                          setState(() {
                                                            row.courseId =
                                                                value;
                                                            row.createCourse =
                                                                false;
                                                          });
                                                        },
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  label: const Text('Tạo mới'),
                                                  selected: row.createCourse,
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      row.createCourse =
                                                          selected;
                                                      if (selected)
                                                        row.courseId = null;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // Lecturer selection
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 100,
                                                  child: Text('Giảng viên:'),
                                                ),
                                                Expanded(
                                                  child: DropdownButtonFormField<String?>(
                                                    value: row.lecturerId,
                                                    items: [
                                                      const DropdownMenuItem<
                                                        String?
                                                      >(
                                                        value: null,
                                                        child: Text(
                                                          '-- Chọn giảng viên --',
                                                        ),
                                                      ),
                                                      ...lecturers.map(
                                                        (l) =>
                                                            DropdownMenuItem<
                                                              String?
                                                            >(
                                                              value: l.uid,
                                                              child: Text(
                                                                '${l.displayName} (${l.email})',
                                                              ),
                                                            ),
                                                      ),
                                                    ],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        row.lecturerId = value;
                                                        row.createLecturer =
                                                            false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  label: const Text('Tạo mới'),
                                                  selected: row.createLecturer,
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      row.createLecturer =
                                                          selected;
                                                      if (selected)
                                                        row.lecturerId = null;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // Class selection
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 100,
                                                  child: Text('Lớp học:'),
                                                ),
                                                Expanded(
                                                  child:
                                                      DropdownButtonFormField<
                                                        String?
                                                      >(
                                                        value: row.classId,
                                                        items: [
                                                          const DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: null,
                                                            child: Text(
                                                              '-- Chọn lớp học --',
                                                            ),
                                                          ),
                                                          ...classes.map(
                                                            (c) =>
                                                                DropdownMenuItem<
                                                                  String?
                                                                >(
                                                                  value: c.id,
                                                                  child: Text(
                                                                    '${c.className} (${c.semester})',
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                        onChanged: (value) {
                                                          setState(() {
                                                            row.classId = value;
                                                            row.createClass =
                                                                false;
                                                          });
                                                        },
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  label: const Text('Tạo mới'),
                                                  selected: row.createClass,
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      row.createClass =
                                                          selected;
                                                      if (selected)
                                                        row.classId = null;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // Student emails
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(
                                                  width: 100,
                                                  child: Text('Sinh viên:'),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${row.studentEmails.length} emails: ${row.studentEmails.take(3).join(", ")}${row.studentEmails.length > 3 ? "..." : ""}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Error display
                                            if (row.error != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                row.error!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
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
