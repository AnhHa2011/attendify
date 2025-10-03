// lib/features/admin/presentation/pages/admin_course_detail_page.dart
import 'package:attendify/core/data/models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/data/models/rich_course_model.dart';
import '../../../../../../core/data/models/session_model.dart';
import '../../../../../../core/data/models/user_model.dart';
import '../../../../../../core/data/services/courses_service.dart';
import '../../../../../../core/data/services/session_service.dart';
import '../../../../../attendance/export/export_attendance_excel_service.dart';
import '../../../../data/services/admin_service.dart';
import '../import/enrollment_bulk_import_page.dart';
import '../import/course_sessions_bulk_import_page.dart';

class AdminCourseDetailPage extends StatelessWidget {
  final String courseCode;
  const AdminCourseDetailPage({super.key, required this.courseCode});

  @override
  Widget build(BuildContext context) {
    final courseService = context.read<CourseService>();
    final sessionService = context.read<SessionService>();

    return StreamBuilder<RichCourseModel>(
      stream: courseService.getRichCourseStream(courseCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: false),
            body: Center(
              child: Text(
                snapshot.error?.toString() ?? 'Lỗi tải dữ liệu môn học',
              ),
            ),
          );
        }

        final richCourse = snapshot.data!;
        final courseInfo = richCourse.courseInfo;
        final lecturer = richCourse.lecturer;
        final adminSvc = context.read<AdminService>();

