import 'package:flutter/material.dart';
import '../../../data/models/session_model.dart';
import '../../../services/firebase/session_service.dart';
import 'weekly_schedule_widget.dart';

class NextSessionCard extends StatelessWidget {
  final String userId;
  final bool isLecturer;
  final SessionService sessionService;

  const NextSessionCard({
    super.key,
    required this.userId,
    required this.isLecturer,
    required this.sessionService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionModel?>(
      future: sessionService.getNextSession(userId, isLecturer: isLecturer),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final nextSession = snapshot.data;
        if (nextSession == null) {
          return Card(
            margin: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Không có buổi học nào sắp tới',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLecturer
                              ? 'Tạo buổi học mới để bắt đầu'
                              : 'Thưởng thức thời gian rảnh rỗi!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final timeUntil = nextSession.timeUntilStart;
        final isUrgent = timeUntil != null && timeUntil.inMinutes <= 30;
        final isToday = nextSession.startTime.day == DateTime.now().day;

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          color: isUrgent
              ? Colors.orange[50]
              : isToday
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
              : null,
          child: InkWell(
            onTap: () => _showSessionDetail(context, nextSession),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isUrgent ? Icons.warning : Icons.schedule,
                        color: isUrgent ? Colors.orange[700] : Colors.blue[600],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUrgent
                            ? 'BUỔI HỌC SẮP BẮT ĐẦU!'
                            : 'Buổi học tiếp theo',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isUrgent
                              ? Colors.orange[700]
                              : Colors.blue[600],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (timeUntil != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? Colors.orange[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatTimeUntil(timeUntil),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isUrgent
                                      ? Colors.orange[700]
                                      : Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    nextSession.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.class_, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${nextSession.classCode} • ${nextSession.className}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nextSession.timeRangeString,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nextSession.location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  if (nextSession.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      nextSession.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeUntil(Duration duration) {
    if (duration.inDays > 0) {
      return 'Còn ${duration.inDays} ngày';
    } else if (duration.inHours > 0) {
      return 'Còn ${duration.inHours} giờ';
    } else if (duration.inMinutes > 0) {
      return 'Còn ${duration.inMinutes} phút';
    } else {
      return 'Bắt đầu ngay!';
    }
  }

  void _showSessionDetail(BuildContext context, SessionModel session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SessionDetailBottomSheet(session: session),
    );
  }
}
