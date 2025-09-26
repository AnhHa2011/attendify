import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/student/presentation/pages/student_main.dart';
import 'app_routes.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/admin/presentation/pages/admin_main.dart';
import '../features/lecturer/presentation/pages/lecturer_main.dart';
import '../app/providers/auth_provider.dart';
import '../features/common/data/models/user_model.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        // Root route - redirect to appropriate main page or login
        return _buildRoute(const _RootRedirectPage());

      case AppRoutes.login:
        return _buildRoute(const LoginPage());

      case AppRoutes.register:
        return _buildRoute(const RegisterPage());

      case AppRoutes.resetPassword:
        return _buildRoute(const ResetPasswordPage());

      case AppRoutes.adminMain:
        return _buildRoute(const AdminMain());

      case AppRoutes.lecturerMain:
        return _buildRoute(const LecturerMain());

      case AppRoutes.studentMain:
        return _buildRoute(const StudentMain());

      default:
        return _errorRoute(settings.name);
    }
  }

  static Route<dynamic> _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  static Route<dynamic> _errorRoute(String? routeName) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Route: $routeName',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Root redirect page to handle initial navigation
class _RootRedirectPage extends StatelessWidget {
  const _RootRedirectPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Still loading authentication state
        if (auth.isLoading) {
          return const _LoadingScreen();
        }

        // Not logged in - go to login
        if (!auth.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          });
          return const _LoadingScreen();
        }

        // Logged in - go to appropriate main page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final route = _getRoleMainRoute(auth.role);
          Navigator.of(context).pushReplacementNamed(route);
        });

        return const _LoadingScreen();
      },
    );
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

// Loading screen widget
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý điểm danh thông minh',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
