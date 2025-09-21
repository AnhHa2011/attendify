// lib/presentation/pages/profile/my_account_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/services/account_service.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final _svc = AccountService();

  final _nameCtl = TextEditingController();
  final _photoCtl = TextEditingController();
  final _curPwdCtl = TextEditingController();
  final _newPwdCtl = TextEditingController();
  final _newPwd2Ctl = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _changingPwd = false;
  String? _email;
  String? _role;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = _svc.currentUser;
      _email = u?.email ?? '';
      _nameCtl.text = u?.displayName ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u?.uid)
          .get();
      final data = doc.data() ?? {};
      _role = (data['role'] ?? '').toString();
      _photoCtl.text = (data['photoURL'] ?? u?.photoURL ?? '') as String;

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _error = null;
    });
    try {
      await _svc.updateDisplayName(_nameCtl.text);
      await _svc.updatePhotoUrl(_photoCtl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin tài khoản.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_svc.canChangePassword) {
      setState(
        () => _error =
            'Tài khoản không hỗ trợ đổi mật khẩu (đăng nhập bằng Google/SSO).',
      );
      return;
    }
    if (_newPwdCtl.text.trim().length < 6) {
      setState(() => _error = 'Mật khẩu mới tối thiểu 6 ký tự.');
      return;
    }
    if (_newPwdCtl.text.trim() != _newPwd2Ctl.text.trim()) {
      setState(() => _error = 'Xác nhận mật khẩu mới không khớp.');
      return;
    }

    setState(() {
      _changingPwd = true;
      _error = null;
    });
    try {
      await _svc.changePassword(
        currentPassword: _curPwdCtl.text.trim(),
        newPassword: _newPwdCtl.text.trim(),
      );
      _curPwdCtl.clear();
      _newPwdCtl.clear();
      _newPwd2Ctl.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _changingPwd = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _photoCtl.dispose();
    _curPwdCtl.dispose();
    _newPwdCtl.dispose();
    _newPwd2Ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin tài khoản',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            readOnly: true,
                            initialValue: _email ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtl,
                            decoration: const InputDecoration(
                              labelText: 'Họ tên hiển thị',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _photoCtl,
                            decoration: const InputDecoration(
                              labelText: 'Ảnh đại diện (photoURL)',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if ((_role ?? '').isNotEmpty)
                            Text(
                              'Vai trò: ${_role!}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _savingProfile ? null : _saveProfile,
                              icon: _savingProfile
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Lưu thông tin'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đổi mật khẩu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (AccountService().canChangePassword) ...[
                            TextFormField(
                              controller: _curPwdCtl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu hiện tại',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPwdCtl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu mới',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPwd2Ctl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Xác nhận mật khẩu mới',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _changingPwd
                                    ? null
                                    : _changePassword,
                                icon: _changingPwd
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.password),
                                label: const Text('Đổi mật khẩu'),
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Tài khoản đăng nhập bằng Google/SSO nên không thể đổi mật khẩu tại đây.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
