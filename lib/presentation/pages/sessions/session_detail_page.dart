// lib/presentation/pages/sessions/session_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/class_model.dart';
import '../../../data/models/session_model.dart';
import '../../../services/firebase/class_service.dart';
import '../../../services/firebase/session_service.dart';

class SessionDetailPage extends StatefulWidget {
  final SessionModel session;
  final ClassModel classInfo;

  const SessionDetailPage({
    super.key,
    required this.session,
    required this.classInfo,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  @override
  Widget build(BuildContext context) {
    final sessionService = context.read<SessionService>();
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        label: const Text('Thêm thủ công'),
        icon: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // --- THẺ THÔNG TIN LỚP HỌC ---
          Card(
            child: ListTile(
              leading: const Icon(Icons.class_, color: Colors.blueGrey),
              title: Text(widget.classInfo.courseName ?? '...'),
              subtitle: Text(
                'Mã: ${widget.classInfo.courseCode ?? "..."} • GV: ${widget.classInfo.lecturerName ?? "..."}',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- THẺ THÔNG TIN BUỔI HỌC ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    'Ngày:',
                    DateFormat(
                      'EEEE, dd/MM/yyyy',
                      'vi_VN',
                    ).format(widget.session.startTime),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.schedule_outlined,
                    'Thời gian:',
                    '${DateFormat.Hm().format(widget.session.startTime)} - ${DateFormat.Hm().format(widget.session.endTime)}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'Địa điểm:',
                    widget.session.location,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- THẺ THỐNG KÊ ĐIỂM DANH ---
          FutureBuilder<int>(
            future: classService.getEnrolledStudentCount(widget.classInfo.id),
            builder: (context, totalStudentsSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: sessionService.getRichAttendanceList(widget.session.id),
                builder: (context, attendanceSnap) {
                  final attendedCount = attendanceSnap.data?.length ?? 0;
                  final totalCount = totalStudentsSnap.data ?? 0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Đã điểm danh',
                            attendedCount.toString(),
                            Colors.green,
                          ),
                          _buildStatColumn(
                            'Tổng số',
                            totalCount.toString(),
                            Colors.blue,
                          ),
                          _buildStatColumn(
                            'Vắng',
                            (totalCount - attendedCount).toString(),
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // --- DANH SÁCH SINH VIÊN ĐÃ ĐIỂM DANH ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Danh sách điểm danh',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: sessionService.getRichAttendanceList(widget.session.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final attendanceList = snapshot.data ?? [];
              if (attendanceList.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Chưa có sinh viên nào điểm danh.'),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attendanceList.length,
                itemBuilder: (context, index) {
                  final data = attendanceList[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(/* ... Code ListTile ... */),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- CÁC HÀM HELPER ---

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(value),
      ],
    );
  }

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

  // Hàm hiển thị Dialog để thêm điểm danh thủ công
  Future<void> _showAddStudentDialog() async {
    final classService = context.read<ClassService>();
    final sessionService = context.read<SessionService>();

    // 1. Lấy danh sách TẤT CẢ sinh viên trong lớp
    final allStudents = await classService.getEnrolledStudents(
      widget.classInfo.id,
    );

    // 2. Lấy danh sách sinh viên ĐÃ điểm danh
    final attendedList = await sessionService
        .getRichAttendanceList(widget.session.id)
        .first; // .first để lấy giá trị hiện tại của Stream
    final attendedStudentIds = attendedList.map((e) => e['studentId']).toSet();

    // 3. Lọc ra những sinh viên CHƯA điểm danh
    final absentStudents = allStudents
        .where((student) => !attendedStudentIds.contains(student['uid']))
        .toList();

    if (!mounted) return;

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả sinh viên đã được điểm danh.')),
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

  // Widget helper để hiển thị chip trạng thái
  Widget _buildStatusChip(String? status) {
    status ??= 'present';
    Color color;
    String label;

    switch (status) {
      case 'late':
        color = Colors.orange;
        label = 'Đi muộn';
        break;
      case 'excused':
        color = Colors.blue;
        label = 'Vắng phép';
        break;
      case 'present':
      default:
        color = Colors.green;
        label = 'Có mặt';
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
