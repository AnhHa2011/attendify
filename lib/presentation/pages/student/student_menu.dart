// lib/presentation/pages/student/student_menu_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import các file cần thiết
import '../../../app/providers/auth_provider.dart';
import '../../../services/firebase/classes/class_service.dart';
import '../../widgets/role_drawer_scaffold.dart';
import 'qr_scanner_page.dart';
import 'join_class_scanner_page.dart';

class StudentMenuPage extends StatelessWidget {
  const StudentMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    // SỬA LỖI: ĐẢM BẢO DANH SÁCH NÀY CÓ ĐỦ 7 MỤC
    final dest = <DrawerDestination>[
      const DrawerDestination(icon: Icons.view_timeline_outlined, label: 'TKB'),
      const DrawerDestination(
        icon: Icons.qr_code_scanner_outlined,
        label: 'Điểm danh',
      ),
      const DrawerDestination(
        icon: Icons.group_add_outlined,
        label: 'Tham gia lớp',
      ),
      const DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
      const DrawerDestination(icon: Icons.history_outlined, label: 'Lịch sử'),
      const DrawerDestination(icon: Icons.person_outline, label: 'Tài khoản'),
      const DrawerDestination(
        icon: Icons.notifications_outlined,
        label: 'Thông báo',
      ),
    ];

    // DANH SÁCH NÀY ĐÃ CÓ 7 TRANG TƯƠNG ỨNG
    final pages = <Widget>[
      const Center(child: Text('Thời khóa biểu')),
      const QrScannerPage(),
      const _JoinClassPage(),
      const Center(child: Text('Gửi yêu cầu xin nghỉ')),
      const Center(child: Text('Lịch sử & tỷ lệ chuyên cần')),
      const Center(child: Text('Hồ sơ cá nhân')),
      const Center(child: Text('Thông báo')),
    ];

    return RoleDrawerScaffold(
      title: 'Sinh viên',
      destinations: dest,
      pages: pages,
      drawerHeader: const _Header(role: 'Sinh viên'),
    );
  }
}

// WIDGET CHO CHỨC NĂNG THAM GIA LỚP
class _JoinClassPage extends StatefulWidget {
  const _JoinClassPage();

  @override
  State<_JoinClassPage> createState() => _JoinClassPageState();
}

class _JoinClassPageState extends State<_JoinClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  // === THAY ĐỔI 1: TÁCH LOGIC SUBMIT RA ĐỂ TÁI SỬ DỤNG ===
  // Hàm này giờ nhận mã tham gia làm tham số
  Future<void> _submitJoinClass({required String joinCode}) async {
    setState(() => _isLoading = true);

    try {
      final classService = context.read<ClassService>();
      final auth = context.read<AuthProvider>();
      final user = auth.user!;

      await classService.enrollStudent(
        joinCode: joinCode, // Sử dụng tham số
        studentUid: user.uid,
        studentName: user.displayName ?? 'N/A',
        studentEmail: user.email ?? 'N/A',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tham gia lớp học thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _codeController.clear();
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

  // === THÊM MỚI 2: HÀM ĐỂ MỞ CAMERA VÀ XỬ LÝ KẾT QUẢ ===
  Future<void> _scanAndJoin() async {
    // Đẩy trang scanner lên và đợi kết quả trả về (await)
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const JoinClassScannerPage()),
    );

    // Nếu người dùng quay lại mà không quét, scannedCode sẽ là null
    if (scannedCode != null && scannedCode.isNotEmpty) {
      // Tự động điền mã vào ô text và gọi hàm tham gia
      _codeController.text = scannedCode;
      await _submitJoinClass(joinCode: scannedCode);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tham gia lớp học',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Nhập mã tham gia',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mã tham gia';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    // Gọi hàm submit với mã từ controller
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _submitJoinClass(joinCode: _codeController.text);
                            }
                          },
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.login),
                    label: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tham gia'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  // === THÊM MỚI 3: NÚT QUÉT MÃ QR ===
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _scanAndJoin,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét mã QR để tham gia'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return UserAccountsDrawerHeader(
      accountName: const Text('Attendify'),
      accountEmail: Text(role),
      currentAccountPicture: CircleAvatar(
        backgroundColor: color.primaryContainer,
        child: Icon(Icons.person, color: color.onPrimaryContainer),
      ),
    );
  }
}
