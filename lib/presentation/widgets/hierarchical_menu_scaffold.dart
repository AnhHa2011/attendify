import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/providers/navigation_provider.dart';
import '../../app/providers/auth_provider.dart';
import '../../data/models/class_model.dart';
import '../../data/models/user_model.dart';
import '../../services/firebase/classes/class_service.dart';
import '../pages/classes/create_class_page.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/models/session_model.dart';
import '../../services/firebase/sessions/session_service.dart';
import '../pages/common/edit_account_page.dart';
import '../pages/sessions/session_detail_page.dart';
import '../pages/admin/course_management_page.dart';
import '../pages/admin/user_management_page.dart';
import '../pages/admin/user_bulk_import_page.dart';
import '../pages/classes/class_detail_page.dart';
import 'package:attendify/presentation/pages/admin/class_management_page.dart';

class HierarchicalMenuScaffold extends StatelessWidget {
  const HierarchicalMenuScaffold({super.key});

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
    final auth = context.watch<AuthProvider>();
    final navProvider = context.watch<NavigationProvider>();
    final isAdmin = auth.role?.toKey() == 'admin';

    // Xây dựng danh sách các mục menu (destinations) một cách linh động
    final destinations = <DrawerDestination>[
      // Mục chung cho cả hai vai trò
      DrawerDestination(
        icon: Icons.dashboard_outlined,
        label: isAdmin ? 'Tổng quan (admin)' : 'Tổng quan (giảng viên)',
      ),

      // Admin only
      if (isAdmin)
        const DrawerDestination(
          icon: Icons.manage_accounts,
          label: 'Quản lý tài khoản',
        ),
      if (isAdmin)
        const DrawerDestination(
          icon: Icons.menu_book_outlined,
          label: 'Quản lý môn học',
        ),

      // Mục "Lớp học" đổi tên tùy theo vai trò
      DrawerDestination(
        icon: Icons.school_outlined,
        label: isAdmin ? 'Quản lý lớp học' : 'Lớp học của tôi',
      ),

      // Mục chung
      const DrawerDestination(
        icon: Icons.person_outline,
        label: 'Thông tin cá nhân',
      ),
    ];

    // Xây dựng danh sách các trang (pages) tương ứng
    final pages = <Widget>[
      // Trang chung
      _DashboardPage(isAdmin: isAdmin),

      // Admin pages
      if (isAdmin) const UserManagementPage(),
      if (isAdmin) const CourseManagementPage(),

      // Common / role-based pages
      _ClassListPage(),
      _ProfilePage(),
    ];

