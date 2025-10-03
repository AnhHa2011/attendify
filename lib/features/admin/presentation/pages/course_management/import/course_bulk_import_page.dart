// lib/features/admin/presentation/pages/course_bulk_import_page.dart
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/data/models/course_model.dart';
import '../../../../../../core/data/models/user_model.dart';
import '../../../../../../core/utils/template_downloader.dart';
import '../../../../data/services/admin_service.dart';

/// Header mong đợi trong file Excel (không phân biệt hoa/thường)
const _expectedHeaders = <String>[
  'courseCode',
  'courseName',
  'lecturerEmail',
  'semester',
  'credits',
  'minStudents',
  'maxStudents',
  'maxAbsences',
  'startDate', // yyyy-MM-dd | dd/MM/yyyy | Excel serial
  'endDate', // yyyy-MM-dd | dd/MM/yyyy | Excel serial
  'description',
];

class _CourseRowState {
  final int rowIndex;

  // dữ liệu thô / đã chỉnh
  String courseCode;
  String courseName;
  String lecturerEmail;
  String semester;
  int credits;
  int minStudents;
  int maxStudents;
  int maxAbsences;
  DateTime? startDate;
  DateTime? endDate;
  String? description;

  // match
  String? lecturerId; // uid giảng viên đã chọn
  String? error; // thông báo lỗi cho dòng

  _CourseRowState({
    required this.rowIndex,
    required this.courseCode,
    required this.courseName,
    required this.lecturerEmail,
    required this.semester,
    required this.credits,
    required this.minStudents,
    required this.maxStudents,
    required this.maxAbsences,
    required this.startDate,
    required this.endDate,
    required this.description,
    this.lecturerId,
    this.error,
  });
}

/// Date Picker Field (không đổi UI)
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateTime? firstSelectableDate; // THÊM DÒNG NÀY
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstSelectableDate, // THÊM DÒNG NÀY
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? firstSelectableDate ?? DateTime.now(),
              // SỬA DÒNG NÀY: Ưu tiên ngày có thể chọn, fallback về ngày mặc định
              firstDate: firstSelectableDate ?? DateTime(2020),
              lastDate: DateTime(2035),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(colorScheme: colorScheme),
                  child: child!,
                );
              },
            );
            if (date != null) onChanged(date); // xoá lỗi ở nơi gọi
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? _formatDate(value!) : 'Chọn ngày...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: value != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class CourseBulkImportPage extends StatefulWidget {
  const CourseBulkImportPage({super.key});

  @override
  State<CourseBulkImportPage> createState() => _CourseBulkImportPageState();
}

class _CourseBulkImportPageState extends State<CourseBulkImportPage> {
  List<_CourseRowState> _rows = [];
  String? _fileName;
  String? _message;
  bool _submitting = false;

  // ---------- Helpers (Excel) ----------
  static String _cellStr(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    final v = row[col]?.value;
    return v == null ? '' : v.toString();
  }

  /// Parse DateTime từ Excel cell: hỗ trợ DateTime, số serial, chuỗi dd/MM/yyyy, yyyy-MM-dd, dd-MM-yyyy
  static DateTime? _dateFromCell(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return null;
    final v = row[col]?.value; // lấy giá trị thực

    if (v == null) return null;

    // Nếu đã là DateTime
    if (v is DateTime) return DateTime.tryParse(v.toString());

    // Nếu là số serial Excel (double/int)
    if (v is int) {
      final excelEpoch = DateTime(1899, 12, 30);
      return excelEpoch.add(Duration(days: v as int));
    }

    // Nếu là chuỗi
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    if (s.contains('-')) {
      final p = s.split('-');
      if (p.length == 3) {
        if (p[0].length == 4) {
          final y = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final d = int.tryParse(p[2]);
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        } else {
          final d = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final y = int.tryParse(p[2]);
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      }
    }

    if (s.contains('/')) {
      final p = s.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }

    return DateTime.tryParse(s);
  }

  // ---------- File picker & parser ----------
  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _fileName = null;
      _message = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null) {
      return;
    }

    try {
      final rows = await _parseCoursesXlsx(res.files.single.bytes!);
      setState(() {
        _rows = rows;
        _fileName = res.files.single.name;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_CourseRowState>> _parseCoursesXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }

    // Ưu tiên sheet "courses" / "course"
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'courses' || lk == 'course') {
        tb = excel.tables[key];
        break;
      }
    }
    if (tb == null || tb.rows.isEmpty) throw Exception('Sheet rỗng.');

