// lib/main.dart - Updated version
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app/providers/admin_class_provider.dart';
import 'app/providers/class_provider.dart';
import 'app/providers/lecturer_class_provider.dart';
import 'app/providers/student_class_provider.dart';
import 'app/providers/navigation_provider.dart'; // Thêm navigation provider
import 'core/config/firebase_config.dart';
import 'app/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'services/firebase/class_service.dart';
import 'services/firebase/firebase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // Service thuần (không notify)
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),

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
