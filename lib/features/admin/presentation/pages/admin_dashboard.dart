// lib/features/admin/presentation/pages/admin_dashboard.dart
import 'package:attendify/features/admin/presentation/pages/course_management/course_management_page.dart';
import 'package:attendify/features/admin/presentation/pages/user_management/user_management_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../core/data/models/course_model.dart';
import '../../../../core/data/models/user_model.dart';
import '../../../../core/presentation/widgets/large_screen_content.dart';
import '../../../../core/presentation/widgets/large_screen_quick_action.dart';
import '../../../../core/presentation/widgets/small_screen_content.dart';
import '../../../../core/presentation/widgets/small_screen_quick_action.dart';
import '../../data/services/admin_service.dart';
import 'class_management/class_form_page.dart';
import 'class_management/class_management_page.dart';
import 'course_management/course_form_page.dart';
import 'course_management/course_import_page.dart';
import 'user_management/user_form_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fabController;
  late AnimationController _headerController;
  late Animation<double> _fabAnimation;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutQuart),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - _headerAnimation.value)),
                    child: Opacity(
                      opacity: _headerAnimation.value,
                      child: _buildGradientHeader(context, auth.user),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildUsersTab(),
            _buildClassesTab(),
            _buildCoursesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context, user) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.8),
            theme.colorScheme.secondary.withOpacity(0.6),
            theme.colorScheme.tertiary.withOpacity(0.4),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'admin-avatar',
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, ${user?.displayName?.split(' ').last ?? 'Admin'}! 👋',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quản trị viên hệ thống',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                        'vi_VN',
                      ).format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          // const SizedBox(height: 24),
          // _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<List<UserModel>>(
      stream: context.read<AdminService>().getAllLecturersStream(),
      builder: (context, lecturerSnapshot) {
        return StreamBuilder<List<UserModel>>(
          stream: context.read<AdminService>().getAllStudentsStream(),
          builder: (context, studentSnapshot) {
            return StreamBuilder<List<CourseModel>>(
              stream: context.read<AdminService>().getAllCoursesStream(),
              builder: (context, courseSnapshot) {
                final lecturers = lecturerSnapshot.data ?? [];
                final students = studentSnapshot.data ?? [];
                final courses = courseSnapshot.data ?? [];

                // Responsive layout
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thống kê tổng quan',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Tổng giảng viên',
                                value: lecturers.length.toString(),
                                icon: Icons.person_outline_rounded,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Tổng sinh viên',
                                value: students.length.toString(),
                                icon: Icons.people,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Môn học',
                                value: courses.length.toString(),
                                icon: Icons.school_rounded,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Hoạt động',
                                value: (courses.length * 0.85)
                                    .round()
                                    .toString(),
                                icon: Icons.schedule,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thao tác nhanh',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard(
                  title: 'Tạo tài khoản',
                  icon: Icons.person_add_rounded,
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserFormPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  title: 'Tạo môn học',
                  icon: Icons.menu_book_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CourseFormPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  title: 'Tạo lớp học',
                  icon: Icons.school_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ClassFormPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  title: 'Import môn học',
                  icon: Icons.upload_file_rounded,
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CourseImportPage(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ← quan trọng
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoạt động gần đây',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double animation, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * animation),
                    child: Opacity(
                      opacity: animation,
                      child: Icon(
                        Icons.timeline_rounded,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return const UserManagementPage();
  }

  Widget _buildClassesTab() {
    return const ClassManagementPage();
  }

  Widget _buildCoursesTab() {
    return const CourseManagementPage();
  }
}

void _navigateToUserForm(BuildContext context) {}

void _navigateToCourseForm(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const CourseFormPage()),
  );
}

void _navigateToClassForm(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ClassFormPage()),
  );
}

void _navigateToCourseImport(BuildContext context) {
  ;
}
