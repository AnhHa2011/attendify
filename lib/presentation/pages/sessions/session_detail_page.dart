// lib/presentation/pages/sessions/session_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../services/firebase/class_service.dart';
import '../../../services/firebase/session_service.dart';
import '../../../data/models/session_model.dart'; // Import model này nếu chưa có

class SessionDetailPage extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final String classId; // Cần classId để lấy tổng số sinh viên

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
  @override
  Widget build(BuildContext context) {
    final sessionService = context.read<SessionService>();
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionTitle)),
      body: Column(
        children: [
          // THẺ THỐNG KÊ
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

          // DANH SÁCH SINH VIÊN ĐÃ ĐIỂM DANH
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: sessionService.getRichAttendanceList(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${snapshot.error}'),
                  );
                }
                final attendanceList = snapshot.data ?? [];
                if (attendanceList.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('Chưa có sinh viên nào điểm danh.'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final data = attendanceList[index];
                    final studentName = data['studentName'] ?? 'Không có tên';
                    final studentEmail =
                        data['studentEmail'] ?? 'Không có email';
                    final Timestamp? attendTime = data['attendTime'];
                    final initial = studentName.isNotEmpty
                        ? studentName[0].toUpperCase()
                        : '?';

                    return ListTile(
                      leading: CircleAvatar(child: Text(initial)),
                      title: Text(studentName),
                      subtitle: Text(studentEmail),
                      trailing: Text(
                        attendTime != null
                            ? DateFormat('HH:mm:ss').format(attendTime.toDate())
                            : '',
                        style: Theme.of(context).textTheme.bodySmall,
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
}