        return Provider<RichCourseModel>.value(
          value: richCourse,
          child: Scaffold(
            appBar: AppBar(
              title: Text(courseInfo.courseName),
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: Builder(
              builder: (BuildContext innerContext) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    // === THÔNG TIN MÔN HỌC ===
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseInfo.courseName,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.person_outline,
                              'Giảng viên:',
                              lecturer?.displayName ?? '...',
                            ),
                            _buildInfoRow(
                              Icons.tag,
                              'Mã lớp:',
                              courseInfo.courseCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 32, indent: 16, endIndent: 16),

                    // === QUẢN LÝ LỊCH HỌC ===
                    _buildSectionHeader(
                      innerContext,
                      title: 'Lịch học',
                      onSelected: (value) async {
                        if (value == 'select_course') {
                          _showCourseSelectorForSessionDialog(
                            innerContext,
                            sessionService,
                          );
                        } else if (value == 'export_attendance') {
                          final adminSvc = innerContext.read<AdminService>();
                          await _exportAttendance(
                            context: innerContext,
                            adminSvc: adminSvc,
                            courseCode: courseInfo.id,
                            courseName: courseInfo.courseName,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<SessionModel>>(
                      stream: sessionService.sessionsOfCourse(courseInfo.id),
                      builder: (context, sessionSnap) {
                        if (sessionSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: LinearProgressIndicator());
                        }
                        if (sessionSnap.hasError) {
                          return Center(
                            child: Text(
                              'Lỗi tải buổi học: ${sessionSnap.error}',
                            ),
                          );
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

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  session.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thời gian: ${DateFormat('dd/MM/yyyy - HH:mm').format(session.startTime)}',
                                    ),
                                    if (session.location.isNotEmpty)
                                      Text('Địa điểm: ${session.location}'),
                                    Text(
                                      'Thời lượng: ${session.duration.inMinutes} phút',
                                    ),
                                    Text(
                                      'Loại: ${session.typeDisplayName}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Trạng thái: ${session.statusDisplayName}',
                                      style: TextStyle(
                                        color: _getStatusColor(session.status),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Toggle điểm danh
                                    IconButton(
                                      icon: Icon(
                                        session.isOpen
                                            ? Icons.qr_code
                                            : Icons.qr_code_outlined,
                                        color: session.isOpen
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      onPressed: () async {
                                        try {
                                          await sessionService.toggleAttendance(
                                            session.id,
                                            !session.isOpen,
                                          );

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  !session.isOpen
                                                      ? 'Đã mở điểm danh'
                                                      : 'Đã đóng điểm danh',
                                                ),
                                                backgroundColor: !session.isOpen
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Lỗi: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      tooltip: session.isOpen
                                          ? 'Đóng điểm danh'
                                          : 'Mở điểm danh',
                                    ),
                                    // Xóa buổi học
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _showDeleteSessionDialog(
                                        context,
                                        sessionService,
                                        session,
                                      ),
                                      tooltip: 'Xoá buổi học',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(height: 32, indent: 16, endIndent: 16),

                    // === QUẢN LÝ SINH VIÊN ===
                    _buildSectionHeader(
                      innerContext,
                      title: 'Sinh viên',
                      onSelected: (value) {
                        if (value == 'add_single') {
                          _showAddStudentDialog(
                            innerContext,
                            adminSvc,
                            courseInfo.id,
                          );
                        }
                        if (value == 'import_file') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseEnrollmentBulkImportPage(
                                course: courseInfo,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<UserModel>>(
                      stream: adminSvc.getEnrolledStudentsStream(courseInfo.id),
                      builder: (context, studentSnap) {
                        if (studentSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: LinearProgressIndicator());
                        }
                        final students = studentSnap.data ?? [];
                        if (students.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('Chưa có sinh viên nào trong lớp.'),
                              ),
                            ),
                          );
                        }
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: students.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final student = students[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    student.displayName.isNotEmpty
                                        ? student.displayName[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(student.displayName),
                                subtitle: Text(student.email),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async =>
                                      await adminSvc.unenrollStudent(
                                        courseInfo.id,
                                        student.uid,
                                      ),
                                  tooltip: 'Xoá khỏi lớp',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.scheduled:
        return Colors.blue;
      case SessionStatus.inProgress:
        return Colors.green;
      case SessionStatus.completed:
        return Colors.grey;
      case SessionStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required Function(String) onSelected,
  }) {
    final Map<String, List<PopupMenuEntry<String>>> menuItems = {
      'Lịch học': [
        const PopupMenuItem(
          value: 'select_course',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Thêm lịch học'),
          ),
        ),
        const PopupMenuItem(
          value: 'export_attendance',
          child: ListTile(
            leading: Icon(Icons.import_export),
            title: Text('Xuất thống kê quá trình'),
          ),
        ),
      ],
      'Sinh viên': [
        const PopupMenuItem(
          value: 'add_single',
          child: ListTile(
            leading: Icon(Icons.person_add_alt_1_outlined),
            title: Text('Thêm sinh viên'),
          ),
        ),
        const PopupMenuItem(
          value: 'import_file',
          child: ListTile(
            leading: Icon(Icons.upload_file_outlined),
            title: Text('Import từ file'),
          ),
        ),
      ],
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        PopupMenuButton<String>(
          onSelected: (value) => onSelected(value),
          itemBuilder: (context) => menuItems[title]!,
          child: const Chip(
            avatar: Icon(Icons.settings_outlined, size: 18),
            label: Text('Tùy chọn'),
            padding: EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCourseSelectorForSessionDialog(
    BuildContext context,
    SessionService sessionService,
    // KHÔNG CẦN courseInfo và lecturer nữa
  ) {
    _showSessionTypeSelectorDialog(context, sessionService);
  }

  void _showSingleSessionForm(
    BuildContext context,
    SessionService sessionService,
    String courseCode,
    String courseName,
    UserModel? lecturer,
  ) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '90');

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    SessionType selectedSessionType = SessionType.lecture;

    // Biến để lưu trữ thông báo lỗi
    String? dateOrTimeError;
    bool _overlaps(
      DateTime aStart,
      DateTime aEnd,
      DateTime bStart,
      DateTime bEnd,
    ) {
      // overlap nếu aStart < bEnd && bStart < aEnd
      return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
    }

    String _fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String _fmtTime(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Thêm buổi học đơn lẻ'),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Canh lề cho text lỗi
                    children: [
                      // ... (Các TextFormField khác giữ nguyên)
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề buổi học',
                          hintText: 'Ví dụ: Buổi 1 - Giới thiệu',
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Không được để trống' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SessionType>(
                        value: selectedSessionType,
                        decoration: const InputDecoration(
                          labelText: 'Loại buổi học',
                        ),
                        items: SessionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.typeDisplayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedSessionType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Địa điểm',
                          hintText: 'Số phòng hoặc link online',
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Không được để trống' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả (tùy chọn)',
                          hintText: 'Nội dung buổi học...',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng (phút)',
                          hintText: '90',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Không được để trống';
                          final duration = int.tryParse(v);
                          if (duration == null || duration <= 0) {
                            return 'Thời lượng phải là số dương';
                          }
                          return null;
                        },
                      ),

                      // === WIDGET HIỂN THỊ LỖI ===
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                selectedDate == null
                                    ? 'Chọn ngày'
                                    : DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(selectedDate!),
                              ),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setDialogState(() => selectedDate = date);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                selectedTime == null
                                    ? 'Chọn giờ'
                                    : selectedTime!.format(context),
                              ),
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setDialogState(() => selectedTime = time);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (dateOrTimeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            dateOrTimeError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () async {
                  final isFormValid = formKey.currentState!.validate();
                  final isDateTimeSelected =
                      selectedDate != null && selectedTime != null;

                  if (!isFormValid || !isDateTimeSelected) {
                    setDialogState(() {
                      if (!isDateTimeSelected) {
                        dateOrTimeError = 'Vui lòng chọn đầy đủ ngày và giờ.';
                      }
                    });
                    return;
                  }

                  final duration = int.parse(durationCtrl.text);
                  if (duration <= 0) {
                    setDialogState(() {
                      dateOrTimeError = 'Thời lượng phải là số dương.';
                    });
                    return;
                  }

                  final startTime = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  final endTime = startTime.add(Duration(minutes: duration));

                  if (!endTime.isAfter(startTime)) {
                    setDialogState(() {
                      dateOrTimeError =
                          'Giờ kết thúc phải lớn hơn giờ bắt đầu.';
                    });
                    return;
                  }

                  // ===== Kiểm tra TRÙNG LỊCH GIẢNG VIÊN (ngày + giờ) =====
                  try {
                    if (lecturer != null && (lecturer.uid).isNotEmpty) {
                      final dayStart = DateTime(
                        startTime.year,
                        startTime.month,
                        startTime.day,
                        0,
                        0,
                        0,
                        0,
                        0,
                      );
                      final dayEnd = DateTime(
                        startTime.year,
                        startTime.month,
                        startTime.day,
                        23,
                        59,
                        59,
                        999,
                        999,
                      );

                      // Cần hàm trong SessionService: fetchLecturerSessionsInRange(...)
                      final existing = await sessionService
                          .fetchLecturerSessionsInRange(
                            lecturerId: lecturer.uid,
                            start: dayStart,
                            end: dayEnd,
                          );

                      final clash = existing.firstWhere(
                        (s) => _overlaps(
                          startTime,
                          endTime,
                          s.startTime,
                          s.endTime,
                        ),
                        orElse: () => SessionModel.empty(),
                      );

                      if (clash.id.isNotEmpty) {
                        setDialogState(() {
                          dateOrTimeError =
                              'Giảng viên đã có lịch dạy lúc: ${clash.title} '
                              '(${_fmtTime(clash.startTime)}–${_fmtTime(clash.endTime)} '
                              '${_fmtDate(clash.startTime)}). Vui lòng chọn khoảng thời gian khác!';
                        });
                        return;
                      }
                    }
                  } catch (e) {
                    // Nếu muốn chặn luôn khi không kiểm tra được lịch thì để lại return
                    setDialogState(() {
                      dateOrTimeError =
                          'Không kiểm tra được lịch giảng viên: $e';
                    });
                    return;
                  }
                  // =======================================================

                  try {
                    await sessionService.createSession(
                      courseCode: courseCode,
                      courseName: courseName,
                      lecturerId: lecturer?.uid,
                      lecturerName: lecturer?.displayName,
                      title: titleCtrl.text.trim(),
                      description: descriptionCtrl.text.trim().isEmpty
                          ? null
                          : descriptionCtrl.text.trim(),
                      startTime: startTime,
                      endTime: endTime,
                      location: locationCtrl.text.trim(),
                      type: selectedSessionType,
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã tạo buổi học thành công'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi tạo buổi học: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Thêm'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Sửa hàm này để đọc từ context
  void _showSessionTypeSelectorDialog(
    BuildContext context,
    SessionService sessionService,
    // KHÔNG CẦN courseInfo và lecturer nữa
  ) {
    // === LẤY DỮ LIỆU TRỰC TIẾP TỪ PROVIDER ===
    // context.read<RichCourseModel>() sẽ lấy đối tượng mà bạn đã cung cấp ở bước 2
    final richCourse = context.read<RichCourseModel>();
    final courseInfo = richCourse.courseInfo;
    final lecturer = richCourse.lecturer;
    // ===========================================

    final courseService = context.read<CourseService>();

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Thêm lịch học:'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Truyền dữ liệu đã lấy được xuống hàm con
              _showSingleSessionForm(
                context,
                sessionService,
                courseInfo.id, // Vẫn cần courseId
                courseInfo.courseName,
                lecturer,
              );
            },
            child: const ListTile(
              leading: Icon(Icons.add),
              title: Text('Thêm buổi đơn lẻ'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CourseSessionsBulkImportPage(course: courseInfo),
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.calendar_month_outlined),
              title: Text('Thêm lịch hàng loạt'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(
    BuildContext context,
    AdminService adminSvc,
    String courseCode,
  ) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final allStudents = await adminSvc.getAllStudentsStream().first;
      final enrolledStudents = await adminSvc
          .getEnrolledStudentsStream(courseCode)
          .first;
      final enrolledStudentIds = enrolledStudents.map((s) => s.uid).toSet();
      final availableStudents = allStudents
          .where((s) => !enrolledStudentIds.contains(s.uid))
          .toList();

      if (context.mounted) Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) {
          String? selectedStudentId;
          return AlertDialog(
            title: const Text('Thêm sinh viên vào môn học'),
            content: availableStudents.isEmpty
                ? const Text(
                    'Tất cả sinh viên đã tham gia môn học hoặc chưa có sinh viên trong hệ thống.',
                  )
                : DropdownButtonFormField<String>(
                    hint: const Text('Chọn sinh viên'),
                    isExpanded: true,
                    items: availableStudents
                        .map(
                          (student) => DropdownMenuItem(
                            value: student.uid,
                            child: Text(
                              '${student.displayName} (${student.email})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => selectedStudentId = value,
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: availableStudents.isEmpty
                    ? null
                    : () async {
                        if (selectedStudentId != null) {
                          try {
                            await adminSvc.enrollSingleStudent(
                              courseCode,
                              selectedStudentId!,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: const Text('Thêm'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteSessionDialog(
    BuildContext context,
    SessionService sessionService,
    SessionModel session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa buổi học "${session.title}"?\n\n'
          'Thời gian: ${DateFormat('dd/MM/yyyy - HH:mm').format(session.startTime)}\n'
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await sessionService.deleteSession(session.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa buổi học thành công'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi xóa buổi học: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAttendance({
    required BuildContext context,
    required AdminService adminSvc,
    required String courseCode,
    required String courseName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final course = await adminSvc.getCourseById(courseCode);
      final students = await adminSvc.getUsersByRole(UserRole.student);
      final sessions = await adminSvc.getSessionsForCourse(courseCode);
      final enrollments = await adminSvc.getEnrollmentsByCourse(courseCode);
      final attendances = await adminSvc.getAttendancesByCourse(courseCode);
      final leaveRequests = await adminSvc.getLeaveRequestsByCourse(courseCode);

      // === gọi export service ===
      final savedPath = await ExportAttendanceExcelService.export(
        users: students,
        course: course,
        enrollments: enrollments,
        attendances: attendances,
        leaveRequests: leaveRequests,
        sessions: sessions,
      );

      if (context.mounted) Navigator.of(context).pop(); // đóng progress

      if (!context.mounted) return;

      // === Thông báo ===
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Đã tải báo cáo (xem trong thư mục Downloads của trình duyệt)'
                : 'Đã lưu báo cáo: $savedPath',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // === Mở file nếu có path (mobile/desktop) ===
      if (savedPath != null) {
        await OpenFilex.open(savedPath);
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất báo cáo thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Extension for SessionType display
extension SessionTypeExtension on SessionType {
  String get typeDisplayName {
    switch (this) {
      case SessionType.lecture:
        return 'Lý thuyết';
      case SessionType.practice:
        return 'Thực hành';
      case SessionType.exam:
        return 'Kiểm tra';
      case SessionType.review:
        return 'Ôn tập';
    }
  }
}
