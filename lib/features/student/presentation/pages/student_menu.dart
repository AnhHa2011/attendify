// lib/presentation/pages/student/student_menu_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../common/data/models/user_model.dart';
import '../../../common/widgets/role_drawer_scaffold.dart';
import '../../../leave/presentation/pages/leave_request_page.dart';
import '../../../schedule/presentation/pages/schedule_page.dart';
import 'qr_scanner_page.dart';
import 'join_class_scanner_page.dart';

// NEW: dùng LocalNotificationService để xin quyền & hiện thông báo
import '../../../notifications/local_notification_service.dart';

class StudentMenuPage extends StatefulWidget {
  const StudentMenuPage({super.key});

  @override
  State<StudentMenuPage> createState() => _StudentMenuPageState();
}

class _StudentMenuPageState extends State<StudentMenuPage> {
  bool _askedPermission = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Xin quyền 1 lần khi vào menu SV
    if (!_askedPermission) {
      _askedPermission = true;
      // Gọi xin quyền không chặn UI
      LocalNotificationService.requestPermissionsIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 7 mục như trước
    final dest = <DrawerDestination>[
      DrawerDestination(
        icon: Icons.calendar_month_outlined,
        label: 'Thời khoá biểu',
      ),
      DrawerDestination(
        icon: Icons.qr_code_scanner_outlined,
        label: 'Điểm danh',
      ),
      DrawerDestination(icon: Icons.group_add_outlined, label: 'Tham gia lớp'),
      DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
      DrawerDestination(icon: Icons.history_outlined, label: 'Lịch sử'),
      DrawerDestination(icon: Icons.person_outline, label: 'Tài khoản'),
      DrawerDestination(icon: Icons.notifications_outlined, label: 'Thông báo'),
    ];

    final pages = <Widget>[
      _ScheduleListPage(),
      QrScannerPage(),
      _JoinClassPage(),
      LeaveRequestPage(),
      const Center(child: Text('Lịch sử & tỷ lệ chuyên cần')),
      const Center(child: Text('Hồ sơ cá nhân')),
      // NEW: Trang thông báo thật thay vì placeholder
      const _NotificationsPage(),
    ];

    return RoleDrawerScaffold(
      title: 'Sinh viên',
      destinations: dest,
      pages: pages,
      drawerHeader: const _Header(role: 'Sinh viên'),
    );
  }
}

// Class List Page sử dụng logic phân vai trò
class _ScheduleListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;
    return SchedulePage(
      currentUid: currentUser!.uid,
      // FIX: là giảng viên khi role == UserRole.lecture
      isLecturer: auth.role == UserRole.lecture,
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

/// NEW: Trang thông báo – xin quyền, test hiện thông báo, bật/tắt nhắc trước 1 giờ
class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  bool _sound = true;
  bool _vibrate = true;
  bool _hourBefore = true;

  @override
  void initState() {
    super.initState();
    // đảm bảo đã xin quyền (idempotent)
    LocalNotificationService.requestPermissionsIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Thông báo', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Bật nhắc nhở trước buổi học 1 giờ. Bạn có thể thử gửi thông báo ngay để kiểm tra.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Nhắc trước 1 giờ'),
            value: _hourBefore,
            onChanged: (v) => setState(() => _hourBefore = v),
          ),
          SwitchListTile(
            title: const Text('Âm thanh'),
            value: _sound,
            onChanged: (v) => setState(() => _sound = v),
          ),
          SwitchListTile(
            title: const Text('Rung'),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
          ),

          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Gửi thông báo thử'),
            onPressed: () async {
              await LocalNotificationService.instance.showNow(
                title: 'Attendify',
                body: 'Thông báo thử hoạt động!',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi thông báo thử')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Xin quyền thông báo (Android 13+)'),
            onPressed: () async {
              await LocalNotificationService.requestPermissionsIfNeeded();
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Lưu ý: Bạn cần mở app ít nhất một lần để thiết lập thông báo cục bộ. '
            'Nếu dùng chức năng nhắc trước 1 giờ, app sẽ lên lịch thông báo dựa trên giờ bắt đầu buổi học.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
