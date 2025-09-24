// // lib/features/lecture/presentation/pages/lecture_menu.dart
// import 'package:attendify/features/schedule/presentation/pages/schedule_page.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

// import '../../../../app/providers/auth_provider.dart';
// import '../../../../app/providers/navigation_provider.dart';
// import '../../../auth/presentation/pages/edit_account_page.dart';
// import '../../../classes/data/services/class_service.dart';
// import '../../../common/data/models/class_model.dart';
// import '../../../common/data/models/session_model.dart';
// import '../../../common/data/models/user_model.dart';

// import '../../../admin/data/services/admin_service.dart'; // <<<--- Cần cho việc lấy SV

// import '../../../sessions/presentation/pages/data/services/session_service.dart';
// import '../../../sessions/presentation/pages/session_detail_page.dart';
// import '../../../schedule/data/services/schedule_service.dart';
// import '../../../schedule/domain/reminder_scheduler.dart';
// import '../../../classes/widgets/dynamic_qr_code_dialog.dart'; // <<<--- Import dialog QR động

// class LectureMenuPage extends StatefulWidget {
//   const LectureMenuPage({super.key});

//   @override
//   State<LectureMenuPage> createState() => _LectureMenuPageState();
// }

// class _LectureMenuPageState extends State<LectureMenuPage> {
//   int _selectedIndex = 0;

