// lib/presentation/widgets/hierarchical_menu_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/providers/navigation_provider.dart';
import '../../app/providers/auth_provider.dart';
import '../../data/models/class_model.dart';
import '../../data/models/user_model.dart';
import '../../services/firebase/class_service.dart';
import '../pages/classes/create_class_page.dart';

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

    final destinations = <DrawerDestination>[
      const DrawerDestination(
        icon: Icons.dashboard_outlined,
        label: 'Tổng quan',
      ),
      const DrawerDestination(icon: Icons.school_outlined, label: 'Lớp học'),
      const DrawerDestination(icon: Icons.person_outline, label: 'Tài khoản'),
    ];

    final pages = <Widget>[
      _DashboardPage(isAdmin: isAdmin),
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
            Text(
              isAdmin ? 'Dashboard Admin' : 'Dashboard Giảng viên',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

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

// Class List Page using ClassService directly
class _ClassListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role?.toKey() == 'admin';

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Danh sách lớp học',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(child: isAdmin ? _AdminClassList() : _LecturerClassList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClassPage()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Tạo lớp mới',
      ),
    );
  }
}

// Admin class list với filter - using ClassService directly
class _AdminClassList extends StatefulWidget {
  @override
  State<_AdminClassList> createState() => _AdminClassListState();
}

class _AdminClassListState extends State<_AdminClassList> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final navProvider = context.read<NavigationProvider>();

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
                ? classService.allClasses()
                : classService.classesOfLecturer(_selectedLecturerUid!),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text('Lỗi: ${snap.error}'),
                    ],
                  ),
                );
              }

              final classes = snap.data ?? [];
              if (classes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Không có lớp học nào'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classItem = classes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          classItem.classCode.isNotEmpty
                              ? classItem.classCode
                                    .substring(0, 2)
                                    .toUpperCase()
                              : 'C',
                        ),
                      ),
                      title: Text(
                        '${classItem.classCode} • ${classItem.className}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GV: ${classItem.lecturerName}'),
                          Text('Mã tham gia: ${classItem.joinCode}'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: true,
                      onTap: () {
                        navProvider.navigateToClassContext(
                          classId: classItem.id,
                          className:
                              '${classItem.classCode} - ${classItem.className}',
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

// Lecturer class list - using ClassService directly
class _LecturerClassList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final navProvider = context.read<NavigationProvider>();
    final auth = context.read<AuthProvider>();
    final lecturerUid = auth.user?.uid;

    if (lecturerUid == null) {
      return const Center(
        child: Text('Lỗi: Không tìm thấy thông tin người dùng'),
      );
    }

    return StreamBuilder<List<ClassModel>>(
      stream: classService.classesOfLecturer(lecturerUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Lỗi: ${snap.error}'),
              ],
            ),
          );
        }

        final classes = snap.data ?? [];
        if (classes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có lớp học nào'),
                SizedBox(height: 8),
                Text('Nhấn nút + để tạo lớp mới'),
              ],
            ),
          );
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
                    classItem.classCode.isNotEmpty
                        ? classItem.classCode.substring(0, 2).toUpperCase()
                        : 'C',
                  ),
                ),
                title: Text('${classItem.classCode} • ${classItem.className}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã tham gia: ${classItem.joinCode}'),
                    if (classItem.schedules.isNotEmpty)
                      Text(
                        'Lịch: ${_formatSchedule(classItem.schedules.first)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                isThreeLine: true,
                onTap: () {
                  navProvider.navigateToClassContext(
                    classId: classItem.id,
                    className:
                        '${classItem.classCode} - ${classItem.className}',
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatSchedule(ClassSchedule schedule) {
    final days = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return '${days[schedule.day]} ${schedule.start}-${schedule.end}';
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng đang phát triển'),
                      ),
                    );
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
class _SessionListPage extends StatelessWidget {
  final String classId;
  const _SessionListPage({required this.classId});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Buổi học',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng đang phát triển'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo buổi học'),
                ),
              ],
            ),
          ),

          // Class info
          StreamBuilder<ClassModel>(
            stream: classService.classStream(classId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final classData = snapshot.data!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.class_),
                    title: Text(classData.className),
                    subtitle: Text(
                      'Mã: ${classData.classCode} • GV: ${classData.lecturerName}',
                    ),
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
                  Icon(
                    Icons.event_note_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có buổi học nào',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn "Tạo buổi học" để bắt đầu',
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
