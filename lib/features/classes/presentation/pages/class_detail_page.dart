// lib/presentation/pages/classes/class_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

// Thay thế bằng các đường dẫn đúng trong dự án của bạn
import '../../../common/data/models/class_model.dart';
import '../../../common/data/models/session_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../../../../app/providers/auth_provider.dart';
import '../../../sessions/presentation/pages/data/services/session_service.dart';
import '../../../sessions/presentation/pages/session_detail_page.dart';
import '../../data/services/class_service.dart';
import '../../widgets/dynamic_qr_code_dialog.dart';

class ClassDetailPage extends StatefulWidget {
  final String classId;
  const ClassDetailPage({super.key, required this.classId});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  bool _isStartingSession = false;

  Future<void> _showSessionSelectorAndStartAttendance() async {
    setState(() => _isStartingSession = true);
    final sessionService = context.read<SessionService>();

    try {
      // === THAY ĐỔI: GỌI HÀM MỚI ĐỂ LẤY DANH SÁCH BUỔI HỌC PHÙ HỢP ===
      final attendableSessions = await sessionService
          .getAttendableSessionsForClass(widget.classId)
          .first;
      if (!mounted) return;

      if (attendableSessions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không có buổi học nào có thể điểm danh vào lúc này.',
            ),
          ),
        );
        return;
      }

      final SessionModel? selectedSession = await showDialog<SessionModel>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chọn buổi học để điểm danh'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: attendableSessions.length, // Dùng danh sách mới
              itemBuilder: (context, index) {
                final session = attendableSessions[index];
                // Thêm hiển thị trạng thái để Giảng viên biết
                final isOngoing = session.status == SessionStatus.inProgress;
                return ListTile(
                  title: Text(session.title),
                  subtitle: Text(
                    'Lịch học: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)}',
                  ),
                  trailing: isOngoing
                      ? const Chip(
                          label: Text('Đang diễn ra'),
                          backgroundColor: Colors.greenAccent,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(session),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      );

      if (selectedSession != null) {
        // Nếu buổi học chưa được mở, thì mở nó ra
        if (selectedSession.status != SessionStatus.inProgress) {
          await sessionService.startAttendanceForSession(selectedSession.id);
        }

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => DynamicQrCodeDialog(
            classId: widget.classId,
            sessionId: selectedSession.id,
            sessionTitle: selectedSession.title,
            refreshInterval: 60,
          ),
        ).then((_) {
          // Sau khi đóng dialog, tự động đóng điểm danh để bảo mật
          sessionService.toggleAttendance(selectedSession.id, false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classSvc = context.read<ClassService>();
    final sessionSvc = context.read<SessionService>();
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.role == UserRole.lecture;

    return StreamBuilder<ClassModel>(
      stream: classSvc.getRichClassStream(widget.classId),
      builder: (context, classSnap) {
        if (classSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (classSnap.hasError || !classSnap.hasData) {
          return Scaffold(
            body: Center(
              child: Text(classSnap.error?.toString() ?? 'Không tìm thấy lớp'),
            ),
          );
        }

        final classInfo = classSnap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              '${classInfo.courseCode ?? ""} - ${classInfo.courseName ?? "..."}',
            ),
          ),
          floatingActionButton: isLecturer
              ? FloatingActionButton.extended(
                  heroTag: 'fab_lecturer_class_detail',
                  onPressed: _isStartingSession
                      ? null
                      : _showSessionSelectorAndStartAttendance,
                  label: const Text('Bắt đầu điểm danh'),
                  icon: _isStartingSession
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_scanner),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // --- THẺ THÔNG TIN LỚP ---
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(classInfo.courseName ?? 'Đang tải...'),
                  subtitle: Text(
                    'Mã môn: ${classInfo.courseCode ?? "..."}\nGV: ${classInfo.lecturerName ?? "..."}\nHọc kỳ: ${classInfo.semester}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),

              // --- THẺ MÃ THAM GIA LỚP ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Mã tham gia lớp: ${classInfo.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      QrImageView(data: classInfo.joinCode, size: 180),
                      if (isLecturer)
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Tạo mã mới'),
                          onPressed: () async =>
                              await classSvc.regenerateJoinCode(classInfo.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // === THÊM LẠI PHẦN HIỂN THỊ DANH SÁCH BUỔI HỌC ===
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Các buổi học',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('Chưa có buổi học nào được tạo.'),
                        ),
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
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: const Icon(Icons.event_note),
                          title: Text(session.title),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)} - Trạng thái: ${session.status.name}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Điều hướng đến trang chi tiết buổi học của Giảng viên
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessionDetailPage(
                                  session: session,
                                  classInfo: classInfo,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              // =======================================================
              const SizedBox(height: 24),

              // --- DANH SÁCH SINH VIÊN ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Danh sách sinh viên',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: classSvc.getEnrolledStudents(classInfo.id),
                builder: (context, ms) {
                  if (ms.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = ms.data ?? [];
                  if (members.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('Chưa có sinh viên nào tham gia.'),
                        ),
                      ),
                    );
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = members[i];
                        // Lấy ra các thông tin cần thiết từ map
                        final studentName = m['displayName'] ?? 'N/A';
                        final studentEmail = m['email'] ?? 'N/A';
                        final enrollmentId =
                            m['enrollmentId']; // ID để thực hiện việc xoá

                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(studentName),
                          subtitle: Text(studentEmail),
                          trailing: isLecturer
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    // --- BẮT ĐẦU LOGIC XOÁ MỚI ---

                                    // B1: Kiểm tra xem enrollmentId có tồn tại không
                                    if (enrollmentId == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Không tìm thấy thông tin để xoá.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    // B2: Hiển thị hộp thoại xác nhận
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('Xác nhận xoá'),
                                          content: Text(
                                            'Bạn có chắc chắn muốn xoá sinh viên "$studentName" khỏi lớp học không?',
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text('HUỶ'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text(
                                                'XOÁ',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    // B3: Nếu người dùng xác nhận, tiến hành xoá
                                    if (confirm == true) {
                                      try {
                                        // Gọi hàm từ service
                                        await context
                                            .read<ClassService>()
                                            .removeStudentFromClass(
                                              enrollmentId,
                                            );

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Đã xoá sinh viên "$studentName".',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Cập nhật lại UI để danh sách làm mới
                                        setState(() {});
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceFirst(
                                                "Exception: ",
                                                "",
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                )
                              : null,
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
