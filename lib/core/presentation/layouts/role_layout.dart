import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/auth_provider.dart';

class RoleLayout extends StatefulWidget {
  const RoleLayout({
    super.key,
    required this.items,
    required this.pages,
    this.initialIndex = 0,
    this.title,
    this.onLogout,
    this.mobileBreakpoint = 820, // 👈 chỉnh breakpoint tại đây
  }) : assert(items.length == pages.length, 'items/pages length mismatch');

  final List<RoleNavigationItem> items;
  final List<Widget> pages;
  final int initialIndex;
  final String? title;
  final Future<void> Function(BuildContext context)? onLogout;
  final double mobileBreakpoint;

  @override
  State<RoleLayout> createState() => _RoleLayoutState();
}

class _RoleLayoutState extends State<RoleLayout> with TickerProviderStateMixin {
  late AnimationController _sidebarController;
  late AnimationController _contentController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _contentAnimation;

  late int _selectedIndex;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutQuart,
    );

    _sidebarController.forward();
    _contentController.forward();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < widget.mobileBreakpoint; // 👈 auto chuyển bottom bar

    final pages = widget.pages;

    if (isMobile) {
      // ======= MOBILE UI: BottomNavigationBar + icon/text nhỏ gọn =======
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? ''),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: () => _logout(),
            ),
          ],
        ),
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          iconSize: 20, // 👈 icon nhỏ
          selectedFontSize: 12, // 👈 chữ nhỏ
          unselectedFontSize: 10, // 👈 chữ nhỏ
          items: [
            for (final it in widget.items)
              BottomNavigationBarItem(
                icon: Icon(it.icon),
                activeIcon: Icon(it.activeIcon ?? it.icon),
                label: it.label,
                tooltip: it.label,
              ),
          ],
        ),
      );
    }

    // ======= DESKTOP/TABLET UI: Sidebar như cũ =======
    return Scaffold(
      body: Row(
        children: [
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-80 * (1 - _sidebarAnimation.value), 0),
                child: Opacity(
                  opacity: _sidebarAnimation.value,
                  child: _buildSidebar(theme, auth.user),
                ),
              );
            },
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(50 * (1 - _contentAnimation.value), 0),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.background,
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: pages,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====== Sidebar (giữ hiệu ứng, thu nhỏ icon/padding để hợp mobile/desktop) ======
  Widget _buildSidebar(ThemeData theme, user) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isExpanded ? 280 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceVariant.withOpacity(0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(theme, user),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = _selectedIndex == index;
                return _buildNavigationItem(theme, item, index, isSelected);
              },
            ),
          ),
          _buildSidebarFooter(theme),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme, user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Row(
        children: [
          Container(
            width: _isExpanded ? 50 : 40,
            height: _isExpanded ? 50 : 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(_isExpanded ? 16 : 12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 22,
            ), // 👈 22 thay vì 24
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName?.split(' ').first ?? 'User',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            tooltip: _isExpanded ? 'Thu gọn' : 'Mở rộng',
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: _isExpanded ? 0 : 0.5,
              child: Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    ThemeData theme,
    RoleNavigationItem item,
    int index,
    bool isSelected,
  ) {
    final grad = item.gradient;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 12,
              vertical: 14, // 👈 giảm nhẹ vertical
            ),
            decoration: BoxDecoration(
              gradient: isSelected ? grad : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: grad.colors.first.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 22, // 👈 22 thay vì 24
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.75),
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withOpacity(0.85),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _isExpanded
          ? InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.errorContainer.withOpacity(0.5),
                      Colors.red.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 20,
                    ), // 👈 nhỏ hơn
                    const SizedBox(height: 6),
                    Text(
                      'Đăng xuất',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
    );
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!(context);
      return;
    }
    await context.read<AuthProvider>().logout();
  }
}

class RoleNavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final LinearGradient gradient;

  const RoleNavigationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.gradient,
  });
}
