// lib/presentation/widgets/role_drawer_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/providers/auth_provider.dart';

/// Scaffold dùng Drawer bên trái + IndexedStack cho nội dung.
/// Dùng chung cho Admin / Lecture / Student. Tối ưu cho mobile.
class RoleDrawerScaffold extends StatefulWidget {
  const RoleDrawerScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.pages,
    this.drawerHeader,
  });

  final String title;
  final List<DrawerDestination> destinations;
  final List<Widget> pages;
  final Widget? drawerHeader;

  @override
  State<RoleDrawerScaffold> createState() => _RoleDrawerScaffoldState();
}

class _RoleDrawerScaffoldState extends State<RoleDrawerScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Kiểm tra hợp lệ số lượng item
    assert(
      widget.destinations.length == widget.pages.length,
      'destinations và pages phải có cùng số lượng phần tử',
    );

    final color = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.destinations[_index].label,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
      ),
      drawer: Drawer(
        width: isSmallScreen ? screenSize.width * 0.85 : 280,
        child: SafeArea(
          child: Column(
            children: [
              if (widget.drawerHeader != null) widget.drawerHeader!,

              // Title section với responsive padding
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 6 : 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: color.primary,
                    ),
                  ),
                ),
              ),

              // Danh sách mục điều hướng chính với responsive design
              Expanded(
                child: ListView.builder(
                  itemCount: widget.destinations.length,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                  ),
                  itemBuilder: (context, i) {
                    final d = widget.destinations[i];
                    final selected = i == _index;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        leading: Icon(
                          selected ? (d.selectedIcon ?? d.icon) : d.icon,
                          color: selected
                              ? color.primary
                              : color.onSurfaceVariant,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        title: Text(
                          d.label,
                          style: TextStyle(
                            color: selected ? color.primary : color.onSurface,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                        selected: selected,
                        selectedTileColor: color.primaryContainer.withOpacity(
                          0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        dense: isSmallScreen,
                        minVerticalPadding: isSmallScreen ? 8 : 12,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 2 : 4,
                        ),
                        onTap: () {
                          Navigator.of(context).pop(); // đóng drawer
                          setState(() => _index = i);
                        },
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Mục Đăng xuất với responsive design
              Container(
                margin: EdgeInsets.all(isSmallScreen ? 8 : 12),
                child: ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  title: Text(
                    'Đăng xuất',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  dense: isSmallScreen,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 2 : 4,
                  ),
                  onTap: () async {
                    // Đóng drawer trước
                    Navigator.of(context).pop();

                    // Hiển thị dialog xác nhận
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Đăng xuất',
                          style: TextStyle(fontSize: isSmallScreen ? 18 : 20),
                        ),
                        content: Text(
                          'Bạn có chắc chắn muốn đăng xuất?',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Đăng xuất',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && context.mounted) {
                      // Gọi logout từ AuthProvider
                      await context.read<AuthProvider>().logout();
                    }
                  },
                ),
              ),

              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom / 2),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: widget.pages),
    );
  }
}

/// Mục trong Drawer với responsive design
class DrawerDestination {
  const DrawerDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon; // Optional, fallback to icon if null
  final String label;
}
