// lib/features/lecturer/presentation/pages/lecturer_layout.dart
import 'package:attendify/features/lecturer/lecturer_module.dart';
import 'package:attendify/features/lecturer/presentation/pages/course_page.dart';
import 'package:attendify/features/lecturer/presentation/pages/leave_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../common/presentation/layouts/role_layout.dart';

class LecturerLayout extends StatelessWidget {
  const LecturerLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <RoleNavigationItem>[
      RoleNavigationItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Trang chủ',
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: 'Môn học',
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
    ];

    final pages = const [
      LecturerDashboard(),
      CoursePage(),
      LeaveRequestsPage(),
      ProfilePage(),
    ];

    return RoleLayout(
      title: 'Bảng điều khiển (Giảng viên)',
      items: items,
      pages: pages,
      onLogout: (ctx) async => ctx.read<AuthProvider>().logout(),
    );
  }
}
