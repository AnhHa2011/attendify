// lib/features/courses/presentation/pages/course_detail_page.dart
import 'package:attendify/app_imports.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/models/rich_course_model.dart';
import '../../../../core/data/services/courses_service.dart';
import '../../../../core/data/services/session_service.dart';
import '../../../../core/presentation/pages/session_detail_page.dart';
import '../../../attendance/export/export_attendance_excel_service.dart';
import '../../widgets/dynamic_qr_code_dialog.dart';

class CourseDetailPage extends StatefulWidget {
  final CourseModel courseModel;
  const CourseDetailPage({super.key, required this.courseModel});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  bool _isStartingSession = false;

  Future<void> _showSessionSelectorAndStartAttendance() async {
    setState(() => _isStartingSession = true);
    final sessionService = context.read<SessionService>();

    try {
      // === THAY ĐỔI: GỌI HÀM MỚI ĐỂ LẤY DANH SÁCH BUỔI HỌC PHÙ HỢP ===
      final attendableSessions = await sessionService
          .getAttendableSessionsForCourse(widget.courseModel.id)
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
            courseCode: widget.courseModel.id,
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

  Future<void> _exportAttendance(
    BuildContext context,
    CourseModel course,
  ) async {
    final adminSvc = context.read<AdminService>();
    final sessionSvc = context.read<SessionService>();

    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Lấy dữ liệu cần export
      final users = await adminSvc
          .getEnrolledStudentsStream(course.id)
          .first; // List<UserModel>
      final enrollments = await adminSvc.getEnrollmentsByCourse(course.id);
      final attendances = await adminSvc.getAttendancesByCourse(course.id);
      final leaveRequests = await adminSvc.getLeaveRequestsByCourse(course.id);
      final sessions = await sessionSvc.sessionsOfCourse(course.id).first;

      // Gọi export
      final savedPath = await ExportAttendanceExcelService.export(
        course: course,
        users: users,
        enrollments: enrollments,
        attendances: attendances,
        leaveRequests: leaveRequests,
        sessions: sessions,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // đóng loading

      // Thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Đã tải báo cáo (xem trong Downloads của trình duyệt)'
                : 'Đã lưu báo cáo: $savedPath',
          ),
        ),
      );

      // Mở file (mobile/desktop)
      if (savedPath != null) {
        await OpenFilex.open(savedPath);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // đóng loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất thống kê thất bại: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseSvc = context.read<CourseService>();
    final sessionSvc = context.read<SessionService>();
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.role == UserRole.lecture;

    // === THAY ĐỔI 1: STREAMBUILDER CHÍNH SỬ DỤNG RICHCLASSMODEL ===
    return StreamBuilder<RichCourseModel>(
      // <<<--- Đổi thành RichCourseModel
      stream: courseSvc.getRichCourseStream(widget.courseModel.id),
      builder: (context, courseSnap) {
        if (courseSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (courseSnap.hasError || !courseSnap.hasData) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: false),
            body: Center(
              child: Text(courseSnap.error?.toString() ?? 'Không tìm thấy môn'),
            ),
          );
        }

        // Bóc tách dữ liệu để dễ sử dụng
        final richCourse = courseSnap.data!;
        final courseInfo = richCourse.courseInfo;
        final lecturer = richCourse.lecturer;

        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'fab_start_att',
                    onPressed: _isStartingSession
                        ? null
                        : _showSessionSelectorAndStartAttendance,
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
                    label: const Text('Bắt đầu điểm danh'),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'fab_export',
                    onPressed: () => _exportAttendance(context, courseInfo),
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                  ),
                ],
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // --- THẺ THÔNG TIN môn ---
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(
                    'Môn: ${courseInfo.courseName}\nGV: ${lecturer?.displayName ?? "..."}\nHọc kỳ: ${courseInfo.semester}',
                  ),
                  subtitle: Text('Số tín chỉ: ${courseInfo.credits}'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),

              // --- THẺ MÃ THAM GIA môn (KHÔNG THAY ĐỔI) ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Mã tham gia môn: ${courseInfo.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      QrImageView(data: courseInfo.joinCode, size: 180),
                      if (isLecturer)
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Tạo mã mới'),
                          onPressed: () async =>
                              await courseSvc.regenerateJoinCode(courseInfo.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- DANH SÁCH BUỔI HỌC ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Các buổi học',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<SessionModel>>(
                stream: sessionSvc.sessionsOfCourse(widget.courseModel.id),
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
                                  courseInfo: courseInfo,
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
                future: courseSvc.getEnrolledStudents(courseInfo.id),
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
                                            'Bạn có chắc chắn muốn xoá sinh viên "$studentName" khỏi môn học không?',
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
                                            .read<CourseService>()
                                            .removeStudentFromCourse(
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
