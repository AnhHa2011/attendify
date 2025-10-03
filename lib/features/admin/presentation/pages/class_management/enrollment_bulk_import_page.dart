import 'package:attendify/app_imports.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';

import '../../../../../core/data/models/class_enrollment_model.dart';
import '../../../../../core/utils/template_downloader.dart';

/// Import theo 1 lớp cố định (widget.classModel.classCode) → chỉ cần cột studentEmail
const _expectedHeaders = <String>['studentEmail'];

class _EnrollmentRowState {
  final int rowIndex;
  String studentEmail;

  String? studentId; // uid sinh viên
  String? error; // lỗi hiển thị

  _EnrollmentRowState({required this.rowIndex, required this.studentEmail});
}

class ClassEnrollmentBulkImportPage extends StatefulWidget {
  final ClassModel classModel;
  const ClassEnrollmentBulkImportPage({super.key, required this.classModel});

  @override
  State<ClassEnrollmentBulkImportPage> createState() =>
      _EnrollmentBulkImportPageState();
}

class _EnrollmentBulkImportPageState
    extends State<ClassEnrollmentBulkImportPage> {
  List<_EnrollmentRowState> _rows = [];
  String? _fileName;
  String? _message;
  bool _submitting = false;

  @override
  void dispose() {
    super.dispose();
  }

  // ---------- Helpers (Excel) ----------
  static String _cellStr(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    final v = row[col]?.value;
    return v == null ? '' : v.toString();
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
      final rows = await _parseEnrollmentsXlsx(res.files.single.bytes!);
      setState(() {
        _rows = rows;
        _fileName = res.files.single.name;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_EnrollmentRowState>> _parseEnrollmentsXlsx(
    Uint8List bytes,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }

    // ưu tiên sheet "enrollments" / "enrollment"
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'enrollments' || lk == 'enrollment') {
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

    final out = <_EnrollmentRowState>[];
    final seenPairs = <String>{}; // studentEmail|classCode trùng trong file

    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      if (row.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue;
      }

      final studentEmail = _cellStr(row, idxOf('studentEmail')).trim();

      if (studentEmail.isEmpty || widget.classModel.id.isEmpty) {
        continue; // thiếu dữ liệu cơ bản → bỏ qua dòng
      }

      final key = '${studentEmail.toLowerCase()}|${widget.classModel.id}';
      if (seenPairs.contains(key)) {
        throw Exception('(studentEmail) bị trùng trong file ở dòng ${i + 1}');
      }
      seenPairs.add(key);

      out.add(_EnrollmentRowState(rowIndex: i, studentEmail: studentEmail));
    }
    return out;
  }

  // ---------- Validate ----------
  String? _validateRow(
    _EnrollmentRowState r,
    List<UserModel> students,
    List<ClassEnrollmentModel> enrollments,
  ) {
    if (r.studentEmail.trim().isEmpty) return 'Thiếu email sinh viên';

    if (r.studentId == null || r.studentId!.isEmpty) {
      return 'Chưa chọn sinh viên';
    }

    // trùng với DB (đã ghi danh)
    final isDup = enrollments.any(
      (e) =>
          e.classCode.toUpperCase().trim() ==
              widget.classModel.id.toUpperCase().trim() &&
          e.studentId == r.studentId,
    );
    if (isDup) {
      return 'SV đã ghi danh lớp "${widget.classModel.className}"';
    }

    return null;
  }

  bool _allValid(
    List<UserModel> students,
    List<ClassEnrollmentModel> enrollments,
  ) =>
      _rows.isNotEmpty &&
      _rows.every((e) => _validateRow(e, students, enrollments) == null);
  int _remainingSeats(List<ClassEnrollmentModel> enrollments) {
    final max = widget.classModel.maxStudents;
    final current = enrollments.length;
    final remain = max - current;
    return remain < 0 ? 0 : remain;
  }

  int _countImportable(
    List<UserModel> students,
    List<ClassEnrollmentModel> enrollments,
  ) {
    int count = 0;
    for (final r in _rows) {
      final err = _validateRow(r, students, enrollments);
      if (err == null) count++;
    }
    return count;
  }

  // ---------- Submit ----------
  Future<void> _submit(
    List<UserModel> students,
    List<ClassEnrollmentModel> enrollments,
  ) async {
    if (_rows.isEmpty) return;

    bool hasError = false;
    for (final r in _rows) {
      r.error = _validateRow(r, students, enrollments);
      if (r.error != null) hasError = true;
    }
    setState(() {});
    if (hasError) {
      setState(() => _message = 'Có lỗi trong dữ liệu. Vui lòng kiểm tra.');
      return;
    }
    // ====== NEW: Kiểm tra sức chứa lớp trước khi import ======
    final remaining = _remainingSeats(enrollments);
    final importable = _countImportable(students, enrollments);
    final inFile = _rows.length;

    if (importable > remaining) {
      setState(() {
        _message =
            'Vượt sức chứa lớp.\n'
            'Số chỗ còn lại: $remaining.\n'
            'Số sinh viên có trong file: $inFile.\n'
            'Số sinh viên hợp lệ có thể import: $remaining.\n'
            'Vui lòng bớt số lượng hoặc chia file.';
      });
      return;
    }
    // ==========================================================

    setState(() {
      _submitting = true;
      _message = null;
    });

    final admin = context.read<AdminService>();

    try {
      int created = 0;
      for (final r in _rows) {
        await admin.enrollClassSingleStudent(
          widget.classModel.id,
          r.studentId!,
        );
        created++;
      }

      setState(() {
        _message = 'Thành công! Đã ghi danh $created lượt.';
        _rows = [];
        _fileName = null;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi: $e');
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
        title: Text('Nhập ghi danh từ Excel — ${widget.classModel.className}'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: StreamBuilder<List<UserModel>>(
          stream: context.read<AdminService>().getAllStudentsStream(),
          builder: (_, stuSnap) {
            if (stuSnap.hasError) {
              // lỗi students: vẫn cho cuộn để xem hết thông báo
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StatusCard(
                    fileName: _fileName,
                    message: 'Lỗi tải danh sách sinh viên: ${stuSnap.error}',
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              );
            }
            final students = stuSnap.data ?? [];

            return StreamBuilder<List<ClassEnrollmentModel>>(
              stream: context.read<AdminService>().getAllClassEnrollmentsStream(
                classCode: widget.classModel.id,
              ),
              builder: (_, enrSnap) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final isWideScreen = MediaQuery.of(context).size.width > 800;

                // ===== lỗi enrollments: header + status, tất cả trong 1 scroll =====
                if (enrSnap.hasError) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeader(
                          theme,
                          colorScheme,
                          isWideScreen,
                          enableSubmit: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _StatusCard(
                            fileName: _fileName,
                            message:
                                'Lỗi tải enrollments (${widget.classModel.classCode}): ${enrSnap.error}',
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final enrollments = enrSnap.data ?? [];

                // auto-match student theo email
                for (final r in _rows) {
                  if (r.studentId == null) {
                    final i = students.indexWhere(
                      (u) =>
                          u.email.toLowerCase().trim() ==
                          r.studentEmail.toLowerCase().trim(),
                    );
                    if (i >= 0) r.studentId = students[i].uid;
                  }
                }

                final remaining = _remainingSeats(enrollments);
                final importable = _countImportable(students, enrollments);
                final inFile = _rows.length;

                final canSubmit =
                    _rows.isNotEmpty &&
                    !_submitting &&
                    importable > 0 &&
                    importable <= remaining;

                // ===== TRANG CUỘN: header + content (không dùng Expanded) =====
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(
                        theme,
                        colorScheme,
                        isWideScreen,
                        enableSubmit: canSubmit,
                        onSubmit: () => _submit(students, enrollments),
                        remaining: remaining,
                        importable: importable,
                        inFile: inFile,
                      ),
                      Padding(
                        padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                        child: _rows.isEmpty
                            ? _EmptyState(colorScheme: colorScheme)
                            : _DataList(
                                rows: _rows,
                                allStudents: students,
                                allEnrollments: enrollments,
                                isWideScreen: isWideScreen,
                                onChanged: () => setState(() {}),
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isWideScreen, {
    bool enableSubmit = false,
    VoidCallback? onSubmit,
    int remaining = 0,
    int importable = 0,
    int inFile = 0,
  }) {
    return Container(
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
            'Tải lên file Excel để ghi danh hàng loạt cho lớp ${widget.classModel.className}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yêu cầu cột: `studentEmail`. Lớp cố định: ${widget.classModel.className}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Chỗ còn lại: $remaining • Trong file: $inFile',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: remaining >= inFile
                      ? colorScheme.onSurface.withOpacity(0.7)
                      : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                icon: Icons.download_outlined,
                label: 'Tải template',
                onPressed: () => TemplateDownloader.download('enrollment'),
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
                label: _submitting ? 'Đang xử lý...' : 'Thực hiện nhập',
                onPressed: enableSubmit ? onSubmit : null,
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
    );
  }

  Widget _buildFatalError(String msg) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _StatusCard(
        fileName: _fileName,
        message: msg,
        colorScheme: colorScheme,
      ),
    );
  }
}

// ====== Reuse components ======

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

// ====== Data list & row card ======

class _DataList extends StatelessWidget {
  final List<_EnrollmentRowState> rows;
  final List<UserModel> allStudents;
  final List<ClassEnrollmentModel> allEnrollments;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _DataList({
    required this.rows,
    required this.allStudents,
    required this.allEnrollments,
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
              'Xem trước dữ liệu (${rows.length} ghi danh)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // List không cuộn, để trang mẹ cuộn
        ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            return _EnrollmentRowCard(
              row: rows[index],
              allStudents: allStudents,
              allEnrollments: allEnrollments,
              isWideScreen: isWideScreen,
              onChanged: () {
                rows[index].error = null;
                final parent = context
                    .findAncestorStateOfType<_EnrollmentBulkImportPageState>();
                if (parent != null) {
                  rows[index].error = parent._validateRow(
                    rows[index],
                    allStudents,
                    allEnrollments,
                  );
                }
                onChanged();
              },
            );
          },
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }
}

class _EnrollmentRowCard extends StatelessWidget {
  final _EnrollmentRowState row;
  final List<UserModel> allStudents;
  final List<ClassEnrollmentModel> allEnrollments;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _EnrollmentRowCard({
    required this.row,
    required this.allStudents,
    required this.allEnrollments,
    required this.isWideScreen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final student = (row.studentId != null && row.studentId!.isNotEmpty)
        ? allStudents.firstWhere(
            (u) => u.uid == row.studentId,
            orElse: () => UserModel.empty(),
          )
        : allStudents.firstWhere(
            (u) =>
                u.email.toLowerCase().trim() ==
                row.studentEmail.toLowerCase().trim(),
            orElse: () => UserModel.empty(),
          );

    final error = context
        .findAncestorStateOfType<_EnrollmentBulkImportPageState>()
        ?._validateRow(row, allStudents, allEnrollments);
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
                    hasError ? Icons.error_outline : Icons.person_add_alt_1,
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
                        row.studentEmail,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (student.uid.isNotEmpty)
                        Text(
                          'SV: ${student.displayName} (${student.email})',
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
                    hasError ? 'Lỗi' : 'Ghi danh',
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
        final w = constraints.maxWidth;
        // 4 / 3 / 2 / 1 cột tùy độ rộng, mobile rất hẹp xuống 1 cột
        final crossAxisCount = w >= 1100
            ? 4
            : w >= 900
            ? 3
            : w >= 600
            ? 2
            : 1;
        final ratio = crossAxisCount >= 3
            ? 5.0
            : (crossAxisCount == 2 ? 5.6 : 3.0);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 4,
          childAspectRatio: ratio,
          children: [
            _FormField(
              label: 'Email sinh viên',
              value: row.studentEmail,
              icon: Icons.alternate_email,
              onChanged: (v) {
                row.studentEmail = v.trim();
                row.error = null;
                onChanged();
              },
            ),
            _StudentDropdownField(
              label: 'Chọn sinh viên',
              value: row.studentId,
              students: allStudents,
              suggestedEmail: row.studentEmail,
              onChanged: (studentId) {
                row.studentId = (studentId ?? '').trim();
                final parent = context
                    .findAncestorStateOfType<_EnrollmentBulkImportPageState>();
                if (parent != null) {
                  row.error = parent._validateRow(
                    row,
                    allStudents,
                    allEnrollments,
                  );
                } else {
                  row.error = null;
                }
                onChanged();
              },
            ),
          ],
        );
      },
    );
  }
}

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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _StudentDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<UserModel> students;
  final String suggestedEmail;
  final ValueChanged<String?> onChanged;

  const _StudentDropdownField({
    required this.label,
    required this.value,
    required this.students,
    required this.suggestedEmail,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // sort students by displayName/email
    final sorted = [...students]
      ..sort((a, b) {
        final ka =
            (a.displayName?.trim().isNotEmpty == true
                    ? a.displayName!
                    : a.email)
                .toLowerCase();
        final kb =
            (b.displayName?.trim().isNotEmpty == true
                    ? b.displayName!
                    : b.email)
                .toLowerCase();
        return ka.compareTo(kb);
      });

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
          value:
              (value != null &&
                  value!.isNotEmpty &&
                  sorted.any((s) => s.uid == value))
              ? value
              : null,
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
                : 'Chọn sinh viên...',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— Chọn sinh viên —'),
            ),
            ...sorted.map(
              (s) => DropdownMenuItem<String?>(
                value: s.uid,
                child: Text(
                  '${s.displayName} (${s.email})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        s.email.toLowerCase() == suggestedEmail.toLowerCase()
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: s.email.toLowerCase() == suggestedEmail.toLowerCase()
                        ? colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