//   @override
//   void initState() {
//     super
//         .initState(); // Đảm bảo rằng chỉ số luôn được reset về 0 khi widget được khởi tạo
//     _selectedIndex = 0;
//     // Đặt thông báo nhắc lịch cho giảng viên đang đăng nhập
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid != null) {
//       // cần ScheduleService có sẵn trong Provider tree
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         final schedule = context.read<ScheduleService>();
//         ReminderScheduler(
//           schedule,
//         ).rescheduleForUser(uid: uid, isLecturer: true);
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<NavigationProvider>(
//       builder: (context, navProvider, child) {
//         switch (navProvider.currentLevel) {
//           case NavigationLevel.main:
//             return const MainMenuScaffold();
//           case NavigationLevel.classContext:
//             return ClassContextMenuScaffold(
//               classId: navProvider.selectedClassId!,
//               className: navProvider.selectedClassName!,
//             );
//         }
//       },
//     );
//   }
// }

// // Main Menu (Level 1)
// class MainMenuScaffold extends StatelessWidget {
//   const MainMenuScaffold({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final navProvider = context.watch<NavigationProvider>();

//     final destinations = <DrawerDestination>[
//       DrawerDestination(
//         icon: Icons.dashboard_outlined,
//         label: 'Tổng quan (giảng viên)',
//       ),
//       DrawerDestination(
//         icon: Icons.calendar_month_outlined,
//         label: 'Thời khoá biểu',
//       ),
//       DrawerDestination(icon: Icons.school_outlined, label: 'Lớp học của tôi'),
//       const DrawerDestination(
//         icon: Icons.person_outline,
//         label: 'Thông tin cá nhân',
//       ),
//     ];

//     final pages = <Widget>[
//       const _DashboardPage(),
//       const _ScheduleListPage(),
//       const _ClassListPage(),
//       _ProfilePage(),
//     ];

//     return RoleDrawerScaffold(
//       title: 'Giảng viên',
//       destinations: destinations,
//       pages: pages,
//       currentIndex: navProvider.currentIndex,
//       onDestinationSelected: navProvider.setCurrentIndex,
//       drawerHeader: const _DrawerHeader(role: 'Giảng viên'),
//     );
//   }
// }

// // Class Context Menu (Level 2)
// class ClassContextMenuScaffold extends StatelessWidget {
//   final String classId;
//   final String className;

//   const ClassContextMenuScaffold({
//     super.key,
//     required this.classId,
//     required this.className,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final navProvider = context.watch<NavigationProvider>();

//     final destinations = <DrawerDestination>[
//       const DrawerDestination(
//         icon: Icons.event_note_outlined,
//         label: 'Buổi học',
//       ),
//       const DrawerDestination(
//         icon: Icons.qr_code_outlined,
//         label: 'QR điểm danh',
//       ),
//       const DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
//     ];

//     final pages = <Widget>[
//       _SessionListPage(classId: classId),
//       _QRAttendancePage(classId: classId),
//       _LeaveRequestPage(classId: classId),
//     ];

//     return RoleDrawerScaffold(
//       title: className,
//       destinations: destinations,
//       pages: pages,
//       currentIndex: navProvider.currentIndex,
//       onDestinationSelected: navProvider.setCurrentIndex,
//       drawerHeader: _ClassContextHeader(
//         className: className,
//         onBackToMain: () => navProvider.navigateToMainLevel(index: 1),
//       ),
//     );
//   }
// }

// /// Drawer shell (bạn đang custom trong file này)
// class RoleDrawerScaffold extends StatelessWidget {
//   final String title;
//   final List<DrawerDestination> destinations;
//   final List<Widget> pages;
//   final int currentIndex;
//   final Function(int) onDestinationSelected;
//   final Widget? drawerHeader;

//   const RoleDrawerScaffold({
//     super.key,
//     required this.title,
//     required this.destinations,
//     required this.pages,
//     this.currentIndex = 0,
//     required this.onDestinationSelected,
//     this.drawerHeader,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(title: Text(destinations[currentIndex].label)),
//       drawer: Drawer(
//         child: SafeArea(
//           child: Column(
//             children: [
//               if (drawerHeader != null) drawerHeader!,
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 8,
//                 ),
//                 child: Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     title,
//                     style: Theme.of(context).textTheme.titleMedium,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: destinations.length,
//                   itemBuilder: (context, i) {
//                     final d = destinations[i];
//                     final selected = i == currentIndex;
//                     return ListTile(
//                       leading: Icon(
//                         d.icon,
//                         color: selected ? color.primary : null,
//                       ),
//                       title: Text(
//                         d.label,
//                         style: TextStyle(
//                           color: selected ? color.primary : null,
//                           fontWeight: selected ? FontWeight.w600 : null,
//                         ),
//                       ),
//                       selected: selected,
//                       selectedTileColor: color.primaryContainer.withValues(
//                         alpha: 0.25,
//                       ),
//                       onTap: () {
//                         Navigator.of(context).pop();
//                         onDestinationSelected(i);
//                       },
//                     );
//                   },
//                 ),
//               ),
//               const Divider(height: 1),
//               ListTile(
//                 leading: const Icon(Icons.logout, color: Colors.red),
//                 title: const Text('Đăng xuất'),
//                 onTap: () async {
//                   Navigator.of(context).pop();
//                   await context.read<AuthProvider>().logout();
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: IndexedStack(index: currentIndex, children: pages),
//     );
//   }
// }

// class DrawerDestination {
//   final IconData icon;
//   final String label;
//   const DrawerDestination({required this.icon, required this.label});
// }

// // Drawer Headers
// class _DrawerHeader extends StatelessWidget {
//   final String role;
//   const _DrawerHeader({required this.role});

//   @override
//   Widget build(BuildContext context) {
//     final color = Theme.of(context).colorScheme;
//     return UserAccountsDrawerHeader(
//       accountName: const Text('Attendify'),
//       accountEmail: Text(role),
//       currentAccountPicture: CircleAvatar(
//         backgroundColor: color.primaryContainer,
//         child: Icon(Icons.person, color: color.onPrimaryContainer),
//       ),
//     );
//   }
// }

// class _ClassContextHeader extends StatelessWidget {
//   final String className;
//   final VoidCallback onBackToMain;

//   const _ClassContextHeader({
//     required this.className,
//     required this.onBackToMain,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = Theme.of(context).colorScheme;
//     return Container(
//       height: 120,
//       color: color.primaryContainer,
//       child: SafeArea(
//         child: Column(
//           children: [
//             ListTile(
//               leading: IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: onBackToMain,
//               ),
//               title: Text(
//                 'Lớp học',
//                 style: TextStyle(fontSize: 12, color: color.onPrimaryContainer),
//               ),
//               subtitle: Text(
//                 className,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: color.onPrimaryContainer,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Dashboard Page
// class _DashboardPage extends StatelessWidget {
//   const _DashboardPage();

//   @override
//   Widget build(BuildContext context) {
//     final classService = context.read<ClassService>();
//     return Scaffold(
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [_LecturerDashboardStats(classService: classService)],
//         ),
//       ),
//     );
//   }
// }

// class _LecturerDashboardStats extends StatelessWidget {
//   final ClassService classService;
//   const _LecturerDashboardStats({required this.classService});

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.read<AuthProvider>();
//     final lecturerUid = auth.user?.uid;
//     if (lecturerUid == null) return const SizedBox.shrink();

//     // <<<--- THAY ĐỔI: STREAMBUILDER SỬ DỤNG RICHCLASSMODEL ---<<<
//     return StreamBuilder<List<RichClassModel>>(
//       stream: classService.getRichClassesStreamForLecturer(lecturerUid),
//       builder: (context, snapshot) {
//         final myClasses = snapshot.data ?? [];
//         return Row(
//           children: [
//             Expanded(
//               child: _StatCard(
//                 title: 'Lớp của tôi',
//                 value: '${myClasses.length}',
//                 icon: Icons.class_,
//                 color: Colors.orange,
//               ),
//             ),
//             const SizedBox(width: 16),
//             const Expanded(
//               child: _StatCard(
//                 title: 'Sinh viên',
//                 value: '...', // Cần logic mới để đếm tổng SV
//                 icon: Icons.people,
//                 color: Colors.purple,
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   final String title;
//   final String value;
//   final IconData icon;
//   final Color color;

//   const _StatCard({
//     required this.title,
//     required this.value,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(icon, color: color),
//                 const Spacer(),
//                 Text(
//                   value,
//                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                     color: color,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(title, style: Theme.of(context).textTheme.bodyMedium),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ClassListPage extends StatelessWidget {
//   const _ClassListPage();

//   @override
//   Widget build(BuildContext context) => const _LecturerAndStudentClassList();
// }

// class _ScheduleListPage extends StatelessWidget {
//   const _ScheduleListPage();

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final currentUser = auth.user;
//     if (currentUser == null) {
//       return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
//     }
//     return SchedulePage(
//       currentUid: currentUser.uid,
//       isLecturer: auth.role == UserRole.lecture,
//     );
//   }
// }

// class _LecturerAndStudentClassList extends StatelessWidget {
//   const _LecturerAndStudentClassList();

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final classService = context.read<ClassService>();

//     // <<<--- THAY ĐỔI: STREAMBUILDER SỬ DỤNG RICHCLASSMODEL ---<<<
//     Stream<List<RichClassModel>> getClassStream() {
//       if (auth.role == UserRole.lecture) {
//         return classService.getRichClassesStreamForLecturer(auth.user!.uid);
//       } else {
//         return classService.getRichEnrolledClassesStream(auth.user!.uid);
//       }
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Danh sách lớp học của tôi'),
//         automaticallyImplyLeading: false,
//       ),
//       body: StreamBuilder<List<RichClassModel>>(
//         stream: getClassStream(),
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snap.hasError) {
//             return Center(child: Text('Lỗi: ${snap.error}'));
//           }
//           final richClasses = snap.data ?? [];
//           if (richClasses.isEmpty) {
//             return const Center(child: Text('Bạn chưa có lớp học nào.'));
//           }

//           return ListView.builder(
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             itemCount: richClasses.length,
//             itemBuilder: (context, index) {
//               final richClass = richClasses[index];
//               final classInfo = richClass.classInfo;
//               final courses = richClass.courses;

//               final leadingText = classInfo.classCode.isNotEmpty
//                   ? classInfo.classCode[0].toUpperCase()
//                   : 'L';

//               return Card(
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 child: ListTile(
//                   leading: CircleAvatar(child: Text(leadingText)),
//                   title: Text(
//                     '${classInfo.classCode} - ${classInfo.className}',
//                   ),
//                   subtitle: Text(courses.map((c) => c.courseCode).join(' | ')),
//                   trailing: const Icon(Icons.chevron_right),
//                   onTap: () {
//                     // Chuyển sang màn hình ngữ cảnh của lớp học
//                     context.read<NavigationProvider>().navigateToClassContext(
//                       classId: classInfo.id,
//                       className: classInfo.className,
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class _AdminClassList extends StatefulWidget {
//   @override
//   State<_AdminClassList> createState() => _AdminClassListState();
// }

// class _AdminClassListState extends State<_AdminClassList> {
//   String? _selectedLecturerUid;
//   @override
//   Widget build(BuildContext context) {
//     // <<<--- THAY ĐỔI 1: LẤY CẢ HAI SERVICE CẦN THIẾT ---<<<
//     final classService = context.read<ClassService>();
//     final adminService = context.read<AdminService>();

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           // <<<--- THAY ĐỔI 2: SỬA LẠI STREAM LẤY GIẢNG VIÊN ---<<<
//           child: StreamBuilder<List<UserModel>>(
//             // <<<--- Đổi thành UserModel
//             stream: adminService
//                 .getAllLecturersStream(), // <<<--- Gọi hàm từ AdminService
//             builder: (context, snap) {
//               final lecturers = snap.data ?? [];
//               return DropdownButtonFormField<String>(
//                 value: _selectedLecturerUid,
//                 hint: const Text('Lọc theo giảng viên'),
//                 decoration: const InputDecoration(
//                   border: OutlineInputBorder(),
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 8,
//                   ),
//                 ),
//                 items: [
//                   const DropdownMenuItem<String>(
//                     value: null,
//                     child: Text('Tất cả giảng viên'),
//                   ),
//                   ...lecturers.map(
//                     (lecturer) => DropdownMenuItem<String>(
//                       value: lecturer.uid,
//                       child: Text(
//                         '${lecturer.displayName} — ${lecturer.email}',
//                       ),
//                     ),
//                   ),
//                 ],
//                 onChanged: (v) => setState(() => _selectedLecturerUid = v),
//               );
//             },
//           ),
//         ),

//         // <<<--- THAY ĐỔI 3: SỬA LẠI STREAMBUILDER CHÍNH VỚI RICHCLASSMODEL ---<<<
//         Expanded(
//           child: StreamBuilder<List<RichClassModel>>(
//             // <<<--- Đổi thành RichClassModel
//             stream: _selectedLecturerUid == null
//                 ? classService.getRichClassesStream()
//                 : classService.getRichClassesStreamForLecturer(
//                     _selectedLecturerUid!,
//                   ),
//             builder: (context, snap) {
//               if (snap.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (snap.hasError) {
//                 return Center(child: Text('Lỗi: ${snap.error}'));
//               }
//               final richClasses = snap.data ?? [];
//               if (richClasses.isEmpty) {
//                 return const Center(child: Text('Không có lớp học nào'));
//               }

//               return ListView.builder(
//                 padding: const EdgeInsets.only(bottom: 80),
//                 itemCount: richClasses.length,
//                 itemBuilder: (context, index) {
//                   // <<<--- THAY ĐỔI 4: BÓC TÁCH VÀ HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ---<<<
//                   final richClass = richClasses[index];
//                   final classInfo = richClass.classInfo;
//                   final courses = richClass.courses;
//                   final lecturer = richClass.lecturer;

//                   final leadingText = classInfo.classCode.isNotEmpty
//                       ? classInfo.classCode[0].toUpperCase()
//                       : 'L';

//                   final courseCodes = courses
//                       .map((c) => c.courseCode)
//                       .join(' | ');

//                   return Card(
//                     margin: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 4,
//                     ),
//                     child: ListTile(
//                       leading: CircleAvatar(child: Text(leadingText)),
//                       title: Text(
//                         '${classInfo.classCode} - ${classInfo.className}',
//                       ),
//                       subtitle: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             courseCodes,
//                             style: TextStyle(
//                               color: Theme.of(context).colorScheme.primary,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text('GV: ${lecturer?.displayName ?? "..."}'),
//                           Text('Mã tham gia: ${classInfo.joinCode}'),
//                         ],
//                       ),
//                       trailing: const Icon(Icons.chevron_right),
//                       isThreeLine: true,
//                       onTap: () {
//                         // Điều hướng sang màn hình ngữ cảnh của lớp học
//                         context
//                             .read<NavigationProvider>()
//                             .navigateToClassContext(
//                               classId: classInfo.id,
//                               className: classInfo.className,
//                             );
//                       },
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final user = auth.user;

//     return Scaffold(
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Thông tin tài khoản',
//               style: Theme.of(context).textTheme.headlineSmall,
//             ),
//             const SizedBox(height: 24),
//             Card(
//               child: ListTile(
//                 leading: CircleAvatar(
//                   child: Text(
//                     (user?.displayName?.isNotEmpty == true)
//                         ? user!.displayName![0].toUpperCase()
//                         : 'U',
//                   ),
//                 ),
//                 title: Text(user?.displayName ?? 'Chưa có tên'),
//                 subtitle: Text(user?.email ?? 'Chưa có email'),
//                 trailing: IconButton(
//                   icon: const Icon(Icons.edit),
//                   onPressed: () async {
//                     final ok = await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => EditAccountPage(
//                           currentName: user?.displayName ?? '',
//                           currentPhotoUrl: user?.photoURL,
//                         ),
//                       ),
//                     );
//                     if (ok == true) {
//                       // reload nếu cần
//                     }
//                   },
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             const Card(
//               child: ListTile(
//                 leading: Icon(Icons.badge),
//                 title: Text('Vai trò'),
//                 subtitle: Text('Giảng viên'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ===== Class context pages =====

// class _SessionListPage extends StatefulWidget {
//   final String classId;
//   const _SessionListPage({required this.classId});

//   @override
//   State<_SessionListPage> createState() => _SessionListPageState();
// }

// class _SessionListPageState extends State<_SessionListPage> {
//   // Loại bỏ biến _isCreatingSession vì không còn tạo buổi học trực tiếp ở đây
//   // bool _isCreatingSession = false;

//   // HÀM MỚI 1: Hiển thị QR động cho buổi học được chọn
//   // Hàm này sẽ được gọi sau khi giảng viên chọn một buổi học từ danh sách.
//   Future<void> _showDynamicQrForSession(SessionModel session) async {
//     final sessionService = context.read<SessionService>();
//     try {
//       // Bật chế độ điểm danh trên Firestore
//       await sessionService.startAttendanceForSession(session.id);

//       if (!mounted) return;

//       // Hiển thị dialog QR động (từ file dynamic_qr_code_dialog.dart)
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => DynamicQrCodeDialog(
//           classId: widget.classId,
//           sessionId: session.id,
//           sessionTitle: session.title,
//         ),
//       ).then((_) {
//         // Sau khi dialog QR đóng, tự động tắt chế độ điểm danh
//         sessionService.toggleAttendance(session.id, false);
//         // Có thể thêm thông báo nhỏ để xác nhận
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Đã đóng điểm danh.')));
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu điểm danh: $e')));
//     }
//   }

//   // HÀM MỚI 2: Hiển thị danh sách các buổi học hôm nay để chọn
//   // Hàm này được gọi khi nhấn vào nút "Tạo mã QR"
//   void _showTodaySessionsDialog() {
//     final sessionService = context.read<SessionService>();
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return StreamBuilder<List<SessionModel>>(
//           // Sử dụng hàm có sẵn để lấy các buổi học có thể điểm danh trong ngày
//           stream: sessionService.getAttendableSessionsForClass(widget.classId),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Lỗi: ${snapshot.error}'));
//             }
//             final sessionsToday = snapshot.data ?? [];
//             if (sessionsToday.isEmpty) {
//               return const Center(
//                 child: Padding(
//                   padding: EdgeInsets.all(24.0),
//                   child: Text(
//                     'Không có buổi học nào được lên lịch hôm nay để điểm danh.',
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               );
//             }

//             // Hiển thị danh sách buổi học trong BottomSheet
//             return Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Text(
//                     'Chọn buổi học để điểm danh',
//                     style: Theme.of(context).textTheme.titleLarge,
//                   ),
//                 ),
//                 const Divider(height: 1),
//                 Flexible(
//                   child: ListView.builder(
//                     shrinkWrap: true,
//                     itemCount: sessionsToday.length,
//                     itemBuilder: (context, index) {
//                       final session = sessionsToday[index];
//                       return ListTile(
//                         leading: const Icon(Icons.qr_code_scanner_outlined),
//                         title: Text(session.title),
//                         subtitle: Text(
//                           'Bắt đầu lúc: ${DateFormat.Hm().format(session.startTime)}',
//                         ),
//                         onTap: () {
//                           Navigator.of(context).pop(); // Đóng BottomSheet
//                           _showDynamicQrForSession(session); // Mở dialog QR
//                         },
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final classService = context.read<ClassService>();
//     final sessionService = context.read<SessionService>();

//     return Scaffold(
//       body: StreamBuilder<RichClassModel>(
//         stream: classService.getRichClassStream(widget.classId),
//         builder: (context, classSnapshot) {
//           if (classSnapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (classSnapshot.hasError || !classSnapshot.hasData) {
//             return Center(
//               child: Text(
//                 classSnapshot.error?.toString() ??
//                     'Không tải được thông tin lớp',
//               ),
//             );
//           }
//           final richClass = classSnapshot.data!;
//           final classData = richClass.classInfo;
//           final courses = richClass.courses;
//           final lecturer = richClass.lecturer;

//           return Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             'Buổi học',
//                             style: Theme.of(context).textTheme.headlineSmall,
//                           ),
//                         ),
//                         // --- THAY ĐỔI LOGIC VÀ GIAO DIỆN CỦA NÚT BẤM ---
//                         FilledButton.icon(
//                           // onPressed giờ sẽ gọi dialog chọn buổi học
//                           onPressed: _showTodaySessionsDialog,
//                           // Icon và Text được cập nhật để phản ánh chức năng mới
//                           icon: const Icon(Icons.qr_code_2_outlined),
//                           label: const Text('Tạo mã QR'),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Card(
//                       margin: EdgeInsets.zero,
//                       child: ListTile(
//                         leading: const Icon(Icons.class_),
//                         title: Text(classData.className),
//                         subtitle: Text(
//                           'Môn: ${courses.map((c) => c.courseCode).join(', ')} • GV: ${lecturer?.displayName ?? "..."}',
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 // Phần hiển thị danh sách các buổi học đã tạo không thay đổi
//                 child: StreamBuilder<List<SessionModel>>(
//                   stream: sessionService.sessionsOfClass(widget.classId),
//                   builder: (context, sessionSnap) {
//                     if (sessionSnap.connectionState ==
//                         ConnectionState.waiting) {
//                       return const Center(child: CircularProgressIndicator());
//                     }
//                     final sessions = sessionSnap.data ?? [];
//                     if (sessions.isEmpty) {
//                       return const Center(
//                         child: Text('Chưa có buổi học nào được tạo.'),
//                       );
//                     }
//                     return ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       itemCount: sessions.length,
//                       itemBuilder: (context, index) {
//                         final session = sessions[index];
//                         return Card(
//                           margin: const EdgeInsets.only(bottom: 8),
//                           child: ListTile(
//                             leading: const Icon(Icons.event_available),
//                             title: Text(session.title),
//                             subtitle: Text(
//                               'Bắt đầu: ${DateFormat.yMd().add_Hm().format(session.startTime)}',
//                             ),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => SessionDetailPage(
//                                     session: session,
//                                     classInfo: classData,
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }

// class _QRAttendancePage extends StatelessWidget {
//   final String classId;
//   const _QRAttendancePage({required this.classId});
//   @override
//   Widget build(BuildContext context) {
//     final classService = context.read<ClassService>();

//     return Scaffold(
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               'QR Điểm danh',
//               style: Theme.of(context).textTheme.headlineSmall,
//             ),
//           ),
//           // <<<--- THAY ĐỔI: STREAMBUILDER SỬ DỤNG RICHCLASSMODEL ---<<<
//           StreamBuilder<RichClassModel>(
//             stream: classService.getRichClassStream(classId),
//             builder: (context, snapshot) {
//               if (snapshot.hasData) {
//                 final classData =
//                     snapshot.data!.classInfo; // Lấy ClassModel gốc
//                 return Card(
//                   margin: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       children: [
//                         Text(
//                           'Mã tham gia lớp: ${classData.joinCode}',
//                           style: Theme.of(context).textTheme.titleMedium,
//                         ),
//                         const SizedBox(height: 8),
//                         QrImageView(data: classData.joinCode, size: 180),
//                         const SizedBox(height: 8),
//                         OutlinedButton.icon(
//                           onPressed: () async {
//                             await classService.regenerateJoinCode(classId);
//                             if (context.mounted) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(content: Text('Đã tạo mã mới')),
//                               );
//                             }
//                           },
//                           icon: const Icon(Icons.refresh),
//                           label: const Text('Tạo mã mới'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               }
//               return const CircularProgressIndicator();
//             },
//           ),
//           const Expanded(
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.inbox_outlined,
//                     size: 64,
//                     color: Color(0xFFBDBDBD),
//                   ),
//                   SizedBox(height: 16),
//                   Text('Tính năng đang phát triển'),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _LeaveRequestPage extends StatelessWidget {
//   final String classId;
//   const _LeaveRequestPage({required this.classId});

//   @override
//   Widget build(BuildContext context) {
//     // <<<--- THAY ĐỔI: SỬ DỤNG ADMINSERVICE ĐỂ LẤY SINH VIÊN ---<<<
//     final adminService = context.read<AdminService>();

//     return Scaffold(
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               'Đơn xin nghỉ',
//               style: Theme.of(context).textTheme.headlineSmall,
//             ),
//           ),
//           StreamBuilder<List<UserModel>>(
//             stream: adminService.getEnrolledStudentsStream(classId),
//             builder: (context, snapshot) {
//               if (snapshot.hasData) {
//                 final members = snapshot.data!;
//                 return Card(
//                   margin: const EdgeInsets.symmetric(horizontal: 16),
//                   child: ListTile(
//                     leading: const Icon(Icons.people),
//                     title: const Text('Sinh viên trong lớp'),
//                     trailing: Text('${members.length} người'),
//                   ),
//                 );
//               }
//               return const SizedBox.shrink();
//             },
//           ),
//           Expanded(
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Chưa có đơn xin nghỉ nào',
//                     style: Theme.of(context).textTheme.titleMedium,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Đơn xin nghỉ từ sinh viên sẽ hiển thị ở đây',
//                     style: Theme.of(context).textTheme.bodyMedium,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// lib/features/lecture/presentation/pages/lecture_menu.dart

// === CÁC IMPORT ĐƯỢC GIỮ LẠI ===
import 'package:attendify/app/providers/navigation_provider.dart';
import 'package:attendify/features/schedule/presentation/pages/schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../../../app/providers/auth_provider.dart';
import '../../../auth/presentation/pages/edit_account_page.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../common/data/models/class_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../../admin/data/services/admin_service.dart';
import '../../../schedule/data/services/schedule_service.dart';
import '../../../schedule/domain/reminder_scheduler.dart';

// === IMPORT MỚI ĐỂ ĐIỀU HƯỚNG ===
import '../../../classes/presentation/pages/class_detail_page.dart';

class LectureMenuPage extends StatefulWidget {
  const LectureMenuPage({super.key});

  @override
  State<LectureMenuPage> createState() => _LectureMenuPageState();
}

class _LectureMenuPageState extends State<LectureMenuPage> {
  @override
  void initState() {
    super.initState();
    // Đặt thông báo nhắc lịch cho giảng viên đang đăng nhập (Logic này được giữ nguyên)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final schedule = context.read<ScheduleService>();
          ReminderScheduler(
            schedule,
          ).rescheduleForUser(uid: uid, isLecturer: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // === ĐƠN GIẢN HÓA: LOẠI BỎ CONSUMER VÀ SWITCH ===
    // Trang này giờ đây chỉ hiển thị menu chính.
    return const MainMenuScaffold();
  }
}

// === BIẾN MAINMENUSCAFFOLD THÀNH STATEFULWIDGET ĐỂ QUẢN LÝ STATE ===
class MainMenuScaffold extends StatefulWidget {
  const MainMenuScaffold({super.key});

  @override
  State<MainMenuScaffold> createState() => _MainMenuScaffoldState();
}

class _MainMenuScaffoldState extends State<MainMenuScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = <DrawerDestination>[
      DrawerDestination(
        icon: Icons.dashboard_outlined,
        label: 'Tổng quan (giảng viên)',
      ),
      DrawerDestination(
        icon: Icons.calendar_month_outlined,
        label: 'Thời khoá biểu',
      ),
      DrawerDestination(icon: Icons.school_outlined, label: 'Lớp học của tôi'),
      const DrawerDestination(
        icon: Icons.person_outline,
        label: 'Thông tin cá nhân',
      ),
    ];

    final pages = <Widget>[
      const _DashboardPage(),
      const _ScheduleListPage(),
      const _LecturerAndStudentClassList(), // Trang danh sách lớp học
      _ProfilePage(),
    ];

    return RoleDrawerScaffold(
      title: 'Giảng viên',
      destinations: destinations,
      pages: pages,
      currentIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      drawerHeader: const _DrawerHeader(role: 'Giảng viên'),
    );
  }
}

// === XÓA BỎ HOÀN TOÀN: ClassContextMenuScaffold ===
// Không còn cần thiết vì đã bỏ menu con

/// Drawer shell (Giữ nguyên không thay đổi)
class RoleDrawerScaffold extends StatelessWidget {
  final String title;
  final List<DrawerDestination> destinations;
  final List<Widget> pages;
  final int currentIndex;
  final Function(int) onDestinationSelected;
  final Widget? drawerHeader;

  const RoleDrawerScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.pages,
    this.currentIndex = 0,
    required this.onDestinationSelected,
    this.drawerHeader,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(destinations[currentIndex].label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              if (drawerHeader != null) drawerHeader!,
              // Phần tiêu đề nhỏ trong drawer (giữ lại cho thẩm mỹ)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: destinations.length,
                  itemBuilder: (context, i) {
                    final d = destinations[i];
                    final selected = i == currentIndex;
                    return ListTile(
                      leading: Icon(
                        d.icon,
                        color: selected ? color.primary : null,
                      ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          color: selected ? color.primary : null,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      selected: selected,
                      selectedTileColor: color.primaryContainer.withAlpha(64),
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(i);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await context.read<AuthProvider>().logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: currentIndex, children: pages),
    );
  }
}

class DrawerDestination {
  final IconData icon;
  final String label;
  const DrawerDestination({required this.icon, required this.label});
}

// Drawer Headers (Giữ nguyên)

class _DrawerHeader extends StatelessWidget {
  final String role;
  const _DrawerHeader({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return UserAccountsDrawerHeader(
      accountName: const Text('Attendify'),
      accountEmail: Text(role),
      currentAccountPicture: CircleAvatar(
        backgroundColor: color.primaryContainer,
        child: Icon(Icons.person, color: color.onPrimaryContainer),
      ),
    );
  }
}

// === XÓA BỎ HOÀN TOÀN: _ClassContextHeader ===
// Không còn cần thiết vì đã bỏ menu con

// Dashboard Page
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_LecturerDashboardStats(classService: classService)],
        ),
      ),
    );
  }
}

