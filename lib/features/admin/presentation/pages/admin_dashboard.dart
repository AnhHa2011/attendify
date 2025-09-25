// lib/features/admin/presentation/pages/admin_dashboard.dart
import 'package:attendify/features/admin/presentation/pages/class_management/class_management_page.dart';
import 'package:attendify/features/admin/presentation/pages/course_management/course_management_page.dart';
import 'package:attendify/features/admin/presentation/pages/user_management/user_management_page.dart';
import 'package:attendify/features/classes/presentation/pages/class_list_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../app/providers/navigation_provider.dart';
import '../../../common/data/models/user_model.dart';
import '../../../common/data/models/class_model.dart';
import '../../data/services/admin_service.dart';
import 'admin_ui_components.dart';
import 'course_management/course_import_page.dart';

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
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: Transform.rotate(
              angle: _fabAnimation.value * 2 * 3.14159,
              child: FloatingActionButton.extended(
                onPressed: () => _showQuickActionsSheet(context),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 8,
                icon: const Icon(Icons.add_rounded, size: 24),
                label: const Text(
                  'Thao tác nhanh',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      aspectRatio = 3.0; // Nexus 4 và các màn hình nhỏ hơn
                    } else if (screenWidth < 400) {
                      aspectRatio = 2.2; // Màn hình nhỏ
                    } else if (screenWidth < 500) {
                      aspectRatio = 1.8; // Màn hình trung bình
                    } else {
                      aspectRatio = 1.6; // Màn hình lớn
                    }
                    final isSmallScreen = screenWidth < 400;

                    return GridView.count(
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
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 6 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 8 : 10,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: isSmallScreen ? 16 : 18,
                              ),
                            ),
                            if (onTap != null)
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 14,
                              ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                value,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 0 : 1),
                              Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isSmallScreen ? 10 : 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
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
    final actions = [
      {
        'title': 'Tạo tài khoản',
        'subtitle': 'Thêm user mới',
        'icon': Icons.person_add_rounded,
        'color': Colors.blue,
        'route': '/admin/users/create',
      },
      {
        'title': 'Thêm môn học',
        'subtitle': 'Tạo course mới',
        'icon': Icons.menu_book_rounded,
        'color': Colors.green,
        'route': '/admin/courses/create',
      },
      {
        'title': 'Tạo lớp học',
        'subtitle': 'Setup class',
        'icon': Icons.school_rounded,
        'color': Colors.orange,
        'route': '/admin/classes/create',
      },
      {
        'title': 'Import môn học',
        'subtitle': 'Từ file CSV',
        'icon': Icons.upload_file_rounded,
        'color': Colors.purple,
        'route': '/admin/courses/import',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thao tác nhanh',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 5.0,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double animation, child) {
                return Transform.translate(
                  offset: Offset(30 * (1 - animation), 0),
                  child: Opacity(
                    opacity: animation,
                    child: Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isSmallScreen = screenWidth < 400;

                        return _buildActionCard(
                          title: action['title'] as String,
                          subtitle: action['subtitle'] as String,
                          icon: action['icon'] as IconData,
                          color: action['color'] as Color,
                          onTap: () =>
                              _handleQuickAction(action['route'] as String),
                          isSmallScreen: isSmallScreen,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSmallScreen ? 14 : 18,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 10 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color.withOpacity(0.7),
                          fontSize: isSmallScreen ? 8 : 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.5),
                  size: 14,
                ),
              ],
            ),
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

  void _showQuickActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thao tác nhanh',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Các tính năng sẽ sớm được bổ sung...'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleQuickAction(String route) {
    if (route == '/admin/courses/import') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CourseImportPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigating to $route - Coming Soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
