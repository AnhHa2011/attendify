import 'package:flutter/material.dart';
import '../../widgets/role_drawer_scaffold.dart';
import '../classes/class_list_page.dart';
import 'lecturer_class_list_page.dart';

class LectureMenuPage extends StatelessWidget {
  const LectureMenuPage({super.key});

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
        icon: Icons.qr_code_outlined,
        label: 'QR điểm danh',
      ),
      const DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
      const DrawerDestination(icon: Icons.bar_chart_outlined, label: 'Báo cáo'),
      const DrawerDestination(icon: Icons.person_outline, label: 'Tài khoản'),
    ];

    final pages = <Widget>[
      const _Stub('Tổng quan giảng viên'),
      const LecturerClassListPage(),
      const _Stub('Quản lý buổi học'),
      const _Stub('Sinh QR động để điểm danh'),
      const _Stub('Duyệt yêu cầu xin nghỉ'),
      const _Stub('Báo cáo chuyên cần'),
      const _Stub('Thông tin cá nhân'),
    ];

    return RoleDrawerScaffold(
      title: 'Giảng viên',
      destinations: dest,
      pages: pages,
      drawerHeader: const _Header(role: 'Giảng viên'),
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
