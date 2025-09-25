import 'dart:typed_data';
import 'package:attendify/features/common/utils/template_downloader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import '../../../../auth/data/services/auth_rest_service.dart';
import '../../../data/services/admin_service.dart';

const _expectedHeaders = ['email', 'displayName', 'role', 'password'];

class UserBulkImportPage extends StatefulWidget {
  const UserBulkImportPage({super.key});

  @override
  State<UserBulkImportPage> createState() => _UserBulkImportPageState();
}

class _UserBulkImportPageState extends State<UserBulkImportPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _submitting = false;
  String? _message;

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _message = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'], // chỉ cho phép .xlsx
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
      setState(() => _message = 'Không có file hoặc file rỗng.');
      return;
    }

    final bytes = res.files.first.bytes!;
    try {
      final rows = _parseExcel(bytes);
      setState(() {
        _rows = rows;
        if (_rows.isEmpty) {
          _message = 'Không tìm thấy dữ liệu hợp lệ trong file.';
        }
      });
    } catch (e) {
      setState(() {
        _rows = [];
        _message = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _parseExcel(Uint8List bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception(
        'File không hợp lệ hoặc không phải .xlsx. '
        'Hãy dùng template đã cung cấp.',
      );
    }

    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet hợp lệ.');
    }

    final firstNonEmpty = excel.tables.values.firstWhere(
      (t) => t.rows.isNotEmpty,
      orElse: () => excel.tables.values.first,
    );
    final table = firstNonEmpty;
    if (table.rows.isEmpty) {
      throw Exception('Sheet đầu tiên không có dữ liệu.');
    }

    final headerRow = table.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();

    // check header
    final minHeaders = _expectedHeaders.take(3).toList();
    for (int i = 0; i < minHeaders.length; i++) {
      final actual = (i < headerRow.length) ? headerRow[i] : '';
      if (actual != minHeaders[i]) {
        throw Exception(
          'File không đúng template. Cột ${i + 1} phải là "${minHeaders[i]}", '
          'hiện tại là "$actual".',
        );
      }
    }
    if (headerRow.length >= 4 && headerRow[3] != 'password') {
      throw Exception('Cột thứ 4 (nếu có) phải là "password".');
    }

    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < table.maxRows; i++) {
      final row = table.rows[i];
      if (row.isEmpty) continue;

      final map = <String, dynamic>{};
      for (var j = 0; j < headerRow.length && j < row.length; j++) {
        final key = headerRow[j];
        final val = row[j]?.value?.toString().trim();
        if (key.isNotEmpty) {
          map[key] = val;
        }
      }

      final email = (map['email'] ?? '').toString().trim();
      final displayName = (map['displayName'] ?? '').toString().trim();
      final role = (map['role'] ?? '').toString().trim().toLowerCase();
      final password = (map['password'] ?? '').toString().trim();

      if (email.isEmpty || displayName.isEmpty) continue;
      if (role != 'student' && role != 'lecturer') {
        throw Exception('Role không hợp lệ tại dòng ${i + 1}: "$role"');
      }

      rows.add({
        'email': email,
        'displayName': displayName,
        'role': role,
        if (password.isNotEmpty) 'password': password,
      });
    }

    return rows;
  }

  Future<void> _submit() async {
    if (_rows.isEmpty) return;

    setState(() {
      _submitting = true;
      _message = null;
    });

    final adminService = context
        .read<AdminService>(); // dùng để ghi Firestore & gửi reset
    final rest = AuthRestService();

    int ok = 0;
    int fail = 0;
    final errors = <String>[];

    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final email = (r['email'] ?? '').toString().trim();
      final displayName = (r['displayName'] ?? '').toString().trim();
      final role = (r['role'] ?? '').toString().trim().toLowerCase();
      String password = (r['password'] ?? '').toString().trim();

      if (email.isEmpty ||
          displayName.isEmpty ||
          (role != 'student' && role != 'lecturer')) {
        fail++;
        errors.add('Dòng ${i + 2}: dữ liệu không hợp lệ.');
        continue;
      }

      // Nếu thiếu mật khẩu -> dùng mật khẩu tạm (hoặc bắt buộc user đặt trong mail reset)
      password = password.isNotEmpty ? password : 'Abc12345!';

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
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
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
        errors.add('Dòng ${i + 2} ($email): $e');
      }
    }

    setState(() {
      _submitting = false;
      _message =
          'Hoàn tất. Thành công: $ok • Thất bại: $fail'
          '${errors.isNotEmpty ? '\n${errors.take(5).join('\n')}${errors.length > 5 ? '\n...' : ''}' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Nhập tài khoản từ Excel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Tải template môn học (.xlsx)'),
              onPressed: () => TemplateDownloader.download('user'),
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
                if (_rows.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: _submitting
                        ? const Text('Đang nhập...')
                        : const Text('Nhập người dùng'),
                  ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('Chưa có dữ liệu xem trước'))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        return ListTile(
                          dense: true,
                          leading: Text('${i + 1}'),
                          title: Text(r['displayName'] ?? ''),
                          subtitle: Text(
                            '${r['email']} • ${r['role']}'
                            '${r.containsKey('password') ? ' • (has password)' : ''}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
