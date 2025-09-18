// lib/presentation/widgets/schedule/session_detail_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/user_model.dart';
import '../../../app/providers/auth_provider.dart';
import '../../../services/firebase/sessions/session_service.dart';

class SessionDetailBottomSheet extends StatefulWidget {
  final SessionModel session;

  const SessionDetailBottomSheet({super.key, required this.session});

  @override
  State<SessionDetailBottomSheet> createState() =>
      _SessionDetailBottomSheetState();
}

class _SessionDetailBottomSheetState extends State<SessionDetailBottomSheet> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.role == UserRole.lecture;
    final isAdmin = auth.role == UserRole.admin;
    final canModify = isLecturer || isAdmin;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _StatusChip(session: widget.session),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (canModify) ...[
                      IconButton(
                        onPressed: () => _showEditDialog(context),
                        icon: const Icon(Icons.edit),
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        onPressed: () => _showDeleteDialog(context),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Xóa buổi học',
                      ),
                    ],
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Quick Actions (for lecturers)
                    if (canModify && _shouldShowQuickActions()) ...[
                      _QuickActionsSection(
                        session: widget.session,
                        onStatusChanged: _onStatusChanged,
                        isUpdating: _isUpdating,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Basic Information
                    _InfoSection(
                      title: 'Thông tin cơ bản',
                      children: [
                        _InfoRow(
                          icon: Icons.class_,
                          label: 'Lớp học',
                          value:
                              '${widget.session.classCode} • ${widget.session.className}',
                        ),
                        _InfoRow(
                          icon: Icons.person,
                          label: 'Giảng viên',
                          value: widget.session.lecturerName,
                        ),
                        _InfoRow(
                          icon: Icons.category,
                          label: 'Loại buổi học',
                          value: widget.session.typeDisplayName,
                        ),
                        _InfoRow(
                          icon: Icons.access_time,
                          label: 'Thời lượng',
                          value: _formatDuration(widget.session.duration),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Time & Location
                    _InfoSection(
                      title: 'Thời gian & Địa điểm',
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Ngày',
                          value: widget.session.dateString,
                        ),
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Giờ học',
                          value: widget.session.timeRangeString,
                        ),
                        _InfoRow(
                          icon: Icons.location_on,
                          label: 'Phòng học',
                          value: widget.session.location,
                        ),
                        if (widget.session.timeUntilStart != null)
                          _InfoRow(
                            icon: Icons.timer,
                            label: 'Thời gian còn lại',
                            value: _formatTimeUntil(
                              widget.session.timeUntilStart!,
                            ),
                            valueColor: _getTimeUntilColor(
                              widget.session.timeUntilStart!,
                            ),
                          ),
                      ],
                    ),

                    // Description
                    if (widget.session.description != null) ...[
                      const SizedBox(height: 20),
                      _InfoSection(
                        title: 'Mô tả',
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.session.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Attendance Info (if completed or ongoing)
                    if (widget.session.status == SessionStatus.completed ||
                        widget.session.status == SessionStatus.ongoing) ...[
                      const SizedBox(height: 20),
                      _AttendanceSection(session: widget.session),
                    ],

                    // Additional Actions
                    if (canModify) ...[
                      const SizedBox(height: 24),
                      _AdditionalActionsSection(
                        session: widget.session,
                        onActionPressed: _onActionPressed,
                      ),
                    ],

                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowQuickActions() {
    return widget.session.status == SessionStatus.upcoming ||
        widget.session.status == SessionStatus.ongoing;
  }

  void _onStatusChanged(SessionStatus newStatus) {
    setState(() {
      // Update local session status
      // In real app, this would update via provider/bloc
    });
  }

  void _onActionPressed(String action) {
    switch (action) {
      case 'attendance':
        _showAttendanceManager(context);
        break;
      case 'qr':
        _showQRCode(context);
        break;
      case 'students':
        _showStudentList(context);
        break;
      case 'export':
        _exportAttendance(context);
        break;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes} phút';
  }

  String _formatTimeUntil(Duration duration) {
    if (duration.inDays > 0) {
      return 'Còn ${duration.inDays} ngày';
    } else if (duration.inHours > 0) {
      return 'Còn ${duration.inHours} giờ ${duration.inMinutes % 60} phút';
    } else if (duration.inMinutes > 0) {
      return 'Còn ${duration.inMinutes} phút';
    } else {
      return 'Sắp bắt đầu!';
    }
  }

  Color _getTimeUntilColor(Duration duration) {
    if (duration.inMinutes <= 30) {
      return Colors.red;
    } else if (duration.inHours <= 2) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa buổi học'),
        content: const Text('Tính năng đang phát triển'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa buổi học'),
        content: Text(
          'Bạn có chắc muốn xóa buổi học "${widget.session.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              await _deleteSession();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession() async {
    try {
      final sessionService = context.read<SessionService>();
      await sessionService.deleteSession(widget.session.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa buổi học')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showAttendanceManager(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mở quản lý điểm danh')));
  }

  void _showQRCode(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hiển thị QR code')));
  }

  void _showStudentList(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Danh sách sinh viên')));
  }

  void _exportAttendance(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Xuất dữ liệu điểm danh')));
  }
}

// Status Chip Widget
class _StatusChip extends StatelessWidget {
  final SessionModel session;

  const _StatusChip({required this.session});

  @override
  Widget build(BuildContext context) {
    Color getStatusColor() {
      switch (session.status) {
        case SessionStatus.upcoming:
          return Colors.blue;
        case SessionStatus.ongoing:
          return Colors.green;
        case SessionStatus.completed:
          return Colors.grey;
        case SessionStatus.cancelled:
          return Colors.red;
      }
    }

    IconData getStatusIcon() {
      switch (session.status) {
        case SessionStatus.upcoming:
          return Icons.schedule;
        case SessionStatus.ongoing:
          return Icons.play_circle_filled;
        case SessionStatus.completed:
          return Icons.check_circle;
        case SessionStatus.cancelled:
          return Icons.cancel;
      }
    }

    final color = getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getStatusIcon(), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            session.statusDisplayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Actions Section
class _QuickActionsSection extends StatelessWidget {
  final SessionModel session;
  final Function(SessionStatus) onStatusChanged;
  final bool isUpdating;

  const _QuickActionsSection({
    required this.session,
    required this.onStatusChanged,
    required this.isUpdating,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Thao tác nhanh',
      children: [
        Row(
          children: [
            if (session.status == SessionStatus.upcoming) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUpdating ? null : () => _startSession(context),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Bắt đầu'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUpdating ? null : () => _cancelSession(context),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Hủy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ] else if (session.status == SessionStatus.ongoing) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _toggleAttendance(context),
                  icon: Icon(
                    session.isAttendanceOpen
                        ? Icons.qr_code
                        : Icons.qr_code_scanner,
                    size: 18,
                  ),
                  label: Text(
                    session.isAttendanceOpen
                        ? 'Đóng điểm danh'
                        : 'Mở điểm danh',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: session.isAttendanceOpen
                        ? Colors.green
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUpdating ? null : () => _endSession(context),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Kết thúc'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _startSession(BuildContext context) async {
    try {
      final sessionService = context.read<SessionService>();
      await sessionService.updateSessionStatus(
        session.id,
        SessionStatus.ongoing,
      );
      onStatusChanged(SessionStatus.ongoing);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã bắt đầu buổi học')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _endSession(BuildContext context) async {
    try {
      final sessionService = context.read<SessionService>();
      await sessionService.updateSessionStatus(
        session.id,
        SessionStatus.completed,
      );
      onStatusChanged(SessionStatus.completed);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã kết thúc buổi học')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _cancelSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy buổi học'),
        content: const Text('Bạn có chắc muốn hủy buổi học này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy buổi học'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final sessionService = context.read<SessionService>();
        await sessionService.updateSessionStatus(
          session.id,
          SessionStatus.cancelled,
        );
        onStatusChanged(SessionStatus.cancelled);

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã hủy buổi học')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  void _toggleAttendance(BuildContext context) async {
    try {
      final sessionService = context.read<SessionService>();
      await sessionService.toggleAttendance(
        session.id,
        !session.isAttendanceOpen,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              session.isAttendanceOpen
                  ? 'Đã đóng điểm danh'
                  : 'Đã mở điểm danh',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

// Attendance Section
class _AttendanceSection extends StatelessWidget {
  final SessionModel session;

  const _AttendanceSection({required this.session});

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Điểm danh',
      children: [
        Row(
          children: [
            Expanded(
              child: _AttendanceCard(
                title: 'Có mặt',
                value: session.attendedStudents.toString(),
                color: Colors.green,
                icon: Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AttendanceCard(
                title: 'Vắng mặt',
                value: (session.totalStudents - session.attendedStudents)
                    .toString(),
                color: Colors.red,
                icon: Icons.cancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AttendanceCard(
                title: 'Tỷ lệ',
                value: '${session.attendancePercentage.toStringAsFixed(1)}%',
                color: Colors.blue,
                icon: Icons.percent,
              ),
            ),
          ],
        ),

        if (session.totalStudents > 0) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: session.attendancePercentage / 100,
            backgroundColor: Colors.red.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              session.attendancePercentage >= 80 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _AttendanceCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Additional Actions Section
class _AdditionalActionsSection extends StatelessWidget {
  final SessionModel session;
  final Function(String) onActionPressed;

  const _AdditionalActionsSection({
    required this.session,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Thao tác khác',
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3,
          children: [
            _ActionButton(
              icon: Icons.qr_code,
              label: 'QR Code',
              onPressed: () => onActionPressed('qr'),
            ),
            _ActionButton(
              icon: Icons.people,
              label: 'Sinh viên',
              onPressed: () => onActionPressed('students'),
            ),
            _ActionButton(
              icon: Icons.assignment,
              label: 'Điểm danh',
              onPressed: () => onActionPressed('attendance'),
            ),
            _ActionButton(
              icon: Icons.download,
              label: 'Xuất dữ liệu',
              onPressed: () => onActionPressed('export'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Info Section Widget
class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