    // Header
    final rawHeader = tb.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    if (rawHeader.isEmpty) throw Exception('Không tìm thấy header.');
    final headerLower = rawHeader.map((e) => e.toLowerCase()).toList();

    for (final h in _expectedHeaders) {
      if (!headerLower.contains(h.toLowerCase())) {
        throw Exception('Thiếu cột bắt buộc: $h');
      }
    }

    int idxOf(String key) => headerLower.indexOf(key.toLowerCase());

    final out = <_CourseRowState>[];
    final seenCourseCodes = <String>{}; // Check trùng trong file

    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      if (row.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue;
      }

      final courseCode = _cellStr(
        row,
        idxOf('courseCode'),
      ).trim().toUpperCase();
      final courseName = _cellStr(row, idxOf('courseName')).trim();
      final lecturerEmail = _cellStr(row, idxOf('lecturerEmail')).trim();
      final semester = _cellStr(row, idxOf('semester')).trim();
      final credits = int.tryParse(_cellStr(row, idxOf('credits')).trim()) ?? 0;
      final minStudents =
          int.tryParse(_cellStr(row, idxOf('minStudents')).trim()) ?? 0;
      final maxStudents =
          int.tryParse(_cellStr(row, idxOf('maxStudents')).trim()) ?? 0;
      final maxAbsences =
          int.tryParse(_cellStr(row, idxOf('maxAbsences')).trim()) ?? 0;
      final startDate = _dateFromCell(row, idxOf('startDate'));
      final endDate = _dateFromCell(row, idxOf('endDate'));
      final description = _cellStr(row, idxOf('description')).trim();

      if (courseCode.isEmpty ||
          courseName.isEmpty ||
          lecturerEmail.isEmpty ||
          semester.isEmpty) {
        // Thiếu dữ liệu cơ bản → bỏ qua dòng
        continue;
      }

      // Trùng mã ngay trong file
      if (seenCourseCodes.contains(courseCode)) {
        throw Exception(
          'Mã môn học "$courseCode" bị trùng lặp trong file (dòng ${i + 1})',
        );
      }
      seenCourseCodes.add(courseCode);

