import 'package:get_it/get_it.dart';
import '../../app/providers/auth_provider.dart';
import '../../app/providers/navigation_provider.dart';
import '../../app/providers/admin_class_provider.dart';
import '../../app/providers/lecturer_class_provider.dart';
import '../../app/providers/student_class_provider.dart';
import '../../features/auth/data/services/firebase_auth_service.dart';
import '../../features/classes/data/services/class_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services - Singleton
  sl.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());
  sl.registerLazySingleton<ClassService>(() => ClassService());

  // Providers - Factory (để có thể dispose)
  sl.registerFactory<NavigationProvider>(() => NavigationProvider());
  sl.registerFactory<AuthProvider>(() => AuthProvider(sl()));
  sl.registerFactory<AdminClassProvider>(() => AdminClassProvider(sl()));
  sl.registerFactory<LecturerClassProvider>(() => LecturerClassProvider(sl()));
  sl.registerFactory<StudentClassProvider>(() => StudentClassProvider(sl()));
}
