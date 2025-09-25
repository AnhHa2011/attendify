// lib/features/admin/presentation/pages/course_bulk_import_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../../../common/data/models/course_model.dart';
import '../../../../common/utils/template_downloader.dart';
import '../../../data/services/admin_service.dart';
// NOTE: Sửa đường dẫn import dưới đây cho đúng với project bạn:
// - Nếu CourseModel nằm ở lib/common/models: dùng dòng đầu, còn nếu ở lib/data/models: dùng dòng thứ hai
// import '../../../data/models/course_model.dart';

const _expectedHeaders = ['courseCode', 'courseName', 'credits'];

class _RowState {
  final int rowIndex;
  String courseCode;
  String courseName;
  int credits;
  String? matchedCourseId; // nếu đã khớp course hiện có
  bool createNew; // nếu không khớp và muốn tạo mới
  String? error;

  _RowState({
    required this.rowIndex,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    this.createNew = false,
  });
}

class CourseBulkImportPage extends StatefulWidget {
  const CourseBulkImportPage({super.key});

  @override
  State<CourseBulkImportPage> createState() => _CourseBulkImportPageState();
}

class _CourseBulkImportPageState extends State<CourseBulkImportPage> {
  List<_RowState> _rows = [];
  String? _fileName;
  bool _submitting = false;
  String? _message;

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
      final rows = await _parseCoursesXlsx(bytes);
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

  Future<List<_RowState>> _parseCoursesXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }
    // Ưu tiên sheet tên Courses/Course, nếu không có dùng sheet đầu
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'courses' || lk == 'course') {
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

    final out = <_RowState>[];
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

      final code = (map['courseCode'] ?? '').toString().trim();
      final name = (map['courseName'] ?? '').toString().trim();
      final creditsStr = (map['credits'] ?? '').toString().trim();
      final credits = int.tryParse(creditsStr);

      if (code.isEmpty || name.isEmpty || credits == null) continue;

      out.add(
        _RowState(
          rowIndex: i,
          courseCode: code,
          courseName: name,
          credits: credits,
        ),
      );
    }
    return out;
  }

  Future<void> _submit(List<CourseModel> allCourses) async {
    if (_rows.isEmpty) return;

    // Kiểm tra: mỗi dòng phải chọn khớp hoặc bật Tạo mới
    for (final r in _rows) {
      r.error = null;
      final ok = (r.matchedCourseId != null) || r.createNew;
      if (!ok) r.error = 'Chưa chọn course hoặc đánh dấu "Tạo mới".';
    }
    setState(() {});
    if (_rows.any((e) => e.error != null)) return;

    setState(() {
      _submitting = true;
      _message = null;
    });
    final admin = context.read<AdminService>();

    try {
      int created = 0, updated = 0;

      for (final r in _rows) {
        if (r.createNew) {
          await admin.createCourse(
            courseCode: r.courseCode,
            courseName: r.courseName,
            credits: r.credits,
          );
          created++;
        } else if (r.matchedCourseId != null) {
          await admin.updateCourse(
            courseId: r.matchedCourseId!,
            courseCode: r.courseCode,
            courseName: r.courseName,
            credits: r.credits,
          );
          updated++;
        }
      }
      setState(() {
        _message = 'Tạo mới: $created • Cập nhật: $updated';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập môn học từ Excel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CourseModel>>(
          stream: context.read<AdminService>().getAllCoursesStream(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];

            // Auto-match theo courseCode
            for (final r in _rows) {
              if (r.matchedCourseId == null) {
                final idx = all.indexWhere(
                  (c) =>
                      c.courseCode.toUpperCase().trim() ==
                      r.courseCode.toUpperCase().trim(),
                );
                if (idx >= 0) r.matchedCourseId = all[idx].id;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Tải template môn học (.xlsx)'),
                  onPressed: () => TemplateDownloader.download('class_enroll'),
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
                      onPressed: (_rows.isNotEmpty && !_submitting)
                          ? () => _submit(all)
                          : null,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: _submitting
                          ? const Text('Đang nhập...')
                          : const Text('Thực hiện'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                      ? const Center(child: Text('Chưa có dữ liệu xem trước'))
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _rows[i];
                            return ListTile(
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(
                                '${r.rowIndex}. ${r.courseCode} — ${r.courseName}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Khớp với: '),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: DropdownButtonFormField<String?>(
                                          initialValue: r.matchedCourseId,
                                          isExpanded: true,
                                          items: <DropdownMenuItem<String?>>[
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('— Chưa chọn —'),
                                            ),
                                            ...all.map(
                                              (c) => DropdownMenuItem<String?>(
                                                value: c.id,
                                                child: Text(
                                                  '${c.courseCode} — ${c.courseName}',
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              r.matchedCourseId = val;
                                              r.createNew = false;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilterChip(
                                        selected: r.createNew,
                                        label: const Text('Tạo mới'),
                                        onSelected: (v) {
                                          setState(() {
                                            r.createNew = v;
                                            if (v) r.matchedCourseId = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Text('credits: ${r.credits}'),
                                  if (r.error != null)
                                    Text(
                                      r.error!,
                                      style: const TextStyle(color: Colors.red),
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
        ),
      ),
    );
  }
}
