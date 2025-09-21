import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../classes/data/services/class_service.dart';
import '../../data/services/leave_request_service.dart';

class LeaveRequestPage extends StatefulWidget {
  final String? presetClassId; // có thể truyền sẵn từ trang lớp/session
  final String? presetSessionId; // nếu có

  const LeaveRequestPage({super.key, this.presetClassId, this.presetSessionId});

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  String? _classId;
  String? _sessionId; // tùy bạn có muốn bắt buộc không
  final _picked = <(Uint8List bytes, String name)>[];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _classId = widget.presetClassId;
    _sessionId = widget.presetSessionId ?? '';
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // cần bytes để putData
    );
    if (res == null) return;

    for (final f in res.files) {
      final data = f.bytes;
      if (data != null && data.isNotEmpty) {
        _picked.add((data, f.name ?? 'evidence.jpg'));
      }
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null || _classId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lớp')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final leaveSrv = context.read<LeaveRequestService>();
      final user = auth.user!;
      await leaveSrv.createLeaveRequest(
        studentUid: user.uid,
        studentName: user.displayName ?? 'N/A',
        studentEmail: user.email ?? 'N/A',
        classId: _classId!,
        sessionId: _sessionId ?? '',
        reason: _reasonCtrl.text.trim(),
        files: _picked,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi đơn xin nghỉ!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi đơn: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Xin nghỉ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Chọn lớp (lấy lớp mà SV đã enrolled)
          StreamBuilder(
            stream: classService.getRichEnrolledClassesStream(auth.user!.uid),
            builder: (context, snapshot) {
              final classes = (snapshot.data ?? []) as List;
              return DropdownButtonFormField<String>(
                value: _classId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chọn lớp',
                  border: OutlineInputBorder(),
                ),
                items: classes
                    .map<DropdownMenuItem<String>>(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.courseCode ?? ''} • ${c.courseName ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _classId = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Chưa chọn lớp' : null,
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Lý do xin nghỉ',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do' : null,
          ),
          const SizedBox(height: 12),

          // Chọn ảnh minh chứng
          Row(
            children: [
              FilledButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.attach_file),
                label: const Text('Đính kèm ảnh'),
              ),
              const SizedBox(width: 12),
              Text('${_picked.length} tệp đã chọn'),
            ],
          ),
          const SizedBox(height: 8),
          if (_picked.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _picked
                  .asMap()
                  .entries
                  .map(
                    (e) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            e.value.$1,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() => _picked.removeAt(e.key));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Gửi đơn'),
          ),
        ],
      ),
    );
  }
}
