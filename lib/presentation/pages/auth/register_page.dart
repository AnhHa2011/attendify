import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/providers/auth_provider.dart' as attendify;
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../utils/auth_error.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _loadingGoogle = false;
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _onRegisterEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<attendify.AuthProvider>().register(
        email: _email.text.trim(),
        password: _pass.text,
        name: _name.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorText(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRegisterWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final authSvc = context.read<FirebaseAuthService>();
      final cred = await authSvc.signInWithGoogle();
      final user = cred.user;
      if (user == null) throw Exception('Google sign-in failed');

      final users = FirebaseFirestore.instance.collection(
        FirestoreCollections.users,
      );
      final docRef = users.doc(user.uid);
      final snap = await docRef.get();

      if (!snap.exists) {
        // Lần đầu — hỏi chọn role
        final selected = await _pickRole(context);
        if (selected == null) {
          // user hủy → sign out để tránh trạng thái lơ lửng
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn đã hủy chọn vai trò')),
          );
          return;
        }

        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          role: selected,
          createdAt: DateTime.now(),
        );
        await docRef.set(newUser.toMap(), SetOptions(merge: true));
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorText(e))));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<UserRole?> _pickRole(BuildContext context) async {
    UserRole temp = UserRole.student;
    return showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final color = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            top: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn vai trò',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color.primary,
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (c, setStateSB) {
                  return Column(
                    children: [
                      RadioListTile<UserRole>(
                        value: UserRole.admin,
                        groupValue: temp,
                        title: const Text('Admin'),
                        onChanged: (v) => setStateSB(() => temp = v ?? temp),
                      ),
                      RadioListTile<UserRole>(
                        value: UserRole.lecture,
                        groupValue: temp,
                        title: const Text('Lecture'),
                        onChanged: (v) => setStateSB(() => temp = v ?? temp),
                      ),
                      RadioListTile<UserRole>(
                        value: UserRole.student,
                        groupValue: temp,
                        title: const Text('Student'),
                        onChanged: (v) => setStateSB(() => temp = v ?? temp),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Hủy'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Xác nhận'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: color.primaryContainer.withOpacity(.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 80,
                      color: color.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: color.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Điền thông tin bên dưới để bắt đầu',
                    style: TextStyle(color: color.onSurfaceVariant),
                  ),

                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _LabeledField(
                          controller: _name,
                          label: 'Họ tên',
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập họ tên'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _LabeledField(
                          controller: _email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập email'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _LabeledField(
                          controller: _pass,
                          label: 'Mật khẩu',
                          obscureText: _obscure,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Vui lòng nhập mật khẩu';
                            if (v.length < 6)
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<UserRole>(
                          value: _role,
                          decoration: InputDecoration(
                            labelText: 'Vai trò',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: UserRole.admin,
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.lecture,
                              child: Text('Lecture'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.student,
                              child: Text('Student'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _role = v ?? _role),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _onRegisterEmail,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Đăng ký', style: TextStyle(fontSize: 16)),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: color.outlineVariant,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC',
                          style: TextStyle(
                            color: color.onSurfaceVariant,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: color.outlineVariant,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingGoogle ? null : _onRegisterWithGoogle,
                      icon: _loadingGoogle
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Đăng ký với Google',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        'Đã có tài khoản?',
                        style: TextStyle(color: color.onSurfaceVariant),
                      ),
                      InkWell(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Đăng nhập',
                          style: TextStyle(
                            color: color.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: color.onSurfaceVariant),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
