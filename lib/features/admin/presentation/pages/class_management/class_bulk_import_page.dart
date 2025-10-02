// lib/features/admin/presentation/pages/class_bulk_import_page.dart
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/models/class_model.dart';
import '../../../../../core/utils/template_downloader.dart';
import '../../../data/services/admin_service.dart';

/// Header mong đợi trong file Excel (không phân biệt hoa/thường)
const _expectedHeaders = <String>[
  'classCode',
  'className',
  'minStudents',
  'maxStudents',
  'startYear',
  'endYear',
  'description',
];

class _RowState {
  final int rowIndex;
  String classCode;
  String className;
  int minStudents;
  int maxStudents;
  int startYear;
  int endYear;
  String? description;

  /// Lỗi validate hiển thị dưới dòng
  String? error;

  _RowState({
    required this.rowIndex,
    required this.classCode,
    required this.className,
    required this.minStudents,
    required this.maxStudents,
    required this.startYear,
    required this.endYear,
    this.description,
    this.error,
  });
}

class ClassBulkImportPage extends StatefulWidget {
  const ClassBulkImportPage({super.key});

  @override
  State<ClassBulkImportPage> createState() => _ClassBulkImportPageState();
}

class _ClassBulkImportPageState extends State<ClassBulkImportPage> {
  List<_RowState> _rows = [];
  String? _fileName;
  String? _message;
  bool _submitting = false;

