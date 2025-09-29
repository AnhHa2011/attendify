// lib/features/auth/presentation/pages/login_page.dart (ĐÃ SỬA)

// =================== THAY THẾ TOÀN BỘ PHẦN IMPORT BẰNG ĐOẠN NÀY ===================

import 'package:attendify/features/auth/presentation/pages/reset_password_page.dart';
import 'package:go_router/go_router.dart';

// Import file tổng hợp. Nó đã chứa Material, Provider, FirebaseAuthException, và AuthProvider của bạn.
import '../../../../app_imports.dart';
import '../../../../core/presentation/widgets/role_picker_dialog.dart';

// Import các widget/dialog cục bộ nếu cần.

// =================================================================================

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
    // Provider và AuthProvider đã có sẵn từ app_imports.dart
    final auth = context.read<AuthProvider>();

    try {
      await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      // GoRouter sẽ tự redirect khi đăng nhập thành công
    } on FirebaseAuthException catch (e) {
      // FirebaseAuthException đã có sẵn từ app_imports.dart
      if (!mounted) return;

      String errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';

      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = 'Email hoặc mật khẩu không chính xác.';
          break;
        case 'user-disabled':
          errorMessage = 'Tài khoản của bạn đã bị vô hiệu hoá.';
          break;
        case 'invalid-email':
          errorMessage = 'Địa chỉ email không hợp lệ.';
          break;
        case 'too-many-requests':
          errorMessage = 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';
          break;
        default:
          print('Firebase Auth Error: ${e.code} - ${e.message}');
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập thất bại: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
    // context.watch hoạt động vì Provider được export từ app_imports.dart
    final isLoadingGlobal = context.watch<AuthProvider>().isLoading;
    final isBusy = _submitting || isLoadingGlobal;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đăng nhập'),
      ),
      // ... (TOÀN BỘ PHẦN GIAO DIỆN CÒN LẠI GIỮ NGUYÊN)
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(8),
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
                        onPressed: isBusy
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ResetPasswordPage(),
                                  ),
                                );
                              },
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
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
