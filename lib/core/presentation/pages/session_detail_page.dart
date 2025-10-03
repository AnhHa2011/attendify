// lib/presentation/pages/sessions/session_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Thay thế bằng các đường dẫn đúng
import '../../data/models/course_model.dart';
import '../../data/models/session_model.dart';
import '../../data/services/courses_service.dart';
import '../../data/services/session_service.dart';

class SessionDetailPage extends StatefulWidget {
  final SessionModel session;
  final CourseModel courseInfo;

  const SessionDetailPage({
    super.key,
    required this.session,
    required this.courseInfo,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  @override
  Widget build(BuildContext context) {
    final sessionService = context.read<SessionService>();
    final courseService = context.read<CourseService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
        actions: [
          StreamBuilder<SessionModel>(
            stream: sessionService.getSessionStream(widget.session.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final isOpen = snapshot.data!.isAttendanceOpen;
              return TextButton.icon(
                onPressed: () =>
                    sessionService.toggleAttendance(widget.session.id, !isOpen),
                icon: Icon(
                  isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: isOpen ? Colors.green : Colors.red,
                ),
                label: Text(
                  isOpen ? 'Đóng Điểm danh' : 'Mở Điểm danh',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_session_detail',
        onPressed: () =>
            _showManualAttendanceDialog(context, sessionService, courseService),
        label: const Text('Điểm danh bù'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // === NÂNG CẤP: DÙNG STREAM MỚI ĐỂ LẤY CẢ DANH SÁCH LỚP ===
        stream: sessionService.getFullStudentListWithStatus(
          sessionId: widget.session.id,
          courseCode: widget.courseInfo.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải danh sách: ${snapshot.error}'));
          }

          final fullStudentList = snapshot.data ?? [];
          final attendedCount = fullStudentList
              .where((s) => s['status'] != 'absent')
              .length;
          final totalCount = fullStudentList.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            children: [
              // --- THẺ THỐNG KÊ ĐIỂM DANH ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        'Có mặt',
                        attendedCount.toString(),
                        Colors.green,
                      ),
                      _buildStatColumn(
                        'Tổng số',
                        totalCount.toString(),
                        Colors.blue,
                      ),
                      _buildStatColumn(
                        'Vắng mặt',
                        (totalCount - attendedCount).toString(),
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- DANH SÁCH TẤT CẢ SINH VIÊN ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Danh sách sinh viên',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              if (fullStudentList.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Môn học chưa có sinh viên nào.'),
                    ),
                  ),
                ),

              if (fullStudentList.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fullStudentList.length,
                  itemBuilder: (context, index) {
                    final student = fullStudentList[index];
                    final timestamp = student['timestamp'] as Timestamp?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(student['displayName']?[0] ?? '?'),
                        ),
                        title: Text(student['displayName'] ?? 'N/A'),
                        subtitle: Text(student['email'] ?? 'N/A'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (timestamp != null)
                              Text(
                                DateFormat('HH:mm').format(timestamp.toDate()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              student['status'],
                              onTap: () {
                                _showUpdateStatusDialog(
                                  context,
                                  sessionService,
                                  student,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  // --- CÁC HÀM HELPER VÀ DIALOG ---

  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Hiển thị Dialog để điểm danh bù cho các sinh viên vắng mặt
  Future<void> _showManualAttendanceDialog(
    BuildContext context,
    SessionService sessionService,
    CourseService courseService,
  ) async {
    // Lấy danh sách sinh viên vắng mặt
    final fullList = await sessionService
        .getFullStudentListWithStatus(
          sessionId: widget.session.id,
          courseCode: widget.courseInfo.id,
        )
        .first;
    final absentStudents = fullList
        .where((s) => s['status'] == 'absent')
        .toList();

    if (!mounted) return;
    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả sinh viên đã có mặt.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thêm điểm danh thủ công'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: absentStudents.length,
              itemBuilder: (context, index) {
                final student = absentStudents[index];
                return ListTile(
                  title: Text(student['displayName'] ?? 'N/A'),
                  subtitle: Text(student['email'] ?? 'N/A'),
                  onTap: () async {
                    await sessionService.addManualAttendance(
                      sessionId: widget.session.id,
                      studentId: student['uid'],
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop(); // Đóng dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thêm ${student['displayName']}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  /// Hiển thị Dialog để cập nhật trạng thái (có mặt, đi muộn, vắng phép)
  Future<void> _showUpdateStatusDialog(
    BuildContext context,
    SessionService sessionService,
    Map<String, dynamic> student,
  ) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Cập nhật trạng thái cho ${student['displayName']}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'present'),
            child: const Text('Có mặt'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'late'),
            child: const Text('Đi muộn'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'excused'),
            child: const Text('Vắng có phép'),
          ),
        ],
      ),
    );

    if (newStatus != null) {
      await sessionService.updateAttendanceStatus(
        sessionId: widget.session.id,
        studentId: student['uid'],
        newStatus: newStatus,
      );
    }
  }

  /// Widget helper để hiển thị chip trạng thái, có thể nhấn vào
  Widget _buildStatusChip(String? status, {required VoidCallback onTap}) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'late':
        color = Colors.orange;
        label = 'Đi muộn';
        icon = Icons.watch_later_outlined;
        break;
      case 'excused':
        color = Colors.blue;
        label = 'Vắng phép';
        icon = Icons.note_alt_outlined;
        break;
      case 'absent':
        color = Colors.red;
        label = 'Vắng mặt';
        icon = Icons.highlight_off_outlined;
        break;
      case 'present':
      default:
        color = Colors.green;
        label = 'Có mặt';
        icon = Icons.check_circle_outline;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Chip(
        avatar: Icon(icon, color: color, size: 16),
        label: Text(label),
        backgroundColor: color.withOpacity(0.15),
        labelStyle: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
