import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bọc quanh các trang root: adminMain / lecturerMain / studentMain / login
class ExitOnBack extends StatelessWidget {
  final Widget child;
  const ExitOnBack({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // không cho pop ngược về route trước
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (!kIsWeb) {
          SystemNavigator.pop(); // Android/iOS/desktop: thoát app
        } else {
          // Web: để trình duyệt xử lý nút Back (rời trang),
          // quan trọng là stack trong app không còn route nào trước đó,
          // nên sẽ không quay về loading.
        }
      },
      child: child,
    );
  }
}
