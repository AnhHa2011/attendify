import 'package:flutter/material.dart';
import '../../../data/models/session_model.dart';
import '../../../services/firebase/session_service.dart';

class WeeklyScheduleWidget extends StatelessWidget {
  final String userId;
  final bool isLecturer;
  final DateTime selectedWeek;
  final SessionService sessionService;
  final ValueChanged<DateTime> onWeekChanged;

  const WeeklyScheduleWidget({
    super.key,
    required this.userId,
    required this.isLecturer,
    required this.selectedWeek,
    required this.sessionService,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Week navigation
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  final previousWeek = selectedWeek.subtract(
                    const Duration(days: 7),
                  );
                  onWeekChanged(previousWeek);
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _formatWeekRange(selectedWeek),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () {
                  final nextWeek = selectedWeek.add(const Duration(days: 7));
                  onWeekChanged(nextWeek);
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        // Week calendar
        Expanded(
          child: StreamBuilder<List<SessionModel>>(
            stream: sessionService.getWeeklySchedule(
              userId,
              selectedWeek,
              isLecturer: isLecturer,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
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
                      Text('Lỗi: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final sessions = snapshot.data ?? [];
              return WeekCalendarView(
                selectedWeek: selectedWeek,
                sessions: sessions,
                isLecturer: isLecturer,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatWeekRange(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    if (weekStart.month == weekEnd.month) {
      return '${weekStart.day} - ${weekEnd.day} tháng ${weekStart.month}/${weekStart.year}';
    } else {
      return '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}/${weekStart.year}';
    }
  }
}

class WeekCalendarView extends StatelessWidget {
  final DateTime selectedWeek;
  final List<SessionModel> sessions;
  final bool isLecturer;

  const WeekCalendarView({
    super.key,
    required this.selectedWeek,
    required this.sessions,
    required this.isLecturer,
  });

  @override
  Widget build(BuildContext context) {
    final weekDays = List.generate(7, (index) {
      return selectedWeek.add(Duration(days: index));
    });

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tuần này không có lịch học',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Thời gian tự do để nghiên cứu và chuẩn bị',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weekDays.length,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final daySessions =
            sessions
                .where(
                  (session) =>
                      session.startTime.day == day.day &&
                      session.startTime.month == day.month &&
                      session.startTime.year == day.year,
                )
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        return DayScheduleCard(
          date: day,
          sessions: daySessions,
          isLecturer: isLecturer,
        );
      },
    );
  }
}

class DayScheduleCard extends StatelessWidget {
  final DateTime date;
  final List<SessionModel> sessions;
  final bool isLecturer;

  const DayScheduleCard({
    super.key,
    required this.date,
    required this.sessions,
    required this.isLecturer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;
    final weekdays = [
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'CN',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 3 : 1,
      color: isToday
          ? theme.colorScheme.primaryContainer.withOpacity(0.1)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Text(
                  weekdays[date.weekday],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isToday
                        ? theme.colorScheme.primary
                        : Colors.grey[600],
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Hôm nay',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (sessions.isNotEmpty)
                  Text(
                    '${sessions.length} buổi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),

            if (sessions.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Không có lịch học',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...sessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WeekSessionTile(
                    session: session,
                    isLecturer: isLecturer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WeekSessionTile extends StatelessWidget {
  final SessionModel session;
  final bool isLecturer;

  const WeekSessionTile({
    super.key,
    required this.session,
    required this.isLecturer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOngoing = session.isNow;
    final isPast = now.isAfter(session.endTime);

    Color getStatusColor() {
      if (isOngoing) return Colors.green;
      if (isPast) return Colors.grey;
      return Colors.blue;
    }

    return InkWell(
      onTap: () => _showSessionDetail(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: getStatusColor().withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: getStatusColor().withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  session.timeRangeString,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.typeDisplayName,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              session.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SessionDetailBottomSheet(session: session),
    );
  }
}

// Required import for SessionDetailBottomSheet
// (This would be in the actual schedule_page.dart file)
class SessionDetailBottomSheet extends StatelessWidget {
  final SessionModel session;

  const SessionDetailBottomSheet({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // Implementation from the previous artifact
    return Container(
      height: 300,
      child: Center(child: Text('Session Detail: ${session.title}')),
    );
  }
}
