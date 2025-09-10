// lib/presentation/widgets/role_drawer_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_provider.dart';

/// Scaffold dùng Drawer bên trái + IndexedStack cho nội dung.
/// Dùng chung cho Admin / Lecture / Student.
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.destinations[_index].label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              if (widget.drawerHeader != null) widget.drawerHeader!,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              // Danh sách mục điều hướng chính
              Expanded(
                child: ListView.builder(
                  itemCount: widget.destinations.length,
                  itemBuilder: (context, i) {
                    final d = widget.destinations[i];
                    final selected = i == _index;
                    return ListTile(
                      leading: Icon(
                        d.icon,
                        color: selected ? color.primary : null,
                      ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          color: selected ? color.primary : null,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      selected: selected,
                      // Flutter mới: dùng withValues(alpha: ...)
                      selectedTileColor: color.primaryContainer.withValues(
                        alpha: 0.25,
                      ),
                      onTap: () {
                        Navigator.of(context).pop(); // đóng drawer
                        setState(() => _index = i);
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Mục Đăng xuất
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất'),
                onTap: () async {
                  // Đóng drawer trước
                  Navigator.of(context).pop();
                  // Gọi logout từ AuthProvider
                  await context.read<AuthProvider>().logout();
                  if (!mounted) return;
                  // Điều hướng về /login và xoá stack
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: widget.pages),
    );
  }
}

/// Mục trong Drawer
class DrawerDestination {
  const DrawerDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