    return RoleDrawerScaffold(
      title: isAdmin ? 'Admin' : 'Giảng viên',
      destinations: destinations,
      pages: pages,
      currentIndex: navProvider.currentIndex,
      onDestinationSelected: (index) {
        navProvider.setCurrentIndex(index);
      },
      drawerHeader: _DrawerHeader(role: isAdmin ? 'Admin' : 'Giảng viên'),
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
  final bool isAdmin;
  const _DashboardPage({required this.isAdmin});

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
            if (isAdmin) ...[
              _AdminDashboardStats(classService: classService),
            ] else ...[
              _LecturerDashboardStats(classService: classService),
            ],
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

class _LecturerDashboardStats extends StatelessWidget {
  final ClassService classService;
  const _LecturerDashboardStats({required this.classService});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lecturerUid = auth.user?.uid;

    if (lecturerUid == null) return const SizedBox.shrink();

    return StreamBuilder<List<ClassModel>>(
      stream: classService.classesOfLecturer(lecturerUid),
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
            Expanded(
              child: _StatCard(
                title: 'Sinh viên',
                value:
                    '${myClasses.fold<int>(0, (sum, c) => sum)}', // Tạm thời = 0
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

// Class List Page sử dụng logic phân vai trò
class _ClassListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role == UserRole.admin;

    // Admin sẽ được điều hướng đến trang quản lý đầy đủ chức năng
    if (isAdmin) {
      // Trả về trang ClassManagementPage mà chúng ta đã tạo
      return const ClassManagementPage();
    } else {
      // Giảng viên và Sinh viên sẽ thấy danh sách lớp của họ
      return _LecturerAndStudentClassList();
    }
  }
}

// Widget dành cho Giảng viên và Sinh viên (có thể tách ra nếu logic phức tạp hơn)
class _LecturerAndStudentClassList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classService = context.read<ClassService>();

    // Xác định xem nên lấy stream nào dựa trên vai trò
    Stream<List<ClassModel>> getClassStream() {
      if (auth.role == UserRole.lecture) {
        return classService.getRichClassesStreamForLecturer(auth.user!.uid);
      } else {
        // Mặc định là sinh viên
        return classService.getRichEnrolledClassesStream(auth.user!.uid);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách lớp học của tôi'),
        automaticallyImplyLeading: false, // Ẩn nút back nếu không cần
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: getClassStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) {
            return const Center(child: Text('Bạn chưa có lớp học nào.'));
          }

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classItem = classes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      classItem.courseCode?.isNotEmpty == true
                          ? classItem.courseCode!.substring(0, 2).toUpperCase()
                          : 'C',
                    ),
                  ),
                  title: Text(
                    '${classItem.courseCode ?? "N/A"} • ${classItem.courseName ?? "..."}',
                  ),
                  subtitle: Text('GV: ${classItem.lecturerName ?? "..."}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassDetailPage(classId: classItem.id),
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

// === ADMIN CLASS LIST - ĐÃ SỬA LỖI VÀ HOÀN THIỆN ===
class _AdminClassList extends StatefulWidget {
  @override
  State<_AdminClassList> createState() => _AdminClassListState();
}

class _AdminClassListState extends State<_AdminClassList> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return Column(
      children: [
        // Filter theo giảng viên
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: StreamBuilder<List<Map<String, String>>>(
            stream: classService.lecturersStream(),
            builder: (context, snap) {
              final list = snap.data ?? [];
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
                  ...list.map(
                    (m) => DropdownMenuItem<String>(
                      value: m['uid'],
                      child: Text('${m['name']} — ${m['email']}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedLecturerUid = v),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Danh sách lớp học
        Expanded(
          child: StreamBuilder<List<ClassModel>>(
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
              final classes = snap.data ?? [];
              if (classes.isEmpty) {
                return const Center(child: Text('Không có lớp học nào'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classItem = classes[index];

                  // === LOGIC AN TOÀN CHO SUBSTRING ===
                  String leadingText;
                  final code = classItem.courseCode;
                  if (code == null || code.isEmpty) {
                    leadingText = 'C';
                  } else if (code.length < 2) {
                    leadingText = code.toUpperCase();
                  } else {
                    leadingText = code.substring(0, 2).toUpperCase();
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(leadingText)),
                      title: Text(
                        '${classItem.courseCode ?? "N/A"} • ${classItem.courseName ?? "..."}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GV: ${classItem.lecturerName ?? "..."}'),
                          Text('Mã tham gia: ${classItem.joinCode}'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassDetailPage(classId: classItem.id),
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

// === LECTURER CLASS LIST - ĐÃ SỬA LỖI VÀ HOÀN THIỆN ===
class _LecturerClassList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final auth = context.read<AuthProvider>();
    final lecturerUid = auth.user?.uid;

    if (lecturerUid == null) {
      return const Center(
        child: Text('Lỗi: Không tìm thấy thông tin người dùng'),
      );
    }

    return StreamBuilder<List<ClassModel>>(
      stream: classService.getRichClassesStreamForLecturer(lecturerUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Lỗi: ${snap.error}'));
        }
        final classes = snap.data ?? [];
        if (classes.isEmpty) {
          return const Center(
            child: Text('Bạn chưa được phân công lớp học nào.'),
          );
        }

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final classItem = classes[index];

            // === LOGIC AN TOÀN CHO SUBSTRING ===
            String leadingText;
            final code = classItem.courseCode;
            if (code == null || code.isEmpty) {
              leadingText = 'C';
            } else if (code.length < 2) {
              leadingText = code.toUpperCase();
            } else {
              leadingText = code.substring(0, 2).toUpperCase();
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text(leadingText)),
                title: Text(
                  '${classItem.courseCode ?? "N/A"} • ${classItem.courseName ?? "..."}',
                ),
                subtitle: Text('Học kỳ: ${classItem.semester}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassDetailPage(classId: classItem.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
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
                subtitle: Text(_getRoleDisplayName(auth.role)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return 'Quản trị viên';
      case UserRole.lecture:
        return 'Giảng viên';
      case UserRole.student:
        return 'Sinh viên';
      default:
        return 'Chưa xác định';
    }
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
      // === CẤU TRÚC LẠI HOÀN TOÀN HÀM BUILD ===
      // StreamBuilder lấy thông tin lớp học sẽ bao bọc toàn bộ nội dung
      body: StreamBuilder<ClassModel>(
        stream: classService.getRichClassStream(widget.classId),
        builder: (context, classSnapshot) {
          // Xử lý trạng thái tải và lỗi của thông tin lớp học trước
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
          // Khi đã có thông tin lớp, ta lưu vào biến classData
          final classData = classSnapshot.data!;

          // Bây giờ, ta xây dựng giao diện dựa trên classData đã có
          return Column(
            children: [
              // --- PHẦN HEADER THÔNG TIN LỚP VÀ NÚT TẠO BUỔI HỌC ---
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
                        title: Text(classData.courseName ?? '...'),
                        subtitle: Text(
                          'Mã: ${classData.courseCode ?? "..."} • GV: ${classData.lecturerName ?? "..."}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- PHẦN DANH SÁCH CÁC BUỔI HỌC ---
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
                            // === THAY ĐỔI QUAN TRỌNG NHẤT: TRUYỀN CÁC ĐỐI TƯỢNG ĐẦY ĐỦ ===
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailPage(
                                    session:
                                        session, // Truyền cả đối tượng session
                                    classInfo:
                                        classData, // Truyền đối tượng classData từ StreamBuilder cha
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
