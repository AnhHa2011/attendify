// lib/features/Student/presentation/pages/Student_layout.dart

import 'package:attendify/app_imports.dart' hide AuthProvider;

import '../../../../app/providers/auth_provider.dart';
import '../../../../core/data/services/courses_service.dart';
import '../../student_module.dart';
import 'join_course_page.dart';
import 'student_profile.dart';

class StudentLayout extends StatefulWidget {
  const StudentLayout({super.key});

  @override
  State<StudentLayout> createState() => _StudentLayoutState();
}

class _StudentLayoutState extends State<StudentLayout> {
  // Index của tab “Điểm danh” trong pages
  static const int _attendanceTabIndex = 1;

  // Dùng GlobalKey để gọi stopCamera()/startCamera() từ QrScannerPage
  final GlobalKey qrScannerKey = GlobalKey();

  int _currentIndex = 0;

  @override
  void dispose() {
    // Khi rời màn hình layout => đảm bảo camera tắt
    _stopCameraIfPossible();
    super.dispose();
  }

  void _stopCameraIfPossible() {
    final s = qrScannerKey.currentState;
    // dùng dynamic để tránh phụ thuộc _QrScannerPageState private
    try {
      (s as dynamic)?.stopCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = <RoleNavigationItem>[
      RoleNavigationItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Thời khoá biểu',
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.qr_code,
        activeIcon: Icons.menu_book_rounded,
        label: 'Điểm danh',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.class_outlined,
        activeIcon: Icons.class_outlined,
        label: 'Tham gia môn học',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.class_outlined,
        activeIcon: Icons.class_outlined,
        label: 'Môn học',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.history,
        activeIcon: Icons.class_outlined,
        label: 'Lịch sử',
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_available_rounded,
        label: 'Nghỉ phép',
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
      ),
      RoleNavigationItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Cá nhân',
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
      ),
    ];

    final pages = [
      StudentSchedulePage(),
      // CHÚ Ý: gắn key để điều khiển camera
      QrScannerPage(key: qrScannerKey),
      JoinCoursePage(),
      StudentCourseListPage(),
      StudentAttendanceHistoryPage(),
      LeaveRequestStatusPage(),
      StudentProfilePage(),
    ];

    return RoleLayout(
      title: 'Bảng điều khiển (Sinh viên)',
      items: items,
      pages: pages,
      // Nếu RoleLayout của bạn có callback đổi tab, dùng nó để tắt camera
      onTabChanged: (idx) {
        // Rời tab “Điểm danh” => tắt camera
        if (_currentIndex == _attendanceTabIndex &&
            idx != _attendanceTabIndex) {
          _stopCameraIfPossible();
        }
        _currentIndex = idx;
      },

      // Nếu RoleLayout không có onTabChanged, bạn có thể thêm thuộc tính đó
      // trong RoleLayout (gọi callback mỗi khi BottomNavigationBar/TabView đổi index).
      onLogout: (ctx) async {
        // Trước khi logout đảm bảo tắt camera
        _stopCameraIfPossible();
        await ctx.read<AuthProvider>().logout();
      },
    );
  }
}
