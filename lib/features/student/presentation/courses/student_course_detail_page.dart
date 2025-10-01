// lib/features/student/presentation/courses/student_course_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../../core/data/models/rich_course_model.dart';
import '../../../../core/data/services/courses_service.dart';
import '../../data/models/student_attendance_stats.dart';
import '../../data/models/student_session_detail.dart';
import '../../data/services/student_service.dart';
import '../widgets/attendance_stats_card.dart';
import '../widgets/session_detail_tile.dart';

class StudentCourseDetailPage extends StatefulWidget {
  final String courseCode;

  const StudentCourseDetailPage({super.key, required this.courseCode});

  @override
  State<StudentCourseDetailPage> createState() =>
      _StudentCourseDetailPageState();
}

class _StudentCourseDetailPageState extends State<StudentCourseDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _studentService = StudentService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final studentId = auth.user?.uid;
    final courseService = context.read<CourseService>();

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Chi tiết môn học'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return StreamBuilder<RichCourseModel?>(
      stream: courseService.getRichCourseStream(widget.courseCode),
      builder: (context, courseSnapshot) {
        if (courseSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Chi tiết môn học'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (courseSnapshot.hasError || !courseSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Chi tiết môn học'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Không thể tải thông tin môn học'),
                ],
              ),
            ),
          );
        }

        final richCourse = courseSnapshot.data!;
        final courseInfo = richCourse.courseInfo;

        return Scaffold(
          appBar: AppBar(
            title: Text(courseInfo.courseCode),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Thông tin'),
                Tab(text: 'Điểm danh'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _CourseInfoTab(richCourse: richCourse, studentId: studentId),
              _AttendanceTab(
                courseCode: widget.courseCode,
                studentId: studentId,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseInfoTab extends StatelessWidget {
  final RichCourseModel richCourse;
  final String studentId;

  const _CourseInfoTab({required this.richCourse, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final courseInfo = richCourse.courseInfo;
    final lecturer = richCourse.lecturer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.class_,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseInfo.courseCode,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              courseInfo.courseName,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // CourseModel không có description field hiện tại
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Course Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.book, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Môn học',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lecturer Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Giảng viên',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (lecturer == null)
                    Text(
                      'Chưa có giảng viên được phân công.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.person, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lecturer.displayName ?? 'N/A',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (lecturer.email != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lecturer.email!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Course Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Thông tin khác',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    context,
                    'Mã tham gia',
                    courseInfo.joinCode,
                    Icons.key,
                  ),

                  _buildInfoRow(
                    context,
                    'Ngày tạo',
                    DateFormat('dd/MM/yyyy HH:mm').format(courseInfo.createdAt),
                    Icons.calendar_today,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  final String courseCode;
  final String studentId;
  final _studentService = StudentService();

  _AttendanceTab({required this.courseCode, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats Section
        FutureBuilder<StudentAttendanceStats>(
          future: _studentService.getCourseAttendanceStats(
            studentId,
            courseCode,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final stats = snapshot.data ?? StudentAttendanceStats.empty();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: AttendanceStatsCard(stats: stats),
            );
          },
        ),

        // Sessions List
        Expanded(
          child: StreamBuilder<List<StudentSessionDetail>>(
            stream: _studentService.getCourseAttendanceHistory(
              studentId,
              courseCode,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                          'Không thể tải lịch sử điểm danh',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sessions = snapshot.data ?? [];

              if (sessions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có buổi học nào',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lịch sử điểm danh sẽ hiển thị ở đây khi có buổi học.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return SessionDetailTile(session: session);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
