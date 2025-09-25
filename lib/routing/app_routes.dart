class AppRoutes {
  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String resetPassword = '/reset-password';

  // Common routes
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  // Admin routes
  static const String adminMain = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String userManagement = '/admin/users';
  static const String courseManagement = '/admin/courses';
  static const String classManagement = '/admin/classes';
  static const String leaveRequestManagement = '/admin/leave-requests';

  // Lecturer routes
  static const String lecturerMain = '/lecturer';
  static const String lecturerDashboard = '/lecturer/dashboard';
  static const String lecturerCourses = '/lecturer/courses';
  static const String lecturerSchedule = '/lecturer/schedule';
  static const String sessionManagement = '/lecturer/sessions';
  static const String attendanceManagement = '/lecturer/attendance';
  static const String leaveApproval = '/lecturer/leave-approval';

  // Student routes
  static const String studentMain = '/student';
  static const String studentClasses = '/student/classes';
  static const String studentSchedule = '/student/schedule';
  static const String attendanceHistory = '/student/attendance';
  static const String joinClass = '/student/join-class';
  static const String qrScanner = '/student/qr-scanner';
  static const String leaveRequest = '/student/leave-request';
  static const String notificationSettings = '/student/notifications';
}