      out.add(
        _CourseRowState(
          rowIndex: i,
          courseCode: courseCode,
          courseName: courseName,
          lecturerEmail: lecturerEmail,
          semester: semester,
          credits: credits,
          minStudents: minStudents,
          maxStudents: maxStudents,
          maxAbsences: maxAbsences,
          startDate: startDate,
          endDate: endDate,
          description: description.isEmpty ? null : description,
        ),
      );
    }
    return out;
  }

  // ---------- Validate ----------
  String? _validateRow(
    _CourseRowState r,
    List<CourseModel> existingCourses,
    List<UserModel> lecturers,
  ) {
    if (r.courseCode.trim().isEmpty) return 'Thiếu mã môn học';
    if (r.courseName.trim().isEmpty) return 'Thiếu tên môn học';
    if (r.semester.trim().isEmpty) return 'Thiếu học kỳ';
    if (r.credits <= 0) return 'Số tín chỉ phải > 0';
    if (r.minStudents < 0) return 'Số sinh viên tối thiểu không hợp lệ';
    if (r.maxStudents <= 0) return 'Số sinh viên tối đa phải > 0';
    if (r.maxStudents < r.minStudents) {
      return 'Số sinh viên tối đa phải ≥ tối thiểu';
    }
    if (r.maxAbsences < 0) return 'Số buổi vắng tối đa không hợp lệ';
    if (r.startDate == null) return 'Thiếu ngày bắt đầu';
    if (r.endDate == null) return 'Thiếu ngày kết thúc';

    if (!r.endDate!.isAfter(r.startDate!)) {
      return 'Ngày kết thúc phải sau ngày bắt đầu';
    }

    // Trùng với DB
    final existed = existingCourses.firstWhere(
      (c) =>
          c.courseCode.toUpperCase().trim() ==
          r.courseCode.toUpperCase().trim(),
      orElse: () => CourseModel.empty(),
    );
    if (existed.id.isNotEmpty) {
      return 'Mã môn học "${r.courseCode}" đã tồn tại trong hệ thống';
    }

    // Bắt buộc chọn giảng viên (dropdown)
    if (r.lecturerId == null || r.lecturerId!.isEmpty) {
      return 'Chưa chọn giảng viên';
    }

    return null;
  }

  bool _allValid(
    List<CourseModel> existingCourses,
    List<UserModel> lecturers,
  ) =>
      _rows.isNotEmpty &&
      _rows.every((e) => _validateRow(e, existingCourses, lecturers) == null);

  // ---------- Submit ----------
  Future<void> _submit(
    List<CourseModel> allCourses,
    List<UserModel> lecturers,
  ) async {
    if (_rows.isEmpty) return;

    bool hasError = false;
    for (final r in _rows) {
      r.error = _validateRow(r, allCourses, lecturers);
      if (r.error != null) hasError = true;
    }
    setState(() {});
    if (hasError) {
      setState(
        () => _message = 'Có lỗi trong dữ liệu. Vui lòng kiểm tra và sửa lại.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    final admin = context.read<AdminService>();

    try {
      int created = 0;
      for (final r in _rows) {
        await admin.createCourse(
          courseCode: r.courseCode.trim().toUpperCase(),
          courseName: r.courseName.trim(),
          lecturerId: r.lecturerId!,
          semester: r.semester.trim(),
          joinCode: '',
          credits: r.credits,
          description: r.description ?? '',
          totalStudents: 0,
          minStudents: r.minStudents,
          maxStudents: r.maxStudents,
          startDate: r.startDate!,
          endDate: r.endDate!,
        );
        created++;
      }

      setState(() {
        _message = 'Thành công! Đã tạo mới $created môn học.';
        _rows = [];
        _fileName = null;
      });
    } catch (e) {
      setState(
        () => _message = 'Lỗi: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Nhập môn học từ Excel'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: StreamBuilder<List<CourseModel>>(
          stream: context.read<AdminService>().getAllCoursesStream(),
          builder: (_, courseSnap) {
            final courses = courseSnap.data ?? [];

            return StreamBuilder<List<UserModel>>(
              stream: context.read<AdminService>().getAllLecturersStream(),
              builder: (_, lecSnap) {
                final lecturers = lecSnap.data ?? [];

                // auto-match lecturer theo email
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
                  children: [
                    // Header Section with Actions
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tải lên file Excel để nhập hàng loạt',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lưu ý: Mã môn học không được trùng lặp trong file và không được trùng với môn học đã có trong hệ thống. Ngày bắt đầu và kết thúc là bắt buộc. Phải chọn giảng viên từ danh sách có sẵn.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _ActionButton(
                                icon: Icons.download_outlined,
                                label: 'Tải template',
                                onPressed: () =>
                                    TemplateDownloader.download('course'),
                                variant: _ButtonVariant.outlined,
                              ),
                              _ActionButton(
                                icon: Icons.upload_file_outlined,
                                label: 'Chọn file Excel',
                                onPressed: _pickFile,
                                variant: _ButtonVariant.filled,
                              ),
                              _ActionButton(
                                icon: _submitting
                                    ? Icons.hourglass_empty
                                    : Icons.cloud_upload_outlined,
                                label: _submitting
                                    ? 'Đang xử lý...'
                                    : 'Thực hiện nhập',
                                onPressed:
                                    (_allValid(courses, lecturers) &&
                                        !_submitting)
                                    ? () => _submit(courses, lecturers)
                                    : null,
                                variant: _ButtonVariant.primary,
                              ),
                            ],
                          ),
                          if (_fileName != null || _message != null) ...[
                            const SizedBox(height: 16),
                            _StatusCard(
                              fileName: _fileName,
                              message: _message,
                              colorScheme: colorScheme,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Content Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                        child: _rows.isEmpty
                            ? _EmptyState(colorScheme: colorScheme)
                            : _DataList(
                                rows: _rows,
                                allCourses: courses,
                                lecturers: lecturers,
                                isWideScreen: isWideScreen,
                                onChanged: () => setState(() {}),
                              ),
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

// Action Button Component
enum _ButtonVariant { outlined, filled, primary }

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _ButtonVariant variant;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (variant) {
      case _ButtonVariant.outlined:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      case _ButtonVariant.filled:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      case _ButtonVariant.primary:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
    }
  }
}

// Status Card Component
class _StatusCard extends StatelessWidget {
  final String? fileName;
  final String? message;
  final ColorScheme colorScheme;

  const _StatusCard({
    required this.fileName,
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null)
            Row(
              children: [
                Icon(Icons.description, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File: $fileName',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          if (message != null) ...[
            if (fileName != null) const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  message!.startsWith('Lỗi') || message!.contains('Có lỗi')
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 16,
                  color:
                      message!.startsWith('Lỗi') || message!.contains('Có lỗi')
                      ? colorScheme.error
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      color:
                          message!.startsWith('Lỗi') ||
                              message!.contains('Có lỗi')
                          ? colorScheme.error
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Empty State Component
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_view_outlined, size: 80, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Chọn file Excel để xem trước dữ liệu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tải template để biết định dạng yêu cầu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Data List Component
class _DataList extends StatelessWidget {
  final List<_CourseRowState> rows;
  final List<CourseModel> allCourses;
  final List<UserModel> lecturers;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _DataList({
    required this.rows,
    required this.allCourses,
    required this.lecturers,
    required this.isWideScreen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Xem trước dữ liệu (${rows.length} môn học)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              return _CourseRowCard(
                row: rows[index],
                allCourses: allCourses,
                lecturers: lecturers,
                isWideScreen: isWideScreen,
                onChanged: () {
                  // Clear error + re-validate tức thì
                  rows[index].error = null;
                  final parent = context
                      .findAncestorStateOfType<_CourseBulkImportPageState>();
                  if (parent != null) {
                    rows[index].error = parent._validateRow(
                      rows[index],
                      allCourses,
                      lecturers,
                    );
                  }
                  onChanged();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Course Row Card
class _CourseRowCard extends StatelessWidget {
  final _CourseRowState row;
  final List<CourseModel> allCourses;
  final List<UserModel> lecturers;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _CourseRowCard({
    required this.row,
    required this.allCourses,
    required this.lecturers,
    required this.isWideScreen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Tìm giảng viên (để hiển thị header)
    final lecturer = (row.lecturerId != null && row.lecturerId!.isNotEmpty)
        ? lecturers.firstWhere(
            (u) => u.uid == row.lecturerId,
            orElse: () => UserModel.empty(),
          )
        : lecturers.firstWhere(
            (u) =>
                u.email.toLowerCase().trim() ==
                row.lecturerEmail.toLowerCase().trim(),
            orElse: () => UserModel.empty(),
          );

    // Validate để hiện lỗi
    final error = context
        .findAncestorStateOfType<_CourseBulkImportPageState>()
        ?._validateRow(row, allCourses, lecturers);
    final hasError = error != null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? colorScheme.error.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
          width: hasError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: hasError
                  ? colorScheme.error.withOpacity(0.05)
                  : colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasError ? colorScheme.error : colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasError ? Icons.error_outline : Icons.book_outlined,
                    color: hasError
                        ? colorScheme.onError
                        : colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.courseCode} — ${row.courseName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (row.startDate != null && row.endDate != null)
                        Text(
                          'Ngày: ${_fmtDate(row.startDate!)} - ${_fmtDate(row.endDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (lecturer.uid.isNotEmpty)
                        Text(
                          'GV: ${lecturer.displayName} (${lecturer.email})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      if (hasError)
                        Text(
                          error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasError
                        ? colorScheme.error.withOpacity(0.1)
                        : colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasError
                          ? colorScheme.error.withOpacity(0.3)
                          : colorScheme.tertiary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    hasError ? 'Lỗi' : 'Tạo mới',
                    style: TextStyle(
                      color: hasError
                          ? colorScheme.error
                          : colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildFormGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 3
            : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 4,
          childAspectRatio: crossAxisCount == 4 ? 5 : 6,
          children: [
            _FormField(
              label: 'Mã môn học',
              value: row.courseCode,
              icon: Icons.tag,
              onChanged: (v) {
                row.courseCode = v.trim().toUpperCase();
                row.error = null;
                onChanged();
              },
            ),
            _FormField(
              label: 'Tên môn học',
              value: row.courseName,
              icon: Icons.book_outlined,
              onChanged: (v) {
                row.courseName = v.trim();
                row.error = null;
                onChanged();
              },
            ),
            // Dropdown chọn giảng viên (clear lỗi ngay khi chọn)
            _LecturerDropdownField(
              label: 'Chọn giảng viên',
              value: row.lecturerId,
              lecturers: lecturers,
              suggestedEmail: row.lecturerEmail,
              onChanged: (lecturerId) {
                row.lecturerId = lecturerId;
                // clear lỗi và re-validate
                final parent = context
                    .findAncestorStateOfType<_CourseBulkImportPageState>();
                if (parent != null) {
                  row.error = parent._validateRow(row, allCourses, lecturers);
                } else {
                  row.error = null;
                }
                onChanged();
              },
            ),

            _FormField(
              label: 'Học kỳ',
              value: row.semester,
              icon: Icons.school_outlined,
              onChanged: (v) {
                row.semester = v.trim();
                row.error = null;
                onChanged();
              },
            ),
            _FormField(
              label: 'Số tín chỉ',
              value: '${row.credits}',
              icon: Icons.grade_outlined,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.credits = int.tryParse(v) ?? 0;
                row.error = null;
                onChanged();
              },
            ),
            _FormField(
              label: 'Min sinh viên',
              value: '${row.minStudents}',
              icon: Icons.people_outline,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.minStudents = int.tryParse(v) ?? 0;
                row.error = null;
                onChanged();
              },
            ),
            _FormField(
              label: 'Max sinh viên',
              value: '${row.maxStudents}',
              icon: Icons.people,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.maxStudents = int.tryParse(v) ?? 0;
                row.error = null;
                onChanged();
              },
            ),
            _FormField(
              label: 'Max vắng mặt',
              value: '${row.maxAbsences}',
              icon: Icons.event_busy,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.maxAbsences = int.tryParse(v) ?? 0;
                row.error = null;
                onChanged();
              },
            ),
            // Date pickers — clear lỗi khi chọn
            _DatePickerField(
              label: 'Ngày bắt đầu (bắt buộc)',
              value: row.startDate,
              onChanged: (date) {
                row.startDate = date;
                // Cải tiến UX: Nếu ngày kết thúc không còn hợp lệ, xóa nó đi
                if (row.endDate != null && date != null) {
                  if (!row.endDate!.isAfter(date)) {
                    row.endDate = null;
                  }
                }
                onChanged(); // Gọi onChanged để cập nhật UI và validate lại
              },
            ),
            _DatePickerField(
              label: 'Ngày kết thúc (bắt buộc)',
              value: row.endDate,
              // Cải tiến UX: Chặn chọn ngày không hợp lệ
              firstSelectableDate: row.startDate?.add(const Duration(days: 1)),
              onChanged: (date) {
                row.endDate = date;
                onChanged(); // Gọi onChanged để cập nhật UI và validate lại
              },
            ),
            // Description spans full width
            Container(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: _FormField(
                label: 'Mô tả',
                value: row.description ?? '',
                icon: Icons.description_outlined,
                maxLines: 2,
                onChanged: (v) {
                  row.description = v.trim().isEmpty ? null : v.trim();
                  row.error = null;
                  onChanged();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// Form Field Component
class _FormField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final ValueChanged<String> onChanged;

  const _FormField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// Lecturer Dropdown Field Component
class _LecturerDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<UserModel> lecturers;
  final String suggestedEmail;
  final ValueChanged<String?> onChanged;

  const _LecturerDropdownField({
    required this.label,
    required this.value,
    required this.lecturers,
    required this.suggestedEmail,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: (value != null && value!.isEmpty) ? null : value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          hint: Text(
            suggestedEmail.isNotEmpty
                ? 'Gợi ý: $suggestedEmail'
                : 'Chọn giảng viên...',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— Chọn giảng viên —'),
            ),
            ...lecturers.map(
              (lecturer) => DropdownMenuItem<String?>(
                value: lecturer.uid,
                child: Text(
                  '${lecturer.displayName} (${lecturer.email})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        lecturer.email.toLowerCase() ==
                            suggestedEmail.toLowerCase()
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color:
                        lecturer.email.toLowerCase() ==
                            suggestedEmail.toLowerCase()
                        ? colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged, // lỗi sẽ được xoá ở nơi gọi
        ),
      ],
    );
  }
}
