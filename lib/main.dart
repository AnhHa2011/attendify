// lib/main.dart - Updated version
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app/providers/admin_class_provider.dart';
import 'app/providers/lecturer_class_provider.dart';
import 'app/providers/student_class_provider.dart';
import 'app/providers/navigation_provider.dart'; // Thêm navigation provider
import 'app/providers/auth_provider.dart';
import 'features/admin/data/services/admin_service.dart';
import 'features/auth/data/services/firebase_auth_service.dart';
import 'features/classes/data/services/class_service.dart';
import 'features/notifications/local_notification_service.dart';
import 'features/schedule/data/services/schedule_service.dart';
import 'features/sessions/presentation/pages/data/services/session_service.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Khởi tạo dữ liệu định dạng ngày tháng cho ngôn ngữ Tiếng Việt
  await initializeDateFormatting('vi_VN', null);
  await LocalNotificationService.instance.init();

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
        Provider<ClassService>(create: (_) => ClassService()),
        Provider<AdminService>(create: (_) => AdminService()),

        // providers theo role
        ChangeNotifierProvider(
          create: (ctx) => AdminClassProvider(ctx.read<ClassService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LecturerClassProvider(ctx.read<ClassService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StudentClassProvider(ctx.read<ClassService>()),
        ),
      ],
      child: const AttendifyApp(),
    ),
  );
}
