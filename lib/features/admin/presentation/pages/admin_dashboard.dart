// lib/features/admin/presentation/pages/admin_dashboard.dart
import 'package:attendify/features/admin/presentation/pages/class_management/class_form_page.dart';
import 'package:attendify/features/admin/presentation/pages/class_management/class_management_page.dart';
import 'package:attendify/features/admin/presentation/pages/course_management/course_form_page.dart';
import 'package:attendify/features/admin/presentation/pages/course_management/course_management_page.dart';
import 'package:attendify/features/admin/presentation/pages/user_management/user_management_page.dart';
import 'package:attendify/features/classes/presentation/pages/class_list_page.dart';
import 'package:attendify/features/common/widgets/large_screen_quick_action.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../app/providers/navigation_provider.dart';
import '../../../common/data/models/user_model.dart';
import '../../../common/data/models/class_model.dart';
import '../../../common/widgets/large_screen_content.dart';
import '../../../common/widgets/small_screen_content.dart';
import '../../../common/widgets/small_screen_quick_action.dart';
import '../../data/services/admin_service.dart';
import 'admin_ui_components.dart';
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
            _buildAcademicTab(),
            _buildAnalyticsTab(),
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
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
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
            return StreamBuilder<List<ClassModel>>(
              stream: context.read<AdminService>().getAllClassesStream(),
              builder: (context, classSnapshot) {
                final lecturers = lecturerSnapshot.data ?? [];
                final students = studentSnapshot.data ?? [];
                final classes = classSnapshot.data ?? [];

                // Responsive layout
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Tính toán responsive dựa trên chiều rộng màn hình
                    final screenWidth = MediaQuery.of(context).size.width;
                    double aspectRatio;
                    if (screenWidth < 350) {
                      aspectRatio = 3.6; // Nexus 4 và các màn hình nhỏ hơn
                    } else if (screenWidth < 400) {
                      aspectRatio = 2.2; // Màn hình nhỏ
                    } else if (screenWidth < 500) {
                      aspectRatio = 1.8; // Màn hình trung bình
                    } else {
                      aspectRatio = 1.6; // Màn hình lớn
                    }
                    final isSmallScreen = screenWidth < 400;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng quan',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: aspectRatio,
                          children: [
                            _buildGlassCard(
                              title: 'Giảng viên',
                              value: '${lecturers.length}',
                              icon: Icons.person_outline_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              delay: const Duration(milliseconds: 100),
                              isSmallScreen: isSmallScreen,
                            ),
                            _buildGlassCard(
                              title: 'Sinh viên',
                              value: '${students.length}',
                              icon: Icons.groups_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                              ),
                              delay: const Duration(milliseconds: 200),
                              isSmallScreen: isSmallScreen,
                            ),
                            _buildGlassCard(
                              title: 'Lớp học',
                              value: '${classes.length}',
                              icon: Icons.school_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                              delay: const Duration(milliseconds: 300),
                              isSmallScreen: isSmallScreen,
                            ),
                            _buildGlassCard(
                              title: 'Hoạt động',
                              value: '${(classes.length * 0.85).round()}%',
                              icon: Icons.trending_up_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                ],
                              ),
                              delay: const Duration(milliseconds: 400),
                              isSmallScreen: isSmallScreen,
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

  Widget _buildActionCard({
    required String title,
    required String subTitle,
    required IconData icon,
    required LinearGradient gradient,
    required Duration delay,
    required bool isSmallScreen,
    VoidCallback? onTap,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double animation, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation)),
          child: Transform.scale(
            scale: 0.8 + (0.2 * animation),
            child: Opacity(
              opacity: animation,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  height: isSmallScreen
                      ? 50
                      : null, // ✅ Chiều cao cố định cho small screen
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(
                      isSmallScreen ? 12 : 20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: isSmallScreen ? 8 : 15,
                        offset: Offset(0, isSmallScreen ? 4 : 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 12 : 20,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    child: isSmallScreen
                        ? SmallScreenQuickAction(
                            icon: icon,
                            title: title,
                            subTitle: subTitle,
                          )
                        : LargeScreenQuickAction(
                            icon: icon,
                            subTitle: subTitle,
                            title: title,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassCard({
    required String title,
    required String value,
    required IconData icon,
    required LinearGradient gradient,
    required Duration delay,
    required bool isSmallScreen,
    VoidCallback? onTap,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double animation, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation)),
          child: Transform.scale(
            scale: 0.8 + (0.2 * animation),
            child: Opacity(
              opacity: animation,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: isSmallScreen
                      ? 50
                      : null, // ✅ Chiều cao cố định cho small screen
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(
                      isSmallScreen ? 12 : 20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: isSmallScreen ? 8 : 15,
                        offset: Offset(0, isSmallScreen ? 4 : 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 12 : 20,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    child: isSmallScreen
                        ? SmallScreenContent(
                            icon: icon,
                            value: value,
                            title: title,
                            onTap: onTap,
                          )
                        : LargeScreenContent(
                            icon: icon,
                            value: value,
                            title: title,
                            onTap: onTap,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double animation, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation)),
          child: Transform.scale(
            scale: 0.8 + (0.2 * animation),
            child: Opacity(
              opacity: animation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  double aspectRatio;
                  if (screenWidth < 350) {
                    aspectRatio = 3.6;
                  } else if (screenWidth < 400) {
                    aspectRatio = 2.2;
                  } else if (screenWidth < 500) {
                    aspectRatio = 1.8;
                  } else {
                    aspectRatio = 1.6;
                  }
                  final isSmallScreen = screenWidth < 400;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thao tác nhanh',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: aspectRatio,
                        children: [
                          _buildActionCard(
                            title: 'Tạo tài khoản',
                            subTitle: 'Thêm user mới',
                            icon: Icons.person_add_rounded,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            // ✅ FIX: Navigation function thay vì Widget
                            onTap: () => _navigateToUserForm(context),
                            delay: const Duration(milliseconds: 100),
                            isSmallScreen: isSmallScreen,
                          ),
                          _buildActionCard(
                            title: 'Tạo môn học',
                            subTitle: 'Thêm 1 môn học',
                            icon: Icons.menu_book_rounded,
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            // ✅ FIX: Navigation function
                            onTap: () => _navigateToCourseForm(context),
                            delay: const Duration(milliseconds: 200),
                            isSmallScreen: isSmallScreen,
                          ),
                          _buildActionCard(
                            title: 'Tạo lớp học',
                            subTitle: 'Thêm 1 lớp học',
                            icon: Icons.school_rounded,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            // ✅ FIX: Navigation function
                            onTap: () => _navigateToClassForm(context),
                            delay: const Duration(milliseconds: 300),
                            isSmallScreen: isSmallScreen,
                          ),
                          _buildActionCard(
                            title: 'Import môn học',
                            subTitle: 'Từ file EXCEL',
                            icon: Icons.upload_file_rounded,
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            // ✅ FIX: Navigation function
                            onTap: () => _navigateToCourseImport(context),
                            delay: const Duration(milliseconds: 400),
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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
              const SizedBox(height: 16),
              Text(
                'Nhật ký hoạt động',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tính năng theo dõi hoạt động hệ thống\nsẽ sớm được cập nhật',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
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

  Widget _buildAcademicTab() {
    return const ClassManagementPage();
  }

  Widget _buildAnalyticsTab() {
    return const CourseManagementPage();
  }
}

void _navigateToUserForm(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const UserFormPage()),
  );
}

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
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const CourseImportPage()),
  );
}
