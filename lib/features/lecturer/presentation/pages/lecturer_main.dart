// lib/features/lecturer/presentation/pages/lecturer_main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/navigation_provider.dart';
import 'lecturer_layout.dart';

class LecturerMain extends StatelessWidget {
  const LecturerMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        // Đối với lecturer, chúng ta sử dụng layout hiện đại mới
        // thay vì hệ thống navigation cũ
        return const LecturerLayout();
      },
    );
  }
}
