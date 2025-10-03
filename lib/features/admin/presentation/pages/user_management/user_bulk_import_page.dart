import 'dart:typed_data';
import 'package:attendify/core/utils/template_downloader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:provider/provider.dart';
import '../../../../auth/data/services/auth_rest_service.dart';
import '../../../data/services/admin_service.dart';

const _expectedHeaders = ['email', 'displayName', 'role', 'password'];

class _UserRowState {
  final int rowIndex;
  String email;
  String displayName;
  String role;
  String? password;
  String? error;

  _UserRowState({
    required this.rowIndex,
    required this.email,
    required this.displayName,
    required this.role,
    this.password,
    this.error,
  });
}

class UserBulkImportPage extends StatefulWidget {
  const UserBulkImportPage({super.key});

  @override
  State<UserBulkImportPage> createState() => _UserBulkImportPageState();
}

class _UserBulkImportPageState extends State<UserBulkImportPage> {
  List<_UserRowState> _rows = [];
  String? _fileName;
  String? _message;
  bool _submitting = false;

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
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
      setState(() => _message = 'Không có file hoặc file rỗng.');
      return;
    }

    try {
      final bytes = res.files.first.bytes!;
      final rows = await _parseUsersXlsx(bytes);
      setState(() {
        _rows = rows;
        _fileName = res.files.first.name;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_UserRowState>> _parseUsersXlsx(Uint8List bytes) async {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception(
        'File không hợp lệ hoặc không phải .xlsx. Hãy dùng template đã cung cấp.',
      );
    }

    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }

    // Ưu tiên sheet "users" / "user"
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'users' || lk == 'user') {
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

    // Check header theo thứ tự
    final minHeaders = _expectedHeaders.take(3).toList();
    for (int i = 0; i < minHeaders.length; i++) {
      final actual = (i < rawHeader.length) ? rawHeader[i] : '';
      if (actual != minHeaders[i]) {
        throw Exception(
          'File không đúng template. Cột ${i + 1} phải là "${minHeaders[i]}", hiện tại là "$actual".',
        );
      }
    }
    if (rawHeader.length >= 4 && rawHeader[3] != 'password') {
      throw Exception('Cột thứ 4 (nếu có) phải là "password".');
    }

    int idxOf(String key) => rawHeader.indexOf(key);
    String cellStr(List<Data?> row, int col) => (col >= 0 && col < row.length)
        ? (row[col]?.value?.toString() ?? '')
        : '';

    final out = <_UserRowState>[];
    final seenEmails = <String>{}; // Để check trùng lặp trong file

    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      if (row.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue; // bỏ dòng trống
      }

      final email = cellStr(row, idxOf('email')).trim().toLowerCase();
      final displayName = cellStr(row, idxOf('displayName')).trim();
      final role = cellStr(row, idxOf('role')).trim().toLowerCase();
      final password = cellStr(row, idxOf('password')).trim();

      if (email.isEmpty || displayName.isEmpty || role.isEmpty) continue;

      // Kiểm tra trùng lặp email trong file
      if (seenEmails.contains(email)) {
        throw Exception(
          'Email "$email" bị trùng lặp trong file (dòng ${i + 1})',
        );
      }
      seenEmails.add(email);

      out.add(
        _UserRowState(
          rowIndex: i,
          email: email,
          displayName: displayName,
          role: role,
          password: password.isEmpty ? null : password,
        ),
      );
    }
    return out;
  }

  String? _validateRow(_UserRowState r) {
    if (r.email.trim().isEmpty) return 'Thiếu email';
    if (!r.email.contains('@')) return 'Email không hợp lệ';
    if (r.displayName.trim().isEmpty) return 'Thiếu tên hiển thị';
    if (r.role != 'student' && r.role != 'lecturer')
      return 'Role phải là "student" hoặc "lecturer"';
    if (r.password != null && r.password!.length < 6)
      return 'Mật khẩu phải ≥ 6 ký tự';
    return null;
  }

  bool _allValid() =>
      _rows.isNotEmpty && _rows.every((e) => _validateRow(e) == null);

  Future<void> _submit() async {
    if (_rows.isEmpty) return;

    // Validate lần cuối
    bool hasError = false;
    for (final r in _rows) {
      r.error = _validateRow(r);
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

    final adminService = context.read<AdminService>();
    final rest = AuthRestService();

    int ok = 0;
    int fail = 0;
    final errors = <String>[];

    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final email = r.email.trim();
      final displayName = r.displayName.trim();
      final role = r.role.trim().toLowerCase();
      String password = r.password?.trim() ?? 'Abc12345!';

      try {
        // 1) Tạo user trong Auth bằng REST API
        final uid = await rest.signUpWithEmailPassword(
          email: email,
          password: password,
        );

        // 2) Ghi profile vào Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'displayName': displayName,
          'role': role == 'lecturer' ? 'lecture' : role,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'isActive': true,
        });

        // 3) (Tuỳ chọn) Gửi email reset để user tự đặt lại password thật
        try {
          await adminService.sendPasswordResetForUserAsAdmin(email);
        } catch (_) {
          // không fail batch vì bước này
        }

        ok++;
      } catch (e) {
        fail++;
        errors.add('${r.displayName} ($email): $e');
      }
    }

    setState(() {
      _submitting = false;
      _message =
          'Hoàn tất! Thành công: $ok • Thất bại: $fail'
          '${errors.isNotEmpty ? '\nLỗi: ${errors.take(3).join(', ')}${errors.length > 3 ? '...' : ''}' : ''}';
      if (ok > 0) {
        _rows = []; // Clear data sau khi import thành công
        _fileName = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Nhập tài khoản từ Excel'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              final isWideScreen = MediaQuery.of(context).size.width > 800;

              return Column(
                children: [
                  // Header Section with Actions (giữ nguyên nội dung cũ)
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
                          'Lưu ý: Email không được trùng lặp trong file. Role phải là "student" hoặc "lecturer". Nếu không có password, hệ thống sẽ dùng mật khẩu tạm và gửi email reset.',
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
                                  TemplateDownloader.download('user'),
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
                              onPressed: (_allValid() && !_submitting)
                                  ? _submit
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

                  // Content Area (không dùng Expanded; list phía dưới không tự cuộn)
                  Padding(
                    padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                    child: _rows.isEmpty
                        ? _EmptyState(colorScheme: colorScheme)
                        : _DataList(
                            rows: _rows,
                            isWideScreen: isWideScreen,
                            onChanged: () => setState(() {}),
                          ),
                  ),
                ],
              );
            },
          ),
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
                  message!.toLowerCase().contains('lỗi') ||
                          message!.toLowerCase().contains('có lỗi') ||
                          message!.toLowerCase().contains('thất bại')
                      ? Icons.error_outline
                      : message!.contains('Hoàn tất')
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 16,
                  color:
                      message!.toLowerCase().contains('lỗi') ||
                          message!.toLowerCase().contains('có lỗi') ||
                          message!.toLowerCase().contains('thất bại')
                      ? colorScheme.error
                      : message!.contains('Hoàn tất')
                      ? Colors.green
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      color:
                          message!.toLowerCase().contains('lỗi') ||
                              message!.toLowerCase().contains('có lỗi') ||
                              message!.toLowerCase().contains('thất bại')
                          ? colorScheme.error
                          : message!.contains('Hoàn tất')
                          ? Colors.green
                          : colorScheme.onSurface,
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
  final List<_UserRowState> rows;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _DataList({
    required this.rows,
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
              'Xem trước dữ liệu (${rows.length} tài khoản)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Thay phần List trong _DataList:
        ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _UserRowCard(
            row: rows[index],
            isWideScreen: isWideScreen,
            onChanged: () {
              rows[index].error = null;
              onChanged();
            },
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }
}

// User Row Card
class _UserRowCard extends StatelessWidget {
  final _UserRowState row;
  final bool isWideScreen;
  final VoidCallback onChanged;

  const _UserRowCard({
    required this.row,
    required this.isWideScreen,
    required this.onChanged,
  });

  String? _validateRow(_UserRowState r) {
    if (r.email.trim().isEmpty) return 'Thiếu email';
    if (!r.email.contains('@')) return 'Email không hợp lệ';
    if (r.displayName.trim().isEmpty) return 'Thiếu tên hiển thị';
    if (r.role != 'student' && (r.role != 'lecturer')) {
      return 'Role phải là "student" hoặc "lecturer"';
    }
    if (r.password != null && r.password!.length < 6) {
      return 'Mật khẩu phải ≥ 6 ký tự';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = _validateRow(row);
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
                    hasError
                        ? Icons.error_outline
                        : row.role == 'lecturer'
                        ? Icons.person_outline
                        : Icons.school_outlined,
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
                        '${row.displayName} — ${row.email}',
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
                // Role & Status Chips
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: row.role == 'lecturer'
                            ? colorScheme.secondary.withOpacity(0.1)
                            : colorScheme.tertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: row.role == 'lecturer'
                              ? colorScheme.secondary.withOpacity(0.3)
                              : colorScheme.tertiary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        row.role == 'lecturer' ? 'Giảng viên' : 'Sinh viên',
                        style: TextStyle(
                          color: row.role == 'lecturer'
                              ? colorScheme.secondary
                              : colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasError
                            ? colorScheme.error.withOpacity(0.1)
                            : colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasError
                              ? colorScheme.error.withOpacity(0.3)
                              : colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        hasError ? 'Lỗi' : 'Tạo mới',
                        style: TextStyle(
                          color: hasError
                              ? colorScheme.error
                              : colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
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
        // responsive columns giống các page trước
        final cols = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        const spacing = 16.0;
        final tileW = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        Widget cell(Widget child) => SizedBox(width: tileW, child: child);

        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            cell(
              _FormField(
                label: 'Email',
                value: row.email,
                icon: Icons.email_outlined,
                onChanged: (v) {
                  row.email = v.trim().toLowerCase();
                  onChanged();
                },
              ),
            ),
            cell(
              _FormField(
                label: 'Tên hiển thị',
                value: row.displayName,
                icon: Icons.person_outline,
                onChanged: (v) {
                  row.displayName = v.trim();
                  onChanged();
                },
              ),
            ),
            cell(
              _FormField(
                label: 'Vai trò (student/lecturer)',
                value: row.role,
                icon: Icons.assignment_ind_outlined,
                onChanged: (v) {
                  row.role = v.trim().toLowerCase();
                  onChanged();
                },
              ),
            ),
            cell(
              _FormField(
                label: 'Mật khẩu (tùy chọn)',
                value: row.password ?? '',
                icon: Icons.lock_outline,
                obscureText: true,
                onChanged: (v) {
                  row.password = v.trim().isEmpty ? null : v.trim();
                  onChanged();
                },
              ),
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
  final bool obscureText;
  final ValueChanged<String> onChanged;

  const _FormField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.obscureText = false,
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
          obscureText: obscureText,
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
