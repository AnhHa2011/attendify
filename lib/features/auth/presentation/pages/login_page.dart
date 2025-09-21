import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/providers/auth_provider.dart';
import '../../../common/widgets/role_picker_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();

    try {
      await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      // GoRouter sẽ tự redirect theo role trong app.dart
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.loginWithGoogleAndPickRole(
        () => showRolePickerDialog(context),
      );
      if (!mounted) return;
      // Router sẽ tự redirect theo role
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In lỗi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingGlobal = context.watch<AuthProvider>().isLoading;
    final isBusy = _submitting || isLoadingGlobal;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        final email = v.trim();
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      autofillHints: const [AutofillHints.password],
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!isBusy) {
                          _signInEmail();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isBusy ? null : _signInEmail,
                      child: isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isBusy ? null : () => context.push('/reset'),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                    // const Divider(height: 32),
                    // OutlinedButton.icon(
                    //   onPressed: isBusy ? null : _signInGoogle,
                    //   icon: Image.asset(
                    //     'assets/icons/google_logo.png',
                    //     width: 24,
                    //     height: 24,
                    //     errorBuilder: (_, __, ___) =>
                    //         const Icon(Icons.g_mobiledata),
                    //   ),
                    //   label: const Text('Đăng nhập/đăng ký với Google'),
                    // ),
                    // const SizedBox(height: 12),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     const Text('Chưa có tài khoản?'),
                    //     TextButton(
                    //       onPressed: isBusy
                    //           ? null
                    //           : () => context.go('/register'),
                    //       child: const Text('Đăng ký'),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
