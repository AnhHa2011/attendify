// lib/features/admin/presentation/pages/admin_main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/navigation_provider.dart';
import 'admin_layout.dart';

class AdminMain extends StatelessWidget {
  const AdminMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        // Đối với admin, chúng ta sử dụng layout hiện đại mới
        // thay vì hệ thống navigation cũ
        return const AdminLayout();
      },
    );
  }
}
