// lib/features/admin/presentation/pages/admin_profile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../../app/providers/auth_provider.dart';
import '../../../auth/presentation/pages/edit_account_page.dart';

class AdminProfile extends StatefulWidget {
  const AdminProfile({super.key});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late Animation<double> _backgroundAnimation;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    _cardAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.1),
            curve: Curves.fastOutSlowIn, // Thay đổi từ Curves.easeOutBack để tránh vượt 1.0
          ),
        ),
      );
    });

    _backgroundController.repeat();
    _cardController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5 + (_backgroundAnimation.value * 0.3), 1.0],
                  ),
                ),
              );
            },
          ),

          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _cardAnimations[0],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - _cardAnimations[0].value)),
                      child: Opacity(
                        opacity: math.min(1.0, math.max(0.0, _cardAnimations[0].value)),
                        child: _buildProfileHeader(theme, user),
                      ),
                    );
                  },
                ),
              ),

              // Profile Sections
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Personal Information
                    AnimatedBuilder(
                      animation: _cardAnimations[1],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            30 * (1 - _cardAnimations[1].value),
                          ),
                          child: Opacity(
                            opacity: math.min(1.0, math.max(0.0, _cardAnimations[1].value)),
                            child: _buildPersonalInfoSection(theme, user),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // System Settings
                    AnimatedBuilder(
                      animation: _cardAnimations[2],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            30 * (1 - _cardAnimations[2].value),
                          ),
                          child: Opacity(
                            opacity: math.min(1.0, math.max(0.0, _cardAnimations[2].value)),
                            child: _buildSystemSection(theme),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, user) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar với animated gradient border
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                      theme.colorScheme.tertiary,
                    ],
                    transform: GradientRotation(value * 6.28),
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // User info với typewriter effect
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              final displayName = user?.displayName ?? 'System Administrator';
              final visibleLength = (displayName.length * value).round();
              return Column(
                children: [
                  Text(
                    displayName.substring(0, visibleLength),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (value > 0.5) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.secondary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'System Administrator',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          Text(
            user?.email ?? 'admin@attendify.com',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(ThemeData theme, user) {
    return _buildGlassCard(
      theme: theme,
      title: 'Thông tin cá nhân',
      icon: Icons.person_outline_rounded,
      children: [
        _buildInfoTile(
          theme: theme,
          icon: Icons.account_circle_outlined,
          title: 'Tên hiển thị',
          subtitle: user?.displayName ?? 'Chưa có tên',
          trailing: Icons.edit_outlined,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditAccountPage(
                  currentName: user?.displayName ?? '',
                  currentPhotoUrl: user?.photoURL,
                ),
              ),
            );
          },
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.email_outlined,
          title: 'Email',
          subtitle: user?.email ?? 'Chưa có email',
          trailing: Icons.verified_rounded,
          trailingColor: Colors.green,
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.shield_rounded,
          title: 'Vai trò',
          subtitle: 'Quản trị viên hệ thống',
          trailing: Icons.admin_panel_settings_rounded,
          trailingColor: theme.colorScheme.primary,
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.access_time_rounded,
          title: 'Lần cuối truy cập',
          subtitle: 'Đang hoạt động',
          trailing: Icons.circle,
          trailingColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildSystemSection(ThemeData theme) {
    return _buildGlassCard(
      theme: theme,
      title: 'Cài đặt hệ thống',
      icon: Icons.settings_rounded,
      children: [
        _buildInfoTile(
          theme: theme,
          icon: Icons.security_rounded,
          title: 'Bảo mật',
          subtitle: 'Quản lý mật khẩu và xác thực',
          trailing: Icons.chevron_right_rounded,
          onTap: () => _showSecurityDialog(),
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.backup_rounded,
          title: 'Sao lưu dữ liệu',
          subtitle: 'Export toàn bộ dữ liệu hệ thống',
          trailing: Icons.chevron_right_rounded,
          onTap: () => _showBackupDialog(),
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.notifications_rounded,
          title: 'Thông báo',
          subtitle: 'Cài đặt nhận thông báo',
          trailing: Icons.chevron_right_rounded,
          onTap: () => _showNotificationDialog(),
        ),
        _buildInfoTile(
          theme: theme,
          icon: Icons.system_update_rounded,
          title: 'Cập nhật',
          subtitle: 'Phiên bản v1.0.0 (mới nhất)',
          trailing: Icons.check_circle_rounded,
          trailingColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.2),
                        theme.colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    IconData? trailing,
    Color? trailingColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (trailingColor ?? theme.colorScheme.onSurface)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      trailing,
                      size: 18,
                      color:
                          trailingColor ??
                          theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.blue),
            SizedBox(width: 12),
            Text('Cài đặt bảo mật'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Các tùy chọn bảo mật:'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.password_rounded),
              title: Text('Đổi mật khẩu'),
              dense: true,
            ),
            ListTile(
              leading: Icon(Icons.phone_android_rounded),
              title: Text('Xác thực 2 bước'),
              dense: true,
            ),
            ListTile(
              leading: Icon(Icons.history_rounded),
              title: Text('Lịch sử đăng nhập'),
              dense: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng bảo mật đang phát triển'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Cấu hình'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.backup_rounded, color: Colors.green),
            SizedBox(width: 12),
            Text('Sao lưu dữ liệu'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tạo bản sao lưu toàn bộ dữ liệu hệ thống?'),
            SizedBox(height: 16),
            LinearProgressIndicator(value: 0.8),
            SizedBox(height: 8),
            Text('Dung lượng ước tính: ~4.2MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _simulateBackup();
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Tải xuống'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Cài đặt thông báo'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Thông báo email'),
              subtitle: Text('Nhận thông báo qua email'),
              value: true,
              onChanged: null,
            ),
            SwitchListTile(
              title: Text('Thông báo push'),
              subtitle: Text('Nhận thông báo trên ứng dụng'),
              value: true,
              onChanged: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã lưu cài đặt thông báo'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _simulateBackup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tạo bản sao lưu...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sao lưu thành công! File đã được tải xuống.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}
