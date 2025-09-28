// lib/presentation/pages/admin/user_form_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';

class UserFormPage extends StatefulWidget {
  final UserModel? user; // Nullable: nếu null là tạo mới, ngược lại là cập nhật

  const UserFormPage({super.key, this.user});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  UserRole _selectedRole = UserRole.student; // Mặc định là sinh viên
  bool _isLoading = false;

  bool get _isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user?.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    if (_isEditMode) {
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final adminService = context.read<AdminService>();

    try {
      if (_isEditMode) {
        // Cập nhật người dùng
        await adminService.updateUser(
          uid: widget.user!.uid,
          displayName: _nameController.text.trim(),
          role: _selectedRole,
        );
      } else {
        // Tạo người dùng mới
        await adminService.createNewUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _nameController.text.trim(),
          role: _selectedRole,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thao tác thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Chỉnh sửa người dùng' : 'Thêm người dùng mới',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isEditMode, // Không cho sửa email
                validator: (value) {
                  if (value!.trim().isEmpty) return 'Vui lòng nhập email';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              // Chỉ hiển thị trường mật khẩu khi tạo mới
              if (!_isEditMode) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  obscureText: true,
                  validator: (value) => value!.trim().length < 6
                      ? 'Mật khẩu phải có ít nhất 6 ký tự'
                      : null,
                ),
              ],
              const SizedBox(height: 24),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: UserRole.values
                    .where(
                      (role) => role != UserRole.admin,
                    ) // Không cho tạo admin khác
                    .map((UserRole role) {
                      return DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.displayName),
                      );
                    })
                    .toList(),
                onChanged: (UserRole? newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save),
                label: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditMode ? 'Lưu thay đổi' : 'Tạo người dùng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
