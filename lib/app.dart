// lib/app.dart - Fixed
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/providers/auth_provider.dart';
import 'core/data/models/user_model.dart';
import 'routing/route_generator.dart';
import 'routing/app_routes.dart';

class AttendifyApp extends StatelessWidget {
  const AttendifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        // 1) Giai đoạn loading: chỉ show một MaterialApp tối giản với home
        if (auth.isLoading) {
          return MaterialApp(
            title: 'Attendify - Quản lý điểm danh thông minh',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            home: const _LoadingScreen(),
          );
        }

        // 2) Đã sẵn sàng: dùng routing (không set home đồng thời)
        return MaterialApp(
          key: ValueKey(auth.isLoggedIn), // buộc rebuild khi login state đổi
          title: 'Attendify - Quản lý điểm danh thông minh',
          debugShowCheckedModeBanner: false,

          // Routing mới
          onGenerateRoute: RouteGenerator.generateRoute,
          initialRoute: _getInitialRoute(auth),

          theme: _lightTheme,
          darkTheme: _darkTheme,
        );
      },
    );
  }

  String _getInitialRoute(AuthProvider auth) {
    return _getRoleMainRoute(auth.role);
  }

  String _getRoleMainRoute(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return AppRoutes.adminMain;
      case UserRole.lecture:
        return AppRoutes.lecturerMain;
      case UserRole.student:
        return AppRoutes.studentMain;
      default:
        return AppRoutes.login;
    }
  }
}

// === THEMEs (đã sửa CardThemeData -> CardTheme) ===
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5A64AF),
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
  ),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5A64AF),
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Attendify',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý điểm danh thông minh',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: cs.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
