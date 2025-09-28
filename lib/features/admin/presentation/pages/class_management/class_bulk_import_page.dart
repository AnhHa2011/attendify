// lib/features/admin/presentation/pages/class_bulk_import_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/models/class_model.dart';
import '../../../../../core/utils/template_downloader.dart';
import '../../../data/services/admin_service.dart';
// NOTE: Sửa đường dẫn import dưới đây cho đúng với project bạn:
// - Nếu ClassModel nằm ở lib/common/models: dùng dòng đầu, còn nếu ở lib/data/models: dùng dòng thứ hai
// import '../../../data/models/class_model.dart';

const _expectedHeaders = ['classCode', 'className', 'credits'];

class _RowState {
  final int rowIndex;
  String classCode;
  String className;
  int credits;
  String? matchedclassCode; // nếu đã khớp class hiện có
  bool createNew; // nếu không khớp và muốn tạo mới
  String? error;

  _RowState({
    required this.rowIndex,
    required this.classCode,
    required this.className,
    required this.credits,
    this.createNew = false,
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
      final rows = await _parseClasssXlsx(bytes);
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

  Future<List<_RowState>> _parseClasssXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }
    // Ưu tiên sheet tên Classs/Class, nếu không có dùng sheet đầu
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'classs' || lk == 'class') {
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

      final code = (map['classCode'] ?? '').toString().trim();
      final name = (map['className'] ?? '').toString().trim();
      final creditsStr = (map['credits'] ?? '').toString().trim();
      final credits = int.tryParse(creditsStr);

      if (code.isEmpty || name.isEmpty || credits == null) continue;

      out.add(
        _RowState(
          rowIndex: i,
          classCode: code,
          className: name,
          credits: credits,
        ),
      );
    }
    return out;
  }

  Future<void> _submit(List<ClassModel> allClasss) async {
    if (_rows.isEmpty) return;

    // Kiểm tra: mỗi dòng phải chọn khớp hoặc bật Tạo mới
    for (final r in _rows) {
      r.error = null;
      final ok = (r.matchedclassCode != null) || r.createNew;
      if (!ok) r.error = 'Chưa chọn class hoặc đánh dấu "Tạo mới".';
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
          await admin.createClass(
            classCode: r.classCode,
            className: r.className,
            minStudents: 0,
            maxStudents: 0,
          );
          created++;
        } else if (r.matchedclassCode != null) {
          await admin.updateClass(
            id: r.matchedclassCode!,
            classCode: r.classCode,
            className: r.className,
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
        child: StreamBuilder<List<ClassModel>>(
          stream: context.read<AdminService>().getAllClassStream(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];

            // Auto-match theo classCode
            for (final r in _rows) {
              if (r.matchedclassCode == null) {
                final idx = all.indexWhere(
                  (c) =>
                      c.classCode.toUpperCase().trim() ==
                      r.classCode.toUpperCase().trim(),
                );
                if (idx >= 0) r.matchedclassCode = all[idx].id;
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
                                '${r.rowIndex}. ${r.classCode} — ${r.className}',
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
                                          initialValue: r.matchedclassCode,
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
                                                  '${c.classCode} — ${c.className}',
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              r.matchedclassCode = val;
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
                                            if (v) r.matchedclassCode = null;
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
