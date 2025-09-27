import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_session.dart';

class SessionDetailDialog extends StatelessWidget {
  final ClassSession session;

  const SessionDetailDialog({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(session.startTime);
    final endTime = DateFormat('HH:mm').format(session.endTime);
    final date = DateFormat('dd/MM/yyyy').format(session.startTime);
    final duration = session.duration;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          session.statusText,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: _getStatusColor().withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Description
            if (session.description.isNotEmpty) ...[
              Text(
                'Mô tả',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
            ],

            // Time and Date Info
            _buildInfoSection(
              context,
              'Thời gian',
              [
                _buildInfoRow(context, Icons.calendar_today, 'Ngày', date),
                _buildInfoRow(context, Icons.access_time, 'Giờ', '$startTime - $endTime'),
                _buildInfoRow(context, Icons.schedule, 'Thời lượng', 
                    '${duration.inHours}h ${duration.inMinutes % 60}m'),
                _buildInfoRow(context, Icons.location_on, 'Địa điểm', session.location),
              ],
            ),

            const SizedBox(height: 24),

            // Attendance Info
            _buildInfoSection(
              context,
              'Điểm danh',
              [
                _buildInfoRow(
                  context, 
                  Icons.qr_code, 
                  'Trạng thái', 
                  session.isAttendanceOpen ? 'Đang mở' : 'Đã đóng'
                ),
                if (session.qrCodeExpiry != null)
                  _buildInfoRow(
                    context,
                    Icons.timer,
                    'Hết hạn QR',
                    DateFormat('HH:mm dd/MM').format(session.qrCodeExpiry!),
                  ),
                _buildInfoRow(
                  context,
                  Icons.people,
                  'Đã điểm danh',
                  '${session.attendedStudents.length} sinh viên',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
                const SizedBox(width: 16),
                if (session.isOngoing || session.isUpcoming)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to attendance management
                    },
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('Quản lý điểm danh'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children.map((child) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: child,
        )),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (session.isOngoing) return Colors.green;
    if (session.isUpcoming) return Colors.orange;
    if (session.isFinished) return Colors.grey;
    return Colors.blue;
  }

  IconData _getStatusIcon() {
    if (session.isOngoing) return Icons.play_circle;
    if (session.isUpcoming) return Icons.schedule;
    if (session.isFinished) return Icons.check_circle;
    return Icons.event;
  }
}
