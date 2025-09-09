import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart'; // file này do `flutterfire configure` sinh ra

class FirebaseConfig {
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