class _LecturerDashboardStats extends StatelessWidget {
  final ClassService classService;
  const _LecturerDashboardStats({required this.classService});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lecturerUid = auth.user?.uid;
    if (lecturerUid == null) return const SizedBox.shrink();

    // <<<--- THAY ĐỔI: STREAMBUILDER SỬ DỤNG RICHCLASSMODEL ---<<<
    return StreamBuilder<List<RichClassModel>>(
      stream: classService.getRichClassesStreamForLecturer(lecturerUid),
      builder: (context, snapshot) {
        final myClasses = snapshot.data ?? [];
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Lớp của tôi',
                value: '${myClasses.length}',
                icon: Icons.class_,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: _StatCard(
                title: 'Sinh viên',
                value: '...', // Cần logic mới để đếm tổng SV
                icon: Icons.people,
                color: Colors.purple,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ClassListPage extends StatelessWidget {
  const _ClassListPage();
  @override
  Widget build(BuildContext context) => const _LecturerAndStudentClassList();
}

class _ScheduleListPage extends StatelessWidget {
  const _ScheduleListPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
    }
    return SchedulePage(
      currentUid: currentUser.uid,
      isLecturer: auth.role == UserRole.lecture,
    );
  }
}

// === CẬP NHẬT LOGIC ĐIỀU HƯỚNG TRONG WIDGET NÀY ===
class _LecturerAndStudentClassList extends StatelessWidget {
  const _LecturerAndStudentClassList();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classService = context.read<ClassService>();

    Stream<List<RichClassModel>> getClassStream() {
      if (auth.role == UserRole.lecture) {
        return classService.getRichClassesStreamForLecturer(auth.user!.uid);
      } else {
        return classService.getRichEnrolledClassesStream(auth.user!.uid);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách lớp học của tôi'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<RichClassModel>>(
        stream: getClassStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final richClasses = snap.data ?? [];
          if (richClasses.isEmpty) {
            return const Center(child: Text('Bạn chưa có lớp học nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: richClasses.length,
            itemBuilder: (context, index) {
              final richClass = richClasses[index];
              final classInfo = richClass.classInfo;
              final courses = richClass.courses;
              final leadingText = classInfo.classCode.isNotEmpty
                  ? classInfo.classCode[0].toUpperCase()
                  : 'L';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Text(leadingText)),
                  title: Text(
                    '${classInfo.classCode} - ${classInfo.className}',
                  ),
                  subtitle: Text(courses.map((c) => c.courseCode).join(' | ')),
                  trailing: const Icon(Icons.chevron_right),
                  // === THAY ĐỔI QUAN TRỌNG NHẤT ===
                  onTap: () {
                    // Sử dụng Navigator.push để mở trang chi tiết
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassDetailPage(
                          classId: classInfo.id,
                          // className không còn cần thiết vì ClassDetailPage tự lấy
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminClassList extends StatefulWidget {
  @override
  State<_AdminClassList> createState() => _AdminClassListState();
}

class _AdminClassListState extends State<_AdminClassList> {
  String? _selectedLecturerUid;
  @override
  Widget build(BuildContext context) {
    // <<<--- THAY ĐỔI 1: LẤY CẢ HAI SERVICE CẦN THIẾT ---<<<
    final classService = context.read<ClassService>();
    final adminService = context.read<AdminService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          // <<<--- THAY ĐỔI 2: SỬA LẠI STREAM LẤY GIẢNG VIÊN ---<<<
          child: StreamBuilder<List<UserModel>>(
            // <<<--- Đổi thành UserModel
            stream: adminService
                .getAllLecturersStream(), // <<<--- Gọi hàm từ AdminService
            builder: (context, snap) {
              final lecturers = snap.data ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedLecturerUid,
                hint: const Text('Lọc theo giảng viên'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tất cả giảng viên'),
                  ),
                  ...lecturers.map(
                    (lecturer) => DropdownMenuItem<String>(
                      value: lecturer.uid,
                      child: Text(
                        '${lecturer.displayName} — ${lecturer.email}',
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedLecturerUid = v),
              );
            },
          ),
        ),

        // <<<--- THAY ĐỔI 3: SỬA LẠI STREAMBUILDER CHÍNH VỚI RICHCLASSMODEL ---<<<
        Expanded(
          child: StreamBuilder<List<RichClassModel>>(
            // <<<--- Đổi thành RichClassModel
            stream: _selectedLecturerUid == null
                ? classService.getRichClassesStream()
                : classService.getRichClassesStreamForLecturer(
                    _selectedLecturerUid!,
                  ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Lỗi: ${snap.error}'));
              }
              final richClasses = snap.data ?? [];
              if (richClasses.isEmpty) {
                return const Center(child: Text('Không có lớp học nào'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: richClasses.length,
                itemBuilder: (context, index) {
                  // <<<--- THAY ĐỔI 4: BÓC TÁCH VÀ HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ---<<<
                  final richClass = richClasses[index];
                  final classInfo = richClass.classInfo;
                  final courses = richClass.courses;
                  final lecturer = richClass.lecturer;

                  final leadingText = classInfo.classCode.isNotEmpty
                      ? classInfo.classCode[0].toUpperCase()
                      : 'L';

                  final courseCodes = courses
                      .map((c) => c.courseCode)
                      .join(' | ');

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(leadingText)),
                      title: Text(
                        '${classInfo.classCode} - ${classInfo.className}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseCodes,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('GV: ${lecturer?.displayName ?? "..."}'),
                          Text('Mã tham gia: ${classInfo.joinCode}'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: true,
                      onTap: () {
                        // Điều hướng sang màn hình ngữ cảnh của lớp học
                        context
                            .read<NavigationProvider>()
                            .navigateToClassContext(
                              classId: classInfo.id,
                              className: classInfo.className,
                            );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin tài khoản',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (user?.displayName?.isNotEmpty == true)
                        ? user!.displayName![0].toUpperCase()
                        : 'U',
                  ),
                ),
                title: Text(user?.displayName ?? 'Chưa có tên'),
                subtitle: Text(user?.email ?? 'Chưa có email'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final ok = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditAccountPage(
                          currentName: user?.displayName ?? '',
                          currentPhotoUrl: user?.photoURL,
                        ),
                      ),
                    );
                    if (ok == true) {
                      // reload nếu cần
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.badge),
                title: Text('Vai trò'),
                subtitle: Text('Giảng viên'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// === XÓA BỎ TOÀN BỘ CÁC WIDGET CON CỦA MENU CŨ ===
// _SessionListPage, _QRAttendancePage, _LeaveRequestPage đã được xóa khỏi file này.