// lib/presentation/pages/common/edit_account_page.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

class EditAccountPage extends StatefulWidget {
  final String currentName;
  final String? currentPhotoUrl;
  const EditAccountPage({
    super.key,
    required this.currentName,
    this.currentPhotoUrl,
  });

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
    _previewUrl = widget.currentPhotoUrl;
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
      return;
    }

    setState(() {
      _pickedBytes = res.files.first.bytes;
      _pickedName = res.files.first.name;
      _previewUrl = null; // ưu tiên preview bằng bytes vừa chọn
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // 1) cập nhật tên
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) {
        await _svc.updateDisplayName(name);
      }

      // 2) upload avatar nếu có chọn ảnh mới
      if (_pickedBytes != null && _pickedName != null) {
        final url = await _svc.uploadAvatarAndSave(
          bytes: _pickedBytes!,
          fileName: _pickedName!,
        );
        setState(() => _previewUrl = url);
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Chỉnh sửa tài khoản'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Avatar
            Center(child: avatarWidget),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickAvatar,
                icon: const Icon(Icons.upload),
                label: const Text('Chọn ảnh đại diện'),
              ),
            ),
            const SizedBox(height: 16),

            // Tên hiển thị
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Mật khẩu hiện tại
            TextField(
              controller: _oldPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),

            // Mật khẩu mới
            TextField(
              controller: _newPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (>= 6 ký tự)',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),

            // Xác nhận mật khẩu mới
            TextField(
              controller: _confirmPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),

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
