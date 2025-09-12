// lib/presentation/pages/sessions/session_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../services/firebase/class_service.dart';
import '../../../services/firebase/session_service.dart';

class SessionDetailPage extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final String classId;

  const SessionDetailPage({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.classId,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  // === 1. HÀM HELPER ĐỂ HIỂN THỊ TRẠNG THÁI ===
  Widget _buildStatusChip(String? status) {
    status ??= 'present'; // Mặc định là 'present' nếu null
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
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = context.read<SessionService>();
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionTitle)),
      // === 2. THÊM NÚT ĐIỂM DANH THỦ CÔNG (SẼ CODE Ở BƯỚC SAU) ===
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        label: const Text('Thêm thủ công'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Thẻ thống kê (giữ nguyên)
          FutureBuilder<int>(
            future: classService.getEnrolledStudentCount(widget.classId),
            builder: (context, totalStudentsSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: sessionService.getRichAttendanceList(widget.sessionId),
                builder: (context, attendanceSnap) {
                  final attendedCount = attendanceSnap.data?.length ?? 0;
                  final totalCount = totalStudentsSnap.data ?? 0;
                  return Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: sessionService.getRichAttendanceList(widget.sessionId),
              builder: (context, snapshot) {
                // ... (code xử lý loading, error, empty giữ nguyên)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final attendanceList = snapshot.data ?? [];
                if (attendanceList.isEmpty) {
                  return const Center(
                    child: Text('Chưa có sinh viên nào điểm danh.'),
                  );
                }

                // === 3. NÂNG CẤP LISTTILE ĐỂ HIỂN THỊ VÀ CHỈNH SỬA TRẠNG THÁI ===
                return ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: 80,
                  ), // Chừa không gian cho FAB
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final data = attendanceList[index];
                    final studentId = data['studentId'];
                    final studentName = data['studentName'] ?? 'Không có tên';
                    final studentEmail =
                        data['studentEmail'] ?? 'Không có email';
                    final Timestamp? attendTime = data['attendTime'];
                    final status = data['status'];

                    return ListTile(
                      leading: _buildStatusChip(status),
                      title: Text(studentName),
                      subtitle: Text(studentEmail),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String newStatus) {
                          sessionService.updateAttendanceStatus(
                            sessionId: widget.sessionId,
                            studentId: studentId,
                            newStatus: newStatus,
                          );
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'present',
                                child: Text('Đánh dấu: Có mặt'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'late',
                                child: Text('Đánh dấu: Đi muộn'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'excused',
                                child: Text('Đánh dấu: Vắng có phép'),
                              ),
                            ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // --- HÀM MỚI ĐỂ HIỂN THỊ DIALOG ---
  Future<void> _showAddStudentDialog() async {
    final classService = context.read<ClassService>();
    final sessionService = context.read<SessionService>();

    // 1. Lấy danh sách TẤT CẢ sinh viên trong lớp
    final allStudents = await classService.getEnrolledStudents(widget.classId);

    // 2. Lấy danh sách sinh viên ĐÃ điểm danh
    final attendedList = await sessionService
        .getRichAttendanceList(widget.sessionId)
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
                      sessionId: widget.sessionId,
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
}