  /// ====== Helpers ======

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
      final bytes = res.files.single.bytes!;
      final rows = await _parseClassesXlsx(bytes);
      setState(() {
        _rows = rows;
        _fileName = res.files.single.name;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_RowState>> _parseClassesXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }

    // Ưu tiên sheet "classes" / "class"
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'classes' || lk == 'class') {
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
    String cellStr(List<Data?> row, int col) => (col >= 0 && col < row.length)
        ? (row[col]?.value?.toString() ?? '')
        : '';

    final out = <_RowState>[];
    final seenClassCodes = <String>{}; // Để check trùng lặp trong file

    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      if (row.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue; // bỏ dòng trống
      }

      final classCode = cellStr(row, idxOf('classCode')).trim().toUpperCase();
      final className = cellStr(row, idxOf('className')).trim();
      final minStr = cellStr(row, idxOf('minStudents')).trim();
      final maxStr = cellStr(row, idxOf('maxStudents')).trim();
      final syStr = cellStr(row, idxOf('startYear')).trim();
      final eyStr = cellStr(row, idxOf('endYear')).trim();
      final desc = cellStr(row, idxOf('description')).trim();

      if (classCode.isEmpty || className.isEmpty) continue;

      // Kiểm tra trùng lặp classCode trong file
      if (seenClassCodes.contains(classCode)) {
        throw Exception(
          'Mã lớp "$classCode" bị trùng lặp trong file (dòng ${i + 1})',
        );
      }
      seenClassCodes.add(classCode);

      out.add(
        _RowState(
          rowIndex: i,
          classCode: classCode,
          className: className,
          minStudents: int.tryParse(minStr) ?? 0,
          maxStudents: int.tryParse(maxStr) ?? 0,
          startYear: int.tryParse(syStr) ?? 0,
          endYear: int.tryParse(eyStr) ?? 0,
          description: desc.isEmpty ? null : desc,
        ),
      );
    }
    return out;
  }

  String? _validateRow(_RowState r, List<ClassModel> existingClasses) {
    if (r.classCode.trim().isEmpty) return 'Thiếu classCode';
    if (r.className.trim().isEmpty) return 'Thiếu className';
    if (r.minStudents <= 0) return 'minStudents phải > 0';
    if (r.maxStudents <= 0) return 'maxStudents phải > 0';
    if (r.maxStudents <= r.minStudents) {
      return 'maxStudents phải > minStudents';
    }
    if (r.startYear <= 0) return 'startYear không hợp lệ';
    if (r.endYear <= 0) return 'endYear không hợp lệ';
    if (r.endYear < r.startYear) return 'endYear phải ≥ startYear';

    // Kiểm tra trùng lặp với lớp đã tồn tại
    final existingClass = existingClasses.firstWhere(
      (c) =>
          c.classCode.toUpperCase().trim() == r.classCode.toUpperCase().trim(),
      orElse: () => ClassModel(
        id: '',
        classCode: '',
        className: '',
        minStudents: 0,
        maxStudents: 0,
        startYear: 0,
        endYear: 0,
        isArchived: false,
      ),
    );

    if (existingClass.id.isNotEmpty) {
      return 'Mã lớp "${r.classCode}" đã tồn tại trong hệ thống';
    }

    return null;
  }

  bool _allValid(List<ClassModel> existingClasses) =>
      _rows.isNotEmpty &&
      _rows.every((e) => _validateRow(e, existingClasses) == null);

  Future<void> _submit(List<ClassModel> allClasses) async {
    if (_rows.isEmpty) return;

    // Validate lần cuối
    bool hasError = false;
    for (final r in _rows) {
      r.error = _validateRow(r, allClasses);
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
        await admin.createClass(
          classCode: r.classCode.trim().toUpperCase(),
          className: r.className.trim(),
          minStudents: r.minStudents,
          maxStudents: r.maxStudents,
          startYear: r.startYear,
          endYear: r.endYear,
          description: r.description,
        );
        created++;
      }

      setState(() {
        _message = 'Thành công! Đã tạo mới $created lớp học.';
        _rows = []; // Clear data sau khi import thành công
        _fileName = null;
      });
    } catch (e) {
      setState(
        () =>
            _message = 'Lỗi:: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  /// ====== UI ======

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Nhập lớp từ Excel'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: StreamBuilder<List<ClassModel>>(
          stream: context.read<AdminService>().getAllClassStream(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];

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
                        'Lưu ý: Mã lớp không được trùng lặp trong file và không được trùng với lớp đã có trong hệ thống',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Tải template',
                            onPressed: () =>
                                TemplateDownloader.download('class'),
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
                            onPressed: (_allValid(all) && !_submitting)
                                ? () => _submit(all)
                                : null,
                            variant: _ButtonVariant.primary,
                          ),
                        ],
                      ),

                      // File and Status Info
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
                            allClasses: all,
                            isWideScreen: isWideScreen,
                            onChanged: () => setState(() {}),
                          ),
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
  final List<_RowState> rows;
  final List<ClassModel> allClasses;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _DataList({
    required this.rows,
    required this.allClasses,
    required this.isWideScreen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.preview, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Xem trước dữ liệu (${rows.length} lớp)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // List
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              return _RowCard(
                row: rows[index],
                allClasses: allClasses,
                isWideScreen: isWideScreen,
                onChanged: () {
                  rows[index].error = null;
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

// Simplified Row Card (removed matching dropdown and create new checkbox)
class _RowCard extends StatelessWidget {
  final _RowState row;
  final List<ClassModel> allClasses;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _RowCard({
    required this.row,
    required this.allClasses,
    required this.isWideScreen,
    required this.onChanged,
  });

  String? _validateRow(_RowState r, List<ClassModel> existingClasses) {
    if (r.classCode.trim().isEmpty) return 'Thiếu mã lớp';
    if (r.className.trim().isEmpty) return 'Thiếu tên lớp';
    if (r.minStudents <= 0) return 'Số sinh viên tối thiểu phải > 0';
    if (r.maxStudents <= 0) return 'Số sinh viên tối đa phải > 0';
    if (r.maxStudents <= r.minStudents) return 'Số tối đa phải > số tối thiểu';
    if (r.startYear <= 0) return 'Năm bắt đầu không hợp lệ';
    if (r.endYear <= 0) return 'Năm kết thúc không hợp lệ';
    if (r.endYear < r.startYear) return 'Năm kết thúc phải ≥ năm bắt đầu';

    // Kiểm tra trùng lặp với lớp đã tồn tại
    final existingClass = existingClasses.firstWhere(
      (c) =>
          c.classCode.toUpperCase().trim() == r.classCode.toUpperCase().trim(),
      orElse: () => ClassModel(
        id: '',
        classCode: '',
        className: '',
        minStudents: 0,
        maxStudents: 0,
        startYear: 0,
        endYear: 0,
        isArchived: false,
      ),
    );

    if (existingClass.id.isNotEmpty) {
      return 'Mã lớp "${r.classCode}" đã tồn tại trong hệ thống';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = _validateRow(row, allClasses);
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
                    hasError ? Icons.error_outline : Icons.class_outlined,
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
                        '${row.classCode} — ${row.className}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (hasError)
                        Text(
                          error,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status Chip
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
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 4,
          childAspectRatio: 6,
          children: [
            _FormField(
              label: 'Mã lớp',
              value: row.classCode,
              icon: Icons.tag,
              onChanged: (v) {
                row.classCode = v.trim().toUpperCase();
                onChanged();
              },
            ),
            _FormField(
              label: 'Tên lớp',
              value: row.className,
              icon: Icons.class_outlined,
              onChanged: (v) {
                row.className = v.trim();
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
                onChanged();
              },
            ),
            _FormField(
              label: 'Năm bắt đầu',
              value: '${row.startYear}',
              icon: Icons.calendar_today,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.startYear = int.tryParse(v) ?? 0;
                onChanged();
              },
            ),
            _FormField(
              label: 'Năm kết thúc',
              value: '${row.endYear}',
              icon: Icons.event,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                row.endYear = int.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ],
        );
      },
    );
  }
}

// Form Field Component
class _FormField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _FormField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
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
