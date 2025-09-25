// lib/features/admin/presentation/pages/admin_class_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../classes/data/services/class_service.dart';
import '../../../../common/data/models/class_model.dart';
import '../../../../common/data/models/class_schedule_model.dart';
import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/session_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';

class AdminClassDetailPage extends StatelessWidget {
  final String classId;
  const AdminClassDetailPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return StreamBuilder<ClassModel>(
      stream: classService.getRichClassStream(classId),
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
                snapshot.error?.toString() ?? 'Lỗi tải dữ liệu lớp học',
              ),
            ),
          );
        }

        final classInfo = snapshot.data!;
        final adminSvc = context.read<AdminService>();

        return Scaffold(
          appBar: AppBar(title: Text('Thông tin lớp học')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // === PHẦN THÔNG TIN LỚP HỌC ===
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classInfo.className,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildInfoRow(Icons.tag, 'Mã lớp:', classInfo.classCode),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32, indent: 16, endIndent: 16),
              // === PHẦN QUẢN LÝ SINH VIÊN ===
              _buildSectionHeader(
                context,
                title: 'Sinh viên',
                onSelected: (value) {
                  if (value == 'add_single') {
                    _showAddStudentDialog(context, adminSvc, classInfo.id);
                  }
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<UserModel>>(
                stream: adminSvc.getEnrolledStudentsStream(classInfo.id),
                builder: (context, studentSnap) {
                  if (studentSnap.connectionState == ConnectionState.waiting) {
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                            onPressed: () async => await adminSvc
                                .unenrollStudent(classInfo.id, student.uid),
                            tooltip: 'Xoá khỏi lớp',
                          ),
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

  // Widget helper để tạo tiêu đề và nút bấm cho mỗi khu vực
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required Function(String) onSelected,
  }) {
    // Menu items được định nghĩa cứng ở đây để gọn gàng
    final Map<String, List<PopupMenuEntry<String>>> menuItems = {
      'Lịch học': [
        const PopupMenuItem(
          value: 'select_course',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Thêm lịch học...'),
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
          // Sửa lỗi cú pháp tại đây
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

  // Widget helper để hiển thị thông tin
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
    AdminService adminSvc,
    String classId,
    List<CourseModel> courses,
  ) {
    CourseModel? selectedCourse;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn môn học để thêm lịch'),
        content: DropdownButtonFormField<CourseModel>(
          hint: const Text('Chọn một môn học'),
          isExpanded: true,
          items: courses
              .map(
                (course) => DropdownMenuItem(
                  value: course,
                  child: Text(
                    '${course.courseCode} - ${course.courseName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => selectedCourse = value,
          validator: (v) => v == null ? 'Vui lòng chọn môn' : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (selectedCourse != null) {
                Navigator.of(ctx).pop();
                _showSessionTypeSelectorDialog(
                  context,
                  adminSvc,
                  classId,
                  selectedCourse!,
                );
              }
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  // === HÀM MỚI: HIỂN THỊ DIALOG CHỌN LOẠI LỊCH (ĐƠN LẺ / HÀNG LOẠT) ===
  void _showSessionTypeSelectorDialog(
    BuildContext context,
    AdminService adminSvc,
    String classId,
    CourseModel course,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Thêm lịch cho môn: ${course.courseCode}'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showSingleSessionForm(context, adminSvc, classId, course);
            },
            child: const ListTile(
              leading: Icon(Icons.add),
              title: Text('Thêm buổi đơn lẻ'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showRecurringSessionForm(context, adminSvc, classId, course);
            },
            child: const ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text('Thêm lịch hàng loạt'),
            ),
          ),
        ],
      ),
    );
  }

  // === HÀM FORM TẠO BUỔI ĐƠN LẺ (ĐÃ CẬP NHẬT) ===
  void _showSingleSessionForm(
    BuildContext context,
    AdminService adminSvc,
    String classId,
    CourseModel course,
  ) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: course.courseName);
    final locationCtrl = TextEditingController(text: 'Tại lớp');
    final durationCtrl = TextEditingController(text: '90');
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Thêm buổi học đơn lẻ'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    TextFormField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Địa điểm'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Thời lượng (phút)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
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
                                firstDate: DateTime(2020),
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
                  ],
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
                  if (formKey.currentState!.validate() &&
                      selectedDate != null &&
                      selectedTime != null) {
                    final startTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    await adminSvc.createSingleSession(
                      classId: classId,
                      courseId: course.id,
                      title: titleCtrl.text.trim(),
                      location: locationCtrl.text.trim(),
                      startTime: startTime,
                      durationInMinutes: int.tryParse(durationCtrl.text) ?? 90,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
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

  // === HÀM FORM TẠO LỊCH HÀNG LOẠT (ĐÃ CẬP NHẬT) ===
  void _showRecurringSessionForm(
    BuildContext context,
    AdminService adminSvc,
    String classId,
    CourseModel course,
  ) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: course.courseName);
    final locationCtrl = TextEditingController(text: 'Tại lớp');
    final durationCtrl = TextEditingController(text: '90');
    final weeksCtrl = TextEditingController(text: '15');
    DateTime semesterStartDate = DateTime.now();
    List<ClassSchedule> weeklySchedules = [
      const ClassSchedule(
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 7, minute: 30),
      ),
    ];
    final weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Thêm lịch học hàng loạt'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề cơ bản',
                        hintText: 'Sẽ tự thêm " - Buổi 1, 2,..."',
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Không được để trống' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: weeksCtrl,
                      decoration: const InputDecoration(labelText: 'Số tuần'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0
                          ? 'Phải là số lớn hơn 0'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Địa điểm'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Thời lượng (phút)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ngày bắt đầu học kỳ:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(semesterStartDate),
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: semesterStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setDialogState(() => semesterStartDate = date);
                        }
                      },
                    ),
                    const Divider(height: 24),
                    Text(
                      'Lịch học trong tuần:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          int index = 0;
                          index < weeklySchedules.length;
                          index++
                        )
                          Builder(
                            builder: (context) {
                              final schedule = weeklySchedules[index];
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButton<int>(
                                      value: schedule.dayOfWeek,
                                      items: List.generate(
                                        7,
                                        (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text(weekdays[i]),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(
                                            () => weeklySchedules[index] =
                                                ClassSchedule(
                                                  dayOfWeek: value,
                                                  startTime: schedule.startTime,
                                                ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      child: Text(
                                        schedule.startTime.format(context),
                                      ),
                                      onPressed: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: schedule.startTime,
                                        );
                                        if (time != null) {
                                          setDialogState(
                                            () => weeklySchedules[index] =
                                                ClassSchedule(
                                                  dayOfWeek: schedule.dayOfWeek,
                                                  startTime: time,
                                                ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => setDialogState(
                                      () => weeklySchedules.removeAt(index),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm lịch'),
                        onPressed: () {
                          setDialogState(
                            () => weeklySchedules.add(
                              const ClassSchedule(
                                dayOfWeek: 1,
                                startTime: TimeOfDay(hour: 7, minute: 30),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
                  if (formKey.currentState!.validate() &&
                      weeklySchedules.isNotEmpty) {
                    final navigator = Navigator.of(ctx);
                    await adminSvc.createRecurringSessions(
                      classId: classId,
                      courseId: course.id,
                      baseTitle: titleCtrl.text.trim(),
                      location: locationCtrl.text.trim(),
                      durationInMinutes: int.tryParse(durationCtrl.text) ?? 90,
                      numberOfWeeks: int.tryParse(weeksCtrl.text) ?? 1,
                      semesterStartDate: semesterStartDate,
                      weeklySchedules: weeklySchedules,
                    );
                    navigator.pop();
                  }
                },
                child: const Text('Tạo lịch'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog để chọn và thêm một sinh viên
  void _showAddStudentDialog(
    BuildContext context,
    AdminService adminSvc,
    String classId,
  ) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    final allStudents = await adminSvc.getAllStudentsStream().first;
    final enrolledStudents = await adminSvc
        .getEnrolledStudentsStream(classId)
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
          title: const Text('Thêm sinh viên vào lớp'),
          content: availableStudents.isEmpty
              ? const Text(
                  'Tất cả sinh viên đã có trong lớp hoặc chưa có sinh viên nào trong hệ thống.',
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
                  validator: (v) =>
                      v == null ? 'Vui lòng chọn một sinh viên' : null,
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
                            classId,
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
  }
}
