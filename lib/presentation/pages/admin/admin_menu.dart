import 'package:flutter/material.dart';
import '../../widgets/role_drawer_scaffold.dart';
import 'admin_class_list_page.dart';

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dest = <DrawerDestination>[
      const DrawerDestination(icon: Icons.home_outlined, label: 'Tổng quan'),
      const DrawerDestination(icon: Icons.groups_outlined, label: 'Lớp học'),
      const DrawerDestination(
        icon: Icons.event_note_outlined,
        label: 'Buổi học',
      ),
      const DrawerDestination(
        icon: Icons.qr_code_2_outlined,
        label: 'Điểm danh',
      ),
      const DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
      const DrawerDestination(icon: Icons.bar_chart_outlined, label: 'Báo cáo'),
      const DrawerDestination(icon: Icons.person_outline, label: 'Tài khoản'),
    ];

    final pages = <Widget>[
      const _Stub('Tổng quan (dashboard)'),
      const AdminClassListPage(),
      const _Stub('Quản lý buổi học'),
      const _Stub('Điểm danh & chuyên cần'),
      const _Stub('Duyệt yêu cầu xin nghỉ'),
      const _Stub('Báo cáo & xuất dữ liệu'),
      const _Stub('Thông tin cá nhân'),
    ];

    return RoleDrawerScaffold(
      title: 'Admin',
      destinations: dest,
      pages: pages,
      drawerHeader: const _Header(role: 'Admin'),
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
