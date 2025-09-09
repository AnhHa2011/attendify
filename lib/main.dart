import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/firebase_config.dart';
import 'app/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'services/firebase/firebase_auth_service.dart';

// Nếu cần các provider khác, import & đăng ký thêm tại đây
// import 'features/classes/providers/class_provider.dart';
// import 'features/attendance/providers/attendance_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // Service thuần (không notify)
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        // Provider phụ thuộc Service
        ChangeNotifierProxyProvider<FirebaseAuthService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<FirebaseAuthService>()),
          update: (ctx, authService, prev) => prev ?? AuthProvider(authService),
        ),

        // Ví dụ mở rộng:
        // ChangeNotifierProvider(create: (_) => ClassProvider()),
        // ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: const AttendifyApp(),
    ),
  );
}
