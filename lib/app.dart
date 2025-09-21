// lib/app.dart
import 'package:attendify/features/common/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/providers/auth_provider.dart';
import 'features/admin/presentation/pages/admin_menu.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/lecture/presentation/pages/lecture_menu.dart';
import 'features/schedule/data/services/schedule_service.dart';
import 'features/student/presentation/pages/student_menu.dart';
import 'features/schedule/presentation/pages/schedule_page.dart';

class AttendifyApp extends StatelessWidget {
  const AttendifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final router = _buildRouter(auth);

    return MaterialApp.router(
      title: 'Attendify',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A64AF)),
        // fontFamily: 'Mali',
      ),
    );
  }

  GoRouter _buildRouter(AuthProvider auth) {
    return GoRouter(
      refreshListenable: auth,
      initialLocation: '/login',
      redirect: (context, state) {
        if (auth.isLoading) return null;

        final loggedIn = auth.isLoggedIn;
        final role = auth.roleKey; // 'admin' | 'lecture' | 'student' | null
        final isAuthRoute = switch (state.matchedLocation) {
          '/login' || '/register' || '/reset' => true,
          _ => false,
        };

        if (!loggedIn) {
          return isAuthRoute ? null : '/login';
        }

        if (loggedIn && isAuthRoute) {
          return _roleHome(role);
        }

        if (state.matchedLocation == '/' || state.matchedLocation == '/home') {
          return _roleHome(role);
        }

        return null;
      },
      routes: [
        // Auth
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
        GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
        GoRoute(path: '/reset', builder: (c, s) => const ResetPasswordPage()),

        // Role menus
        GoRoute(path: '/admin', builder: (c, s) => const AdminMenuPage()),
        GoRoute(path: '/lecture', builder: (c, s) => const LectureMenuPage()),
        GoRoute(path: '/student', builder: (c, s) => const StudentMenuPage()),

        GoRoute(
          path: '/schedule',
          builder: (ctx, state) {
            final auth = ctx.read<AuthProvider>();
            final uid = auth.user?.uid ?? '';
            final isLecturer = auth.role == UserRole.lecture;

            // Bọc provider cục bộ cho trang
            return Provider<ScheduleService>(
              create: (_) => ScheduleService(),
              child: SchedulePage(currentUid: uid, isLecturer: isLecturer),
            );
          },
        ),
        // Mặc định
        GoRoute(path: '/', builder: (c, s) => const SizedBox.shrink()),
      ],
    );
  }

  String _roleHome(String? role) {
    switch (role) {
      case 'admin':
        return '/admin';
      case 'lecture':
        return '/lecture';
      case 'student':
      default:
        return '/student';
    }
  }
}
