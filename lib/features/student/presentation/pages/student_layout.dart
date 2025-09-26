// lib/features/Student/presentation/pages/Student_layout.dart

import 'package:attendify/app_imports.dart' hide AuthProvider;
import 'package:attendify/features/schedule/presentation/pages/schedule_page.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../classes/data/services/class_service.dart';
import '../../student_module.dart';
import '../schedule/student_schedule_page.dart';
import 'join_class_scanner_page.dart';
import 'qr_scanner_page.dart';

class StudentLayout extends StatelessWidget {
  const StudentLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <RoleNavigationItem>[
      RoleNavigationItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Thời khoá biểu',
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.qr_code,
        activeIcon: Icons.menu_book_rounded,
        label: 'Điểm danh',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.class_outlined,
        activeIcon: Icons.class_outlined,
        label: 'Tham gia lớp học',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.class_outlined,
        activeIcon: Icons.class_outlined,
        label: 'Lớp học',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.history,
        activeIcon: Icons.class_outlined,
        label: 'Lịch sử',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_available_rounded,
        label: 'Nghỉ phép',
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Cá nhân',
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
      ),
      // RoleNavigationItem(
      //   icon: Icons.person_outline_rounded,
      //   activeIcon: Icons.person_rounded,
      //   label: 'Thông báo',
      //   gradient: LinearGradient(
      //     colors: [Colors.indigo.shade400, Colors.indigo.shade600],
      //   ),
      // ),
    ];

    final pages = const [
      StudentSchedulePage(),
      QrScannerPage(),
      _JoinClassPage(),
      StudentClassListPage(),
      StudentAttendanceHistoryPage(),
      LeaveRequestStatusPage(),
      _StudentProfilePage(),
      // NotificationSettingsPage(),
    ];

    return RoleLayout(
      title: 'Bảng điều khiển (Sinh viên)',
      items: items,
      pages: pages,
      onLogout: (ctx) async => ctx.read<AuthProvider>().logout(),
    );
  }
}

// WIDGET CHO CHỨC NĂNG THAM GIA LỚP - Tối ưu cho mobile
class _JoinClassPage extends StatefulWidget {
  const _JoinClassPage();

  @override
  State<_JoinClassPage> createState() => _JoinClassPageState();
}

class _JoinClassPageState extends State<_JoinClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitJoinClass({required String joinCode}) async {
    setState(() => _isLoading = true);
    try {
      final classService = context.read<ClassService>();
      final auth = context.read<AuthProvider>();
      final user = auth.user!;

      await classService.enrollStudent(
        joinCode: joinCode,
        studentUid: user.uid,
        studentName: user.displayName ?? 'N/A',
        studentEmail: user.email ?? 'N/A',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tham gia lớp học thành công!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _codeController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanAndJoin() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const JoinClassScannerPage()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final padding = EdgeInsets.symmetric(
      horizontal: screenSize.width < 360 ? 16.0 : 24.0,
      vertical: 16.0,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenSize.height - 100,
            maxWidth: 400,
          ),
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header với icon - Responsive
                  Container(
                    padding: EdgeInsets.all(screenSize.width < 360 ? 16 : 20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            screenSize.width < 360 ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.group_add,
                            color: colorScheme.primary,
                            size: screenSize.width < 360 ? 36 : 48,
                          ),
                        ),
                        SizedBox(height: screenSize.width < 360 ? 12 : 16),
                        Text(
                          'Tham gia lớp học',
                          style:
                              (screenSize.width < 360
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập mã tham gia hoặc quét QR code',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenSize.width < 360 ? 24 : 32),

                  // Text Field - Responsive
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Mã tham gia',
                      hintText: 'Ví dụ: ABC123',
                      prefixIcon: Icon(
                        Icons.tag,
                        size: screenSize.width < 360 ? 20 : 24,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState!.validate()) {
                        _submitJoinClass(joinCode: _codeController.text);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mã tham gia';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: screenSize.width < 360 ? 16 : 20),

                  // Join Button - Responsive
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _submitJoinClass(joinCode: _codeController.text);
                            }
                          },
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : Icon(
                            Icons.login,
                            size: screenSize.width < 360 ? 18 : 20,
                          ),
                    label: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Tham gia'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                      textStyle: TextStyle(
                        fontSize: screenSize.width < 360 ? 14 : 16,
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.width < 360 ? 12 : 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'HOẶC',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: screenSize.width < 360 ? 11 : 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  SizedBox(height: screenSize.width < 360 ? 12 : 16),

                  // QR Scan Button - Responsive
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _scanAndJoin,
                    icon: Icon(
                      Icons.qr_code_scanner,
                      size: screenSize.width < 360 ? 18 : 20,
                    ),
                    label: const Text('Quét mã QR'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.width < 360 ? 12 : 16,
                      ),
                      textStyle: TextStyle(
                        fontSize: screenSize.width < 360 ? 14 : 16,
                      ),
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

// Header component tối ưu cho mobile
class _Header extends StatelessWidget {
  const _Header({required this.role, required this.isSmallScreen});
  final String role;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return UserAccountsDrawerHeader(
      accountName: Text(
        user?.displayName ?? 'Attendify',
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      accountEmail: Text(
        role,
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      currentAccountPicture: CircleAvatar(
        radius: isSmallScreen ? 25 : 30,
        backgroundColor: color.primaryContainer,
        child: user?.photoURL != null
            ? ClipOval(
                child: Image.network(
                  user!.photoURL!,
                  width: isSmallScreen ? 50 : 60,
                  height: isSmallScreen ? 50 : 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.person,
                    color: color.onPrimaryContainer,
                    size: isSmallScreen ? 24 : 30,
                  ),
                ),
              )
            : Icon(
                Icons.person,
                color: color.onPrimaryContainer,
                size: isSmallScreen ? 24 : 30,
              ),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.primary, color.primaryContainer],
        ),
      ),
    );
  }
}

// Simple profile page placeholder
class _StudentProfilePage extends StatelessWidget {
  const _StudentProfilePage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: user?.photoURL != null
                        ? ClipOval(
                            child: Image.network(
                              user!.photoURL!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Sinh viên',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Chỉnh sửa thông tin'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đang phát triển'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đang phát triển'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Đăng xuất'),
                          content: const Text(
                            'Bạn có chắc chắn muốn đăng xuất?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
