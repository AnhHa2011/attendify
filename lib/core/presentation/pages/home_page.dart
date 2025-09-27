import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../app/providers/auth_provider.dart';
import '../../data/models/user_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role;

    String roleLabel(UserRole? r) {
      switch (r) {
        case UserRole.admin:
          return 'Admin';
        case UserRole.lecture:
          return 'Lecturer';
        case UserRole.student:
          return 'Student';
        default:
          return 'Unknown';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Xin chào, ${auth.user?.displayName ?? auth.user?.email ?? 'User'}\n'
          'Role: ${roleLabel(role)}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
