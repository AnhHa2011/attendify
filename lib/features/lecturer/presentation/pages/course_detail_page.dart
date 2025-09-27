import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/lecturer_service.dart';
import '../../models/class_session.dart';
import 'session_create_screen.dart';
import 'attendance_detail_screen.dart';

class CourseDetail extends StatefulWidget {
  final String courseCode;

  const CourseDetail({Key? key, required this.courseCode}) : super(key: key);

  @override
  State<CourseDetail> createState() => _CourseDetailState();
}

class _CourseDetailState extends State<CourseDetail>
    with TickerProviderStateMixin {
  final LecturerService _lecturerService = LecturerService();
  late TabController _tabController;

  Map<String, dynamic>? courseDetails;
  List<ClassSession> sessions = [];
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic> statistics = {};

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Mock data for demonstration
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        courseDetails = {
          'id': widget.courseCode,
          'name': 'Lập trình Flutter',
          'code': 'CS101',
          'description':
              'Khóa học lập trình ứng dụng di động với Flutter framework',
          'credits': 3,
          'enrollmentCount': 25,
          'joinCode': '123456',
        };

        statistics = {
          'totalSessions': 12,
          'completedSessions': 8,
          'upcomingSessions': 4,
          'averageAttendance': 85.5,
        };

        students = [
          {
            'id': '1',
            'name': 'Nguyễn Văn A',
            'email': 'nguyenvana@email.com',
            'studentId': 'SV001',
          },
          {
            'id': '2',
            'name': 'Trần Thị B',
            'email': 'tranthib@email.com',
            'studentId': 'SV002',
          },
          {
            'id': '3',
            'name': 'Lê Văn C',
            'email': 'levanc@email.com',
            'studentId': 'SV003',
          },
        ];

        isLoading = false;
      });

      // Load real sessions
      _lecturerService.getCourseSessions(widget.courseCode).listen((
        sessionList,
      ) {
        if (mounted) {
          setState(() {
            sessions = sessionList;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(courseDetails?['name'] ?? 'Chi tiết môn học'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tổng quan', icon: Icon(Icons.dashboard)),
            Tab(text: 'Buổi học', icon: Icon(Icons.schedule)),
            Tab(text: 'Sinh viên', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSessionsTab(),
                _buildStudentsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SessionCreate(courseCode: widget.courseCode),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Tạo buổi học mới',
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Không thể tải thông tin môn học',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCourseData,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (courseDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.school,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseDetails!['code'] ?? '',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              courseDetails!['name'] ?? '',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mô tả:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    courseDetails!['description'] ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // Course Stats
                  Row(
                    children: [
                      _buildStatItem('Tín chỉ', '${courseDetails!['credits']}'),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        'Sinh viên',
                        '${courseDetails!['enrollmentCount']}',
                      ),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        'Buổi học',
                        '${statistics['totalSessions']}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Join Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.key,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Mã tham gia: '),
                        Text(
                          courseDetails!['joinCode'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: courseDetails!['joinCode'] ?? '',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép mã tham gia'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return sessions.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có buổi học nào'),
                SizedBox(height: 8),
                Text('Nhấn nút + để tạo buổi học mới'),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _buildSessionCard(session);
            },
          );
  }

  Widget _buildStudentsTab() {
    return students.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có sinh viên nào đăng ký'),
                SizedBox(height: 8),
                Text('Chia sẻ mã tham gia để sinh viên tham gia lớp'),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = students[index];
              return _buildStudentCard(student);
            },
          );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSessionCard(ClassSession session) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getSessionStatusColor(session).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getSessionStatusIcon(session),
            color: _getSessionStatusColor(session),
            size: 20,
          ),
        ),
        title: Text(
          session.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd/MM/yyyy - HH:mm').format(session.startTime)),
            Text(session.location),
          ],
        ),
        trailing: Chip(
          label: Text(session.statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: _getSessionStatusColor(session).withOpacity(0.1),
          labelStyle: TextStyle(
            color: _getSessionStatusColor(session),
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          if (session.isFinished) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceDetail(session: session),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          child: Text(
            student['name']?.isNotEmpty == true
                ? student['name'][0].toUpperCase()
                : 'S',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student['name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student['email'] ?? ''),
            if (student['studentId']?.isNotEmpty == true)
              Text(
                'MSSV: ${student['studentId']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSessionStatusColor(ClassSession session) {
    if (session.isOngoing) return Colors.green;
    if (session.isUpcoming) return Colors.orange;
    if (session.isFinished) return Colors.grey;
    return Colors.blue;
  }

  IconData _getSessionStatusIcon(ClassSession session) {
    if (session.isOngoing) return Icons.play_circle;
    if (session.isUpcoming) return Icons.schedule;
    if (session.isFinished) return Icons.check_circle;
    return Icons.event;
  }
}
