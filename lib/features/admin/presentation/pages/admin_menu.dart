// lib/features/admin/presentation/pages/admin_menu.dart

import 'package:attendify/features/admin/data/services/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../app/providers/navigation_provider.dart';
import '../../../auth/presentation/pages/edit_account_page.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../classes/presentation/pages/class_detail_page.dart';
import '../../../common/data/models/class_model.dart';
import '../../../common/data/models/session_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../../sessions/presentation/pages/data/services/session_service.dart';
import '../../../sessions/presentation/pages/session_detail_page.dart';
import 'class_management/class_management_page.dart';
import 'course_management/course_management_page.dart';
import 'user_management/user_management_page.dart';

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        switch (navProvider.currentLevel) {
          case NavigationLevel.main:
            return MainMenuScaffold();
          case NavigationLevel.classContext:
            return ClassContextMenuScaffold(
              classId: navProvider.selectedClassId!,
              className: navProvider.selectedClassName!,
            );
        }
      },
    );
  }
}

// Main Menu (Level 1)
class MainMenuScaffold extends StatelessWidget {
  const MainMenuScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    // Xây dựng danh sách các mục menu (destinations) một cách linh động
    final destinations = <DrawerDestination>[
      // Mục chung cho cả hai vai trò
      DrawerDestination(
        icon: Icons.dashboard_outlined,
        label: 'Tổng quan (admin)',
      ),

      const DrawerDestination(
        icon: Icons.manage_accounts,
        label: 'Quản lý tài khoản',
      ),
      const DrawerDestination(
        icon: Icons.menu_book_outlined,
        label: 'Quản lý môn học',
      ),

      // Mục "Lớp học" đổi tên tùy theo vai trò
      DrawerDestination(icon: Icons.school_outlined, label: 'Quản lý lớp học'),

      // Mục chung
      const DrawerDestination(
        icon: Icons.person_outline,
        label: 'Thông tin cá nhân',
      ),
    ];

    // Xây dựng danh sách các trang (pages) tương ứng
    final pages = <Widget>[
      // Trang chung
      _DashboardPage(),

      // Admin pages
      const UserManagementPage(),
      const CourseManagementPage(),

      // Common / role-based pages
      _ClassListPage(),
      _ProfilePage(),
    ];

    return RoleDrawerScaffold(
      title: 'Admin',
      destinations: destinations,
      pages: pages,
      currentIndex: navProvider.currentIndex,
      onDestinationSelected: (index) {
        navProvider.setCurrentIndex(index);
      },
      drawerHeader: _DrawerHeader(),
    );
  }
}

// Class Context Menu (Level 2)
class ClassContextMenuScaffold extends StatelessWidget {
  final String classId;
  final String className;

  const ClassContextMenuScaffold({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    final destinations = <DrawerDestination>[
      const DrawerDestination(
        icon: Icons.event_note_outlined,
        label: 'Buổi học',
      ),
      const DrawerDestination(
        icon: Icons.qr_code_outlined,
        label: 'QR điểm danh',
      ),
      const DrawerDestination(icon: Icons.inbox_outlined, label: 'Xin nghỉ'),
    ];

    final pages = <Widget>[
      _SessionListPage(classId: classId),
      _QRAttendancePage(classId: classId),
      _LeaveRequestPage(classId: classId),
    ];

    return RoleDrawerScaffold(
      title: className,
      destinations: destinations,
      pages: pages,
      currentIndex: navProvider.currentIndex,
      onDestinationSelected: (index) {
        navProvider.setCurrentIndex(index);
      },
      drawerHeader: _ClassContextHeader(
        className: className,
        onBackToMain: () {
          navProvider.navigateToMainLevel(index: 1); // Back to "Lớp học"
        },
      ),
    );
  }
}

// Updated RoleDrawerScaffold to support dynamic behavior
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
                      selectedTileColor: color.primaryContainer.withValues(
                        alpha: 0.25,
                      ),
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

// Drawer Headers
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return UserAccountsDrawerHeader(
      accountName: const Text('Attendify'),
      accountEmail: Text('Admin'),
      currentAccountPicture: CircleAvatar(
        backgroundColor: color.primaryContainer,
        child: Icon(Icons.person, color: color.onPrimaryContainer),
      ),
    );
  }
}

