// lib/features/.../profile_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/auth_provider.dart';
import '../../../features/auth/presentation/pages/edit_account_page.dart';

class ProfileWidget extends StatelessWidget {
  const ProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy riêng từng field để rebuild tối thiểu
    final displayName =
        context.select<AuthProvider, String?>(
          (p) => p.displayNameFromProfile,
        ) ??
        context.select<AuthProvider, String?>((p) => p.user?.displayName);
    final email = context.select<AuthProvider, String?>((p) => p.user?.email);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin tài khoản',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    (displayName?.isNotEmpty == true)
                        ? displayName!.characters.first.toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(displayName ?? 'Administrator'),
                subtitle: Text(email ?? 'admin@attendify.com'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditAccountPage(currentName: displayName ?? ''),
                      ),
                    );
                    if (updated == true) {
                      // Kéo lại user ngay
                      await context.read<AuthProvider>().refreshUser();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Vai trò'),
                subtitle: const Text('Quản trị viên hệ thống'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
