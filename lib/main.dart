// lib/main.dart - Updated version
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app/providers/admin_class_provider.dart';
import 'app/providers/lecturer_class_provider.dart';
import 'app/providers/student_class_provider.dart';
import 'app/providers/navigation_provider.dart'; // Thêm navigation provider
import 'core/config/firebase_config.dart';
import 'app/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'services/firebase/classes/class_service.dart';
import 'services/firebase/auth/firebase_auth_service.dart';
import 'package:attendify/services/firebase/sessions/session_service.dart';
import 'package:attendify/services/firebase/admin/admin_service.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Khởi tạo dữ liệu định dạng ngày tháng cho ngôn ngữ Tiếng Việt
  await initializeDateFormatting('vi_VN', null);

  runApp(
    MultiProvider(
      providers: [
        // Service thuần (không notify)
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        Provider<SessionService>(create: (_) => SessionService()),

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