class _ClassContextHeader extends StatelessWidget {
  final String className;
  final VoidCallback onBackToMain;

  const _ClassContextHeader({
    required this.className,
    required this.onBackToMain,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      color: color.primaryContainer,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackToMain,
              ),
              title: Text(
                'Lớp học',
                style: TextStyle(fontSize: 12, color: color.onPrimaryContainer),
              ),
              subtitle: Text(
                className,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Destination model
class DrawerDestination {
  const DrawerDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

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
          children: [
            // Stats cards
            _AdminDashboardStats(classService: classService),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardStats extends StatelessWidget {
  final ClassService classService;
  const _AdminDashboardStats({required this.classService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClassModel>>(
      stream: classService.allClasses(),
      builder: (context, classSnap) {
        final totalClasses = classSnap.data?.length ?? 0;

        return StreamBuilder<List<Map<String, String>>>(
          stream: classService.lecturersStream(),
          builder: (context, lecturerSnap) {
            final totalLecturers = lecturerSnap.data?.length ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Tổng số lớp',
                    value: '$totalClasses',
                    icon: Icons.school,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Giảng viên',
                    value: '$totalLecturers',
                    icon: Icons.person,
                    color: Colors.green,
                  ),
                ),
              ],
            );
          },
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

// Class List Page sử dụng logic phân vai trò
class _ClassListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Admin sẽ được điều hướng đến trang quản lý đầy đủ chức năng
    // Trả về trang ClassManagementPage mà chúng ta đã tạo
    return const ClassManagementPage();
  }
}

// === ADMIN CLASS LIST - ĐÃ SỬA LỖI VÀ HOÀN THIỆN ===
class _AdminClassList extends StatefulWidget {
  @override
  State<_AdminClassList> createState() => _AdminClassListState();
}

class _AdminClassListState extends State<_AdminClassList> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    // === THAY ĐỔI 1: TÁCH SERVICE RA ĐỂ DÙNG LẠI ===
    // ClassService giờ chỉ dùng cho danh sách lớp
    final classService = context.read<ClassService>();
    // AdminService dùng cho danh sách giảng viên
    final adminService = context.read<AdminService>();

    return Column(
      children: [
        // === THAY ĐỔI 2: STREAM LẤY GIẢNG VIÊN TỪ ADMINSERVICE ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: StreamBuilder<List<UserModel>>(
            // <<<--- Đổi thành UserModel
            stream: adminService.getAllLecturersStream(), // <<<--- Gọi hàm mới
            builder: (context, snap) {
              final lecturers = snap.data ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedLecturerUid, // <<<--- Sửa lại thành value
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

        // === THAY ĐỔI 3: STREAMBUILDER CHÍNH SỬ DỤNG RICHCLASSMODEL ===
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
                  final richClass = richClasses[index];
                  final classInfo =
                      richClass.classInfo; // Lấy ra ClassModel gốc
                  final courses = richClass.courses; // Lấy ra danh sách môn học
                  final lecturer =
                      richClass.lecturer; // Lấy ra thông tin giảng viên

                  // === THAY ĐỔI 4: HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ===
                  String leadingText = classInfo.classCode.isNotEmpty
                      ? classInfo.classCode.substring(0, 1).toUpperCase()
                      : 'L';
                  String courseCodes = courses
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
                          // Hiển thị danh sách mã môn
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
                        // Truyền vào classId từ classInfo
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassDetailPage(classId: classInfo.id),
                          ),
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

// Profile Page
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
                      // Reload lại UI nếu cần
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Vai trò'),
                subtitle: Text('Admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Class context pages với ClassService
// 1. CHUYỂN THÀNH STATEFULWIDGET
class _SessionListPage extends StatefulWidget {
  final String classId;
  const _SessionListPage({required this.classId});

  @override
  State<_SessionListPage> createState() => _SessionListPageState();
}

// THAY THẾ TOÀN BỘ CLASS _SessionListPageState BẰNG CODE NÀY
class _SessionListPageState extends State<_SessionListPage> {
  bool _isCreatingSession = false;

  // Hàm tạo buổi học không thay đổi, nó đã đúng logic
  Future<void> _startNewAttendanceSession(ClassModel c) async {
    setState(() => _isCreatingSession = true);
    try {
      final sessionService = context.read<SessionService>();
      final String sessionId = await sessionService.createSession(
        classId: c.id,
        title:
            'Buổi học ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 90)),
        location: 'Tại lớp',
        type: SessionType.lecture,
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final qrData = '${c.id}|$sessionId||$timestamp';

      if (!mounted) return;
      await sessionService.toggleAttendance(sessionId, true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Điểm danh bằng mã QR'),
          content: SizedBox(
            width: 250,
            height: 250,
            child: QrImageView(data: qrData),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await sessionService.toggleAttendance(sessionId, false);
                Navigator.of(context).pop();
              },
              child: const Text('ĐÓNG ĐIỂM DANH'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tạo buổi học: $e')));
    } finally {
      if (mounted) setState(() => _isCreatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final sessionService = context.read<SessionService>();

    return Scaffold(
      body: StreamBuilder<RichClassModel>(
        // <<<--- THAY ĐỔI 1: Đổi thành RichClassModel
        stream: classService.getRichClassStream(widget.classId),
        builder: (context, classSnapshot) {
          if (classSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (classSnapshot.hasError || !classSnapshot.hasData) {
            return Center(
              child: Text(
                classSnapshot.error?.toString() ??
                    'Không tải được thông tin lớp',
              ),
            );
          }

          final richClass = classSnapshot.data!;
          final classData = richClass.classInfo; // Lấy ra ClassModel gốc
          final courses = richClass.courses; // Lấy ra danh sách môn học
          final lecturer = richClass.lecturer; // Lấy ra thông tin giảng viên

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Buổi học',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        FilledButton.icon(
                          // === THAY ĐỔI 2: Truyền classData (ClassModel) vào hàm ===
                          onPressed: _isCreatingSession
                              ? null
                              : () => _startNewAttendanceSession(classData),
                          icon: _isCreatingSession
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: const Text('Tạo buổi học'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.class_),
                        // === THAY ĐỔI 3: Hiển thị dữ liệu từ RichClassModel ===
                        title: Text(classData.className),
                        subtitle: Text(
                          'Môn: ${courses.map((c) => c.courseCode).join(', ')} • GV: ${lecturer?.displayName ?? "..."}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SessionModel>>(
                  stream: sessionService.sessionsOfClass(widget.classId),
                  builder: (context, sessionSnap) {
                    if (sessionSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final sessions = sessionSnap.data ?? [];
                    if (sessions.isEmpty) {
                      return const Center(
                        child: Text('Chưa có buổi học nào được tạo.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.event_available),
                            title: Text(session.title),
                            subtitle: Text(
                              'Bắt đầu: ${DateFormat.yMd().add_Hm().format(session.startTime)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailPage(
                                    session: session,
                                    // === THAY ĐỔI 4: Truyền classData (ClassModel) vào trang chi tiết ===
                                    classInfo: classData,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QRAttendancePage extends StatelessWidget {
  final String classId;
  const _QRAttendancePage({required this.classId});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'QR Điểm danh',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Class join code display
          StreamBuilder<ClassModel>(
            stream: classService.classStream(classId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final classData = snapshot.data!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Mã tham gia lớp: ${classData.joinCode}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code, size: 60),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await classService.regenerateJoinCode(classId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã tạo mã mới')),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tạo mã mới'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const CircularProgressIndicator();
            },
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đang phát triển'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Tạo QR điểm danh'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đang phát triển'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('Xem lịch sử điểm danh'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestPage extends StatelessWidget {
  final String classId;
  const _LeaveRequestPage({required this.classId});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Đơn xin nghỉ',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Class members count
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: classService.membersStream(classId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final members = snapshot.data!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: Text('Sinh viên trong lớp'),
                    trailing: Text('${members.length} người'),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có đơn xin nghỉ nào',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đơn xin nghỉ từ sinh viên sẽ hiển thị ở đây',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
