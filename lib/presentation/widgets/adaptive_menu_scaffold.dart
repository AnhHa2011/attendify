import 'package:flutter/material.dart';

/// Một Scaffold dùng lại cho mọi role:
/// - Hẹp: BottomNavigationBar (NavigationBar)
/// - Rộng: NavigationRail
class AdaptiveMenuScaffold extends StatefulWidget {
  const AdaptiveMenuScaffold({
    super.key,
    required this.destinations,
    required this.pages,
    this.title,
  }) : assert(
         // so sánh trực tiếp, tránh gọi hàm trong const ctor
         // để không bị "Invalid constant value"
         // (destinations length == pages length)
         // ignore: unnecessary_null_comparison
         true,
       );

  final String? title;

  /// Danh sách destination tự định nghĩa (không đụng tên Flutter)
  final List<MenuDestination> destinations;

  /// Mỗi destination tương ứng một page
  final List<Widget> pages;

  @override
  State<AdaptiveMenuScaffold> createState() => _AdaptiveMenuScaffoldState();
}

class _AdaptiveMenuScaffoldState extends State<AdaptiveMenuScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    assert(
      widget.destinations.length == widget.pages.length,
      'destinations và pages phải có cùng số lượng phần tử',
    );

    final isWide = MediaQuery.of(context).size.width >= 900;
    final body = widget.pages[_index];

    // Map từ model của bạn -> widget NavigationDestination của Flutter
    final navBarDestinations = widget.destinations
        .map(
          (d) => NavigationDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon ?? d.icon,
            label: d.label,
          ),
        )
        .toList();

    final railDestinations = widget.destinations
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon ?? d.icon,
            label: Text(d.label),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Attendify')),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
              onDestinationSelected: (i) => setState(() => _index = i),
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              destinations: navBarDestinations,
              onDestinationSelected: (i) => setState(() => _index = i),
            ),
    );
  }
}

/// Model destination của app (tránh đụng tên với NavigationDestination của Flutter)
class MenuDestination {
  const MenuDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final Widget icon;
  final String label;
  final Widget? selectedIcon;
}
