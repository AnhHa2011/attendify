// lib/features/admin/presentation/pages/admin_menu_new.dart
import 'package:attendify/features/admin/presentation/pages/leave_request_management_page.dart';
import 'package:attendify/features/common/presentation/widgets/profile_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/navigation_provider.dart';
import '../../../common/presentation/pages/dashboard_page.dart';
import '../../../common/presentation/widgets/drawer_scaffold.dart';
import '../../../common/widgets/role_drawer_scaffold.dart';
import 'user_management/user_management_page.dart';
import 'course_management/course_management_page.dart';
import 'class_management/class_management_page.dart';

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    final destinations = <DrawerDestination>[
      const DrawerDestination(
        icon: Icons.dashboard_outlined,
        label: 'Tổng quan',
      ),
      const DrawerDestination(
        icon: Icons.manage_accounts,
        label: 'Quản lý tài khoản',
      ),
      const DrawerDestination(
        icon: Icons.menu_book_outlined,
        label: 'Quản lý môn học',
      ),
      const DrawerDestination(
        icon: Icons.school_outlined,
        label: 'Quản lý lớp học',
      ),
      const DrawerDestination(
        icon: Icons.person_outline,
        label: 'Thông tin cá nhân',
      ),
    ];

    final pages = <Widget>[
      const DashboardPage(),
      const UserManagementPage(),
      const CourseManagementPage(),
      const ClassManagementPage(),
      const LeaveRequestManagementPage(),
      const ProfileWidget(),
    ];

    return DrawerScaffold(
      title: 'Admin Panel',
      destinations: destinations,
      pages: pages,
      currentIndex: navProvider.currentIndex,
      onDestinationSelected: (index) {
        navProvider.setCurrentIndex(index);
      },
      drawerHeader: const DrawerHeader(
        child:
            SizedBox(), // Provide an empty widget or your custom header widget here
      ),
    );
  }
}
