//  Dashboard Page
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/admin/data/services/admin_service.dart';
import '../../../features/admin/presentation/pages/admin_ui_components.dart';
import '../../data/models/course_model.dart';
import '../../data/models/user_model.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dashboard_rounded,
                      size: 28,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chào mừng trở lại!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Admin Dashboard',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<UserModel>>(
                stream: context.read<AdminService>().getAllLecturersStream(),
                builder: (context, lecturerSnapshot) {
                  return StreamBuilder<List<UserModel>>(
                    stream: context.read<AdminService>().getAllStudentsStream(),
                    builder: (context, studentSnapshot) {
                      return StreamBuilder<List<CourseModel>>(
                        stream: context
                            .read<AdminService>()
                            .getAllCoursesStream(),
                        builder: (context, classSnapshot) {
                          final lecturers = lecturerSnapshot.data ?? [];
                          final students = studentSnapshot.data ?? [];
                          final classes = classSnapshot.data ?? [];

                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.4,
                            children: [
                              StatCard(
                                title: 'Giảng viên',
                                value: '${lecturers.length}',
                                icon: Icons.person_outline,
                                color: Colors.blue,
                              ),
                              StatCard(
                                title: 'Sinh viên',
                                value: '${students.length}',
                                icon: Icons.groups,
                                color: Colors.green,
                              ),
                              StatCard(
                                title: 'Lớp học',
                                value: '${classes.length}',
                                icon: Icons.school,
                                color: Colors.orange,
                              ),
                              StatCard(
                                title: 'Môn học',
                                value: 'N/A',
                                icon: Icons.menu_book,
                                color: Colors.purple,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
