// lib/main.dart - Updated version with new routing
import 'package:attendify/core/data/services/class_service.dart';
import 'package:attendify/features/admin/data/services/admin_leave_request_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/data/services/courses_service.dart';
import 'app/providers/navigation_provider.dart';
import 'app/providers/auth_provider.dart';
import 'features/admin/data/services/admin_service.dart';
import 'features/auth/data/services/firebase_auth_service.dart';
import 'features/lecturer/services/lecturer_service.dart';
import 'features/notifications/local_notification_service.dart';
import 'core/data/services/schedule_service.dart';
import 'core/data/services/session_service.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Khởi tạo dữ liệu định dạng ngày tháng cho ngôn ngữ Tiếng Việt
  await initializeDateFormatting('vi_VN', null);
  await LocalNotificationService.instance.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(
    MultiProvider(
      providers: [
        // Service thuần (không notify)
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        Provider<SessionService>(create: (_) => SessionService()),
        Provider<ScheduleService>(create: (_) => ScheduleService()),

        // Navigation Provider (thêm mới)
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),

        // Provider phụ thuộc Service
        ChangeNotifierProxyProvider<FirebaseAuthService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<FirebaseAuthService>()),
          update: (ctx, authService, prev) => prev ?? AuthProvider(authService),
        ),

        // services
        Provider<CourseService>(
          create: (_) => CourseService(
            // courseRepo: courseRepo,
            // userRepo: userRepo,
            // sesionRepo: sesionRepo,
          ),
        ),
        Provider<AdminService>(create: (_) => AdminService()),
        Provider<ClassService>(create: (_) => ClassService()),
        Provider<CourseService>(create: (_) => CourseService()),
        Provider<LeaveRequestService>(create: (_) => LeaveRequestService()),
        // // providers theo role
        // ChangeNotifierProvider(
        //   create: (ctx) => AdminCourseProvider(ctx.read<CourseService>()),
        // ),
        // ChangeNotifierProvider(
        //   create: (ctx) => LecturerCourseProvider(ctx.read<CourseService>()),
        // ),
        // ChangeNotifierProvider(
        //   create: (ctx) => StudentCourseProvider(ctx.read<CourseService>()),
        // ),
      ],
      child: const AttendifyApp(),
    ),
  );
}
