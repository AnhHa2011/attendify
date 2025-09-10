import 'package:attendify/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/providers/auth_provider.dart';
import '../../../app/providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import '../../../services/firebase/class_service.dart';
import 'class_detail_page.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _maxAbsCtrl = TextEditingController(text: '3');

  // lịch học đơn giản
  int _day = 1;
  final _startCtrl = TextEditingController(text: '07:30');
  final _endCtrl = TextEditingController(text: '09:30');

  // chọn giảng viên (dành cho admin)
  String? _lecturerUid;

  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _maxAbsCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final auth = context.read<AuthProvider>();
      final u = auth.user!;
      final svc = context.read<ClassService>(); // KHÔNG cần ClassProvider
      final classId = await svc.createClass(
        lecturerId: u.uid,
        lecturerName: u.displayName ?? '',
        lecturerEmail: u.email ?? '',
        className: _nameCtrl.text.trim(),
        classCode: _codeCtrl.text.trim(),
        schedules: [
          ClassSchedule(day: _day, start: _startCtrl.text, end: _endCtrl.text),
        ],
        maxAbsences: int.parse(_maxAbsCtrl.text),
      );
      // chuẩn bị thông tin giảng viên

      if (!mounted) return;
      // thành công → navigate và reset loading
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClassDetailPage(classId: classId)),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tạo lớp thành công')));
    } catch (e, st) {
      debugPrint('Error creating class: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tạo lớp: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role?.toKey() == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo lớp học')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Nếu là admin → chọn giảng viên; nếu giảng viên → hiển thị cố định
                  if (isAdmin) ...[
                    Text(
                      'Giảng viên',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, String>>>(
                      stream: context.read<ClassProvider>().lecturers(),
                      builder: (context, snap) {
                        final list = snap.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _lecturerUid,
                          decoration: const InputDecoration(
                            labelText: 'Chọn giảng viên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: list
                              .map(
                                (m) => DropdownMenuItem<String>(
                                  value: m['uid'],
                                  child: Text('${m['name']}  —  ${m['email']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _lecturerUid = v;
                              final m = list.firstWhere((e) => e['uid'] == v);
                            });
                          },
                          validator: (v) => v == null
                              ? 'Vui lòng chọn giảng viên phụ trách'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(auth.user?.displayName ?? ''),
                      subtitle: Text(auth.user?.email ?? ''),
                      trailing: const Text('Giảng viên'),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên môn',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập tên môn' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mã môn',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập mã môn' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _day,
                          decoration: const InputDecoration(
                            labelText: 'Lịch học (thứ)',
                            prefixIcon: Icon(Icons.event_repeat_outlined),
                          ),
                          items:
                              const {
                                    1: 'Thứ 2',
                                    2: 'Thứ 3',
                                    3: 'Thứ 4',
                                    4: 'Thứ 5',
                                    5: 'Thứ 6',
                                    6: 'Thứ 7',
                                    7: 'Chủ nhật',
                                  }.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => _day = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _startCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bắt đầu (HH:mm)',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Bắt đầu?' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _endCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kết thúc (HH:mm)',
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Kết thúc?' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxAbsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số buổi vắng tối đa cho phép',
                      prefixIcon: Icon(Icons.rule_folder_outlined),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Nhập số nguyên >= 0';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tạo lớp'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
