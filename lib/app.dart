// lib/app.dart - ĐÃ SỬA LỖI
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
    // Router vẫn được build lại mỗi khi auth thay đổi, điều này là đúng.
    final router = _buildRouter(auth);

    return MaterialApp.router(
      // === PHẦN SỬA LỖI QUAN TRỌNG NHẤT ===
      // Key này đảm bảo rằng khi trạng thái đăng nhập (isLoggedIn) thay đổi,
      // toàn bộ MaterialApp sẽ được coi là một widget mới. Điều này buộc
      // Flutter phải xây dựng lại cây widget từ đầu, và quan trọng nhất là
      // các provider trong MultiProvider (từ main.dart) cũng sẽ được
      // khởi tạo lại. Việc này sẽ xóa sạch state cũ của người dùng trước.
      key: ValueKey(auth.isLoggedIn),

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
      initialLocation:
          '/login', // initialLocation có thể được giữ hoặc loại bỏ tuỳ vào logic redirect
      // Logic redirect của bạn đã rất tốt, không cần thay đổi.
      redirect: (context, state) {
        // Tạm thời hiển thị màn hình trống trong khi chờ
        // Nếu không có dòng này, redirect có thể chạy trước khi có trạng thái auth
        if (auth.isLoading)
          return null; // Hoặc trả về một route cho màn hình chờ '/splash'

        final loggedIn = auth.isLoggedIn;
        final role = auth.roleKey; // 'admin' | 'lecture' | 'student' | null
        final isAuthRoute = switch (state.matchedLocation) {
          '/login' || '/register' || '/reset' => true,
          _ => false,
        };

        // Nếu chưa đăng nhập và đang không ở trang auth, điều hướng về login
        if (!loggedIn) {
          return isAuthRoute ? null : '/login';
        }

        // Nếu đã đăng nhập và đang ở trang auth, điều hướng về trang chủ theo vai trò
        if (loggedIn && isAuthRoute) {
          return _roleHome(role);
        }

        // Nếu người dùng truy cập vào trang gốc, điều hướng về trang chủ theo vai trò
        if (state.matchedLocation == '/' || state.matchedLocation == '/home') {
          return _roleHome(role);
        }

        // Các trường hợp khác thì không cần redirect
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
        GoRoute(
          path: '/',
          builder: (c, s) => const SizedBox.shrink(),
        ), // Màn hình trống để redirect
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
