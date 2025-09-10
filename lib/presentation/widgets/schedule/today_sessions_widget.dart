import 'package:flutter/material.dart';
import '../../../data/models/session_model.dart';
import '../../../services/firebase/session_service.dart';
import 'session_detail_bottom_sheet.dart';

class TodaySessionsWidget extends StatelessWidget {
  final String userId;
  final bool isLecturer;
  final SessionService sessionService;

  const TodaySessionsWidget({
    super.key,
    required this.userId,
    required this.isLecturer,
    required this.sessionService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionModel>>(
      stream: sessionService.getTodaySessions(userId, isLecturer: isLecturer),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        final todaySessions = snapshot.data ?? [];

        if (todaySessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.free_breakfast_outlined,
                  size: 64,
                  color: Colors.green[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Hôm nay không có lịch học',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thư giãn và tận hưởng ngày nghỉ!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.green[500]),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hôm nay có ${todaySessions.length} buổi học',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatToday(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = todaySessions[index];
                  final isNext = _isNextSession(session, todaySessions);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TodaySessionCard(
                      session: session,
                      isNext: isNext,
                      isLecturer: isLecturer,
                    ),
                  );
                }, childCount: todaySessions.length),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatToday() {
    final now = DateTime.now();
    final weekdays = [
      '',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return '${weekdays[now.weekday]}, ${now.day}/${now.month}/${now.year}';
  }

  bool _isNextSession(SessionModel session, List<SessionModel> allSessions) {
    final now = DateTime.now();
    final upcomingSessions =
        allSessions.where((s) => s.startTime.isAfter(now)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return upcomingSessions.isNotEmpty &&
        upcomingSessions.first.id == session.id;
  }
}

class TodaySessionCard extends StatelessWidget {
  final SessionModel session;
  final bool isNext;
  final bool isLecturer;

  const TodaySessionCard({
    super.key,
    required this.session,
    required this.isNext,
    required this.isLecturer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOngoing = session.isNow;
    final isPast = now.isAfter(session.endTime);

    Color getCardColor() {
      if (isOngoing) return Colors.green[50]!;
      if (isNext) return theme.colorScheme.primaryContainer.withOpacity(0.1);
      if (isPast) return Colors.grey[50]!;
      return Colors.white;
    }

    Color getBorderColor() {
      if (isOngoing) return Colors.green;
      if (isNext) return theme.colorScheme.primary;
      if (isPast) return Colors.grey;
      return Colors.transparent;
    }

    IconData getStatusIcon() {
      if (isOngoing) return Icons.play_circle_filled;
      if (isNext) return Icons.notification_important;
      if (isPast) return Icons.check_circle;
      return Icons.schedule;
    }

    Color getStatusColor() {
      if (isOngoing) return Colors.green;
      if (isNext) return Colors.orange;
      if (isPast) return Colors.grey;
      return Colors.blue;
    }

    String getStatusText() {
      if (isOngoing) return 'ĐANG DIỄN RA';
      if (isNext) return 'BUỔI TIẾP THEO';
      if (isPast) return 'ĐÃ KẾT THÚC';
      return 'SẮP DIỄN RA';
    }

    return Card(
      elevation: isNext || isOngoing ? 4 : 1,
      color: getCardColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: getBorderColor(),
          width: isNext || isOngoing ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _showSessionDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and time
              Row(
                children: [
                  Icon(getStatusIcon(), color: getStatusColor(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    getStatusText(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: getStatusColor(),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    session.timeRangeString,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                session.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Class and location info
              Row(
                children: [
                  Icon(Icons.class_, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${session.classCode} • ${session.className}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    session.location,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.typeDisplayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Time until start (if upcoming)
              if (!isPast && !isOngoing && session.timeUntilStart != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isNext ? Colors.orange[100] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isNext ? Colors.orange[700] : Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeUntil(session.timeUntilStart!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isNext ? Colors.orange[700] : Colors.blue[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons for lecturers
              if (isLecturer && (isOngoing || isNext)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isOngoing) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleAttendance(context),
                          icon: Icon(
                            session.isAttendanceOpen
                                ? Icons.qr_code
                                : Icons.qr_code_scanner,
                            size: 18,
                          ),
                          label: Text(
                            session.isAttendanceOpen
                                ? 'Đang điểm danh'
                                : 'Mở điểm danh',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: session.isAttendanceOpen
                                ? Colors.green
                                : Colors.blue,
                            side: BorderSide(
                              color: session.isAttendanceOpen
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ] else if (isNext) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _startSession(context),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Bắt đầu'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeUntil(Duration duration) {
    if (duration.inHours > 0) {
      return 'Còn ${duration.inHours} giờ ${duration.inMinutes % 60} phút';
    } else if (duration.inMinutes > 0) {
      return 'Còn ${duration.inMinutes} phút';
    } else {
      return 'Sắp bắt đầu!';
    }
  }

  void _showSessionDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SessionDetailBottomSheet(session: session),
    );
  }

  void _toggleAttendance(BuildContext context) {
    // TODO: Implement attendance toggle
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          session.isAttendanceOpen ? 'Đóng điểm danh' : 'Mở điểm danh',
        ),
      ),
    );
  }

  void _startSession(BuildContext context) {
    // TODO: Implement start session
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bắt đầu buổi học')));
  }
}
