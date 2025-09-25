// lib/features/student/presentation/attendance/student_attendance_history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../data/models/student_session_detail.dart';
import '../../data/models/student_attendance_stats.dart';
import '../../data/services/student_service.dart';
import '../widgets/attendance_stats_card.dart';
import '../widgets/session_detail_tile.dart';

class StudentAttendanceHistoryPage extends StatefulWidget {
  const StudentAttendanceHistoryPage({super.key});

  @override
  State<StudentAttendanceHistoryPage> createState() =>
      _StudentAttendanceHistoryPageState();
}

class _StudentAttendanceHistoryPageState
    extends State<StudentAttendanceHistoryPage>
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

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Lịch sử điểm danh'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử điểm danh'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Thống kê'),
            Tab(text: 'Chi tiết'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StatisticsTab(studentId: studentId),
          _HistoryTab(studentId: studentId),
        ],
      ),
    );
  }
}

class _StatisticsTab extends StatelessWidget {
  final String studentId;
  final _studentService = StudentService();

  _StatisticsTab({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentAttendanceStats>(
      future: _studentService.getAttendanceStats(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                    'Không thể tải thống kê',
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

        final stats = snapshot.data ?? StudentAttendanceStats.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AttendanceStatsCard(stats: stats),
              const SizedBox(height: 24),
              Text(
                'Phân tích chi tiết',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                context,
                'Tổng số buổi học',
                stats.totalSessions.toString(),
                Icons.calendar_month,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDetailCard(
                context,
                'Có mặt',
                stats.presentCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildDetailCard(
                context,
                'Vắng mặt',
                stats.absentCount.toString(),
                Icons.cancel,
                Colors.red,
              ),
              const SizedBox(height: 12),
              _buildDetailCard(
                context,
                'Nghỉ phép',
                stats.leaveRequestCount.toString(),
                Icons.event_busy,
                Colors.orange,
              ),
              const SizedBox(height: 24),
              if (stats.totalSessions > 0) ...[
                Text(
                  'Lời khuyên',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildAdviceCard(context, stats),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildAdviceCard(BuildContext context, StudentAttendanceStats stats) {
    String advice;
    Color cardColor;
    IconData cardIcon;

    if (stats.attendanceRate >= 90) {
      advice = 'Xuất sắc! Bạn có tỷ lệ tham dự rất cao. Hãy tiếp tục duy trì.';
      cardColor = Colors.green;
      cardIcon = Icons.emoji_events;
    } else if (stats.attendanceRate >= 80) {
      advice = 'Tốt! Tỷ lệ tham dự của bạn ổn định. Cố gắng cải thiện thêm.';
      cardColor = Colors.blue;
      cardIcon = Icons.thumb_up;
    } else if (stats.attendanceRate >= 70) {
      advice = 'Cần cải thiện. Hãy cố gắng tham dự đều đặn hơn.';
      cardColor = Colors.orange;
      cardIcon = Icons.warning;
    } else {
      advice =
          'Cảnh báo! Tỷ lệ tham dự thấp. Bạn nên tăng cường tham gia lớp học.';
      cardColor = Colors.red;
      cardIcon = Icons.error;
    }

    return Card(
      color: cardColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(cardIcon, color: cardColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                advice,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cardColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final String studentId;
  final _studentService = StudentService();

  _HistoryTab({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentSessionDetail>>(
      stream: _studentService.getAttendanceHistory(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                    'Không thể tải lịch sử',
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử điểm danh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lịch sử điểm danh sẽ hiển thị ở đây khi bạn tham gia các buổi học.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Nhóm sessions theo ngày
        final groupedSessions = _groupSessionsByDate(sessions);
        final dates = groupedSessions.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];
            final daySessions = groupedSessions[date]!;
            final dateStr = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...daySessions.map(
                  (session) => SessionDetailTile(session: session),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Map<DateTime, List<StudentSessionDetail>> _groupSessionsByDate(
    List<StudentSessionDetail> sessions,
  ) {
    final Map<DateTime, List<StudentSessionDetail>> grouped = {};

    for (final session in sessions) {
      final date = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(session);
    }

    // Sort sessions within each day by start time
    for (final sessions in grouped.values) {
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return grouped;
  }
}
