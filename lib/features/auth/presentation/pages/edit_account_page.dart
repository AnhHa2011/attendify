// lib/presentation/pages/common/edit_account_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

class EditAccountPage extends StatefulWidget {
  final String currentName;
  const EditAccountPage({super.key, required this.currentName});

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  final _nameCtrl = TextEditingController();
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  final _svc = AccountService();

  bool _loading = false;
  String? _previewUrl; // hiển thị URL hiện tại
  Uint8List? _pickedBytes; // ảnh mới chọn (chưa upload)
  String? _pickedName;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.currentName;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // 1) cập nhật tên
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) {
        await _svc.updateDisplayName(name);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarWidget = CircleAvatar(
      radius: 36,
      backgroundImage: _pickedBytes != null
          ? MemoryImage(_pickedBytes!)
          : (_previewUrl != null && _previewUrl!.isNotEmpty)
          ? NetworkImage(_previewUrl!) as ImageProvider
          : null,
      child:
          (_pickedBytes == null &&
              (_previewUrl == null || _previewUrl!.isEmpty))
          ? const Icon(Icons.person, size: 36)
          : null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa tài khoản')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Tên hiển thị
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
