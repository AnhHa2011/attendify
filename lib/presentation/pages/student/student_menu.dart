import 'package:flutter/material.dart';
import '../../widgets/role_drawer_scaffold.dart';

class StudentMenuPage extends StatelessWidget {
  const StudentMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
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

    final pages = <Widget>[
      const _Stub('Thời khóa biểu'),
      const _Stub('Quét QR điểm danh'),
      const _Stub('Nhập mã/Quét QR tham gia lớp'),
      const _Stub('Gửi yêu cầu xin nghỉ'),
      const _Stub('Lịch sử & tỷ lệ chuyên cần'),
      const _Stub('Hồ sơ cá nhân'),
      const _Stub('Thông báo'),
    ];

    return RoleDrawerScaffold(
      title: 'Sinh viên',
      destinations: dest,
      pages: pages,
      drawerHeader: const _Header(role: 'Sinh viên'),
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, textAlign: TextAlign.center));
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
