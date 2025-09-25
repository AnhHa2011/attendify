import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/providers/auth_provider.dart';
import '../../../common/presentation/layouts/role_layout.dart';
import 'admin_dashboard.dart';
import 'user_management/user_management_page.dart';
import 'course_management/course_management_page.dart';
import 'class_management/class_management_page.dart';
import 'admin_profile.dart';
import '../../presentation/pages/leave_request_management_page.dart';

class AdminLayout extends StatelessWidget {
  const AdminLayout({super.key});

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
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Người dùng',
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
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
        icon: Icons.school_outlined,
        activeIcon: Icons.school_rounded,
        label: 'Lớp học',
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
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
      AdminDashboard(),
      UserManagementPage(),
      CourseManagementPage(),
      ClassManagementPage(),
      LeaveRequestManagementPage(),
      AdminProfile(),
    ];

    return RoleLayout(
      title: 'Bảng điều khiển (Admin)',
      items: items,
      pages: pages,
      onLogout: (ctx) async => ctx.read<AuthProvider>().logout(),
    );
  }
}
