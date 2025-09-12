// lib/presentation/pages/classes/class_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

// Import các model và service cần thiết
import '../../../data/models/class_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/user_model.dart'; // <-- QUAN TRỌNG: Cần để so sánh UserRole
import '../../../services/firebase/class_service.dart';
import '../../../services/firebase/session_service.dart';
import '../../../app/providers/auth_provider.dart';
import '../sessions/session_detail_page.dart';

class ClassDetailPage extends StatefulWidget {
  final String classId;
  const ClassDetailPage({super.key, required this.classId});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  bool _isCreatingSession = false;

  // Hàm tạo buổi học không thay đổi
  Future<void> _startNewAttendanceSession() async {
    // ... (Giữ nguyên toàn bộ code của hàm này)
  }

  @override
  Widget build(BuildContext context) {
    final classSvc = context.read<ClassService>();
    final sessionSvc = context.read<SessionService>();

    // === BƯỚC 1: LẤY VAI TRÒ NGƯỜI DÙNG ===
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.role == UserRole.lecture;

    return StreamBuilder<ClassModel>(
      stream: classSvc.getRichClassStream(widget.classId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            body: Center(
              child: Text(snap.error?.toString() ?? 'Không tìm thấy lớp'),
            ),
          );
        }

        final c = snap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('${c.courseCode ?? ""} - ${c.courseName ?? "..."}'),
          ),

          // === BƯỚC 2: PHÂN QUYỀN CHO FLOATINGACTIONBUTTON ===
          floatingActionButton: isLecturer
              ? FloatingActionButton.extended(
                  onPressed: _isCreatingSession
                      ? null
                      : _startNewAttendanceSession,
                  label: const Text('Tạo buổi học & QR'),
                  icon: _isCreatingSession
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.qr_code_scanner),
                )
              : null, // Nếu không phải giảng viên, ẩn nút này đi

          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Thẻ thông tin lớp học (hiển thị cho cả 2)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(c.courseName ?? 'Đang tải...'),
                  subtitle: Text(
                    'Mã môn: ${c.courseCode ?? "..."}\nGV: ${c.lecturerName ?? "..."}\nHọc kỳ: ${c.semester}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),

              // Thẻ Mã tham gia lớp
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Mã tham gia lớp: ${c.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      QrImageView(data: c.joinCode, size: 180),

                      // === BƯỚC 3: PHÂN QUYỀN CHO NÚT "TẠO MÃ MỚI" ===
                      if (isLecturer)
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Tạo mã mới'),
                          onPressed: () async =>
                              await classSvc.regenerateJoinCode(c.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Danh sách buổi học (hiển thị cho cả 2)
              Text(
                'Các buổi học',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<SessionModel>>(
                stream: sessionSvc.sessionsOfClass(widget.classId),
                builder: (context, sessionSnap) {
                  if (sessionSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = sessionSnap.data ?? [];
                  if (sessions.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Chưa có buổi học nào được tạo.'),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.event_available),
                          title: Text(session.title),
                          subtitle: Text(
                            '${DateFormat.yMd().add_Hm().format(session.startTime)} - Trạng thái: ${session.status.name}',
                          ),
                          // Bạn có thể thêm các hành động khác ở đây, ví dụ xem chi tiết điểm danh
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Điều hướng đến trang chi tiết buổi học (nếu có)
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Danh sách Sinh viên (hiển thị cho cả 2)
              Text(
                'Danh sách sinh viên',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: classSvc.getEnrolledStudents(c.id),
                builder: (context, ms) {
                  if (ms.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = ms.data ?? [];
                  if (members.isEmpty)
                    return const Text('Chưa có sinh viên tham gia');

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = members[i];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(m['displayName'] ?? 'N/A'),
                          subtitle: Text(m['email'] ?? 'N/A'),

                          // === BƯỚC 4: PHÂN QUYỀN CHO NÚT XÓA SINH VIÊN ===
                          trailing: isLecturer
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Xóa sinh viên khỏi lớp',
                                  onPressed: () {
                                    // TODO: Cần tạo hàm xóa enrollment trong ClassService
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tính năng xóa đang phát triển',
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : null, // Sinh viên không thấy nút xóa
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
