// lib/presentation/pages/admin/admin_class_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// Thay thế bằng các đường dẫn đúng trong dự án của bạn
import '../../../common/data/models/class_model.dart';
import '../../../common/data/models/session_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../data/services/admin_service.dart';

class AdminClassDetailPage extends StatelessWidget {
  final ClassModel classInfo;
  const AdminClassDetailPage({super.key, required this.classInfo});

  @override
  Widget build(BuildContext context) {
    // final sessionSvc = context.read<SessionService>();
    final adminSvc = context.read<AdminService>();

    return Scaffold(
      appBar: AppBar(title: Text(classInfo.courseCode ?? 'Chi tiết lớp học')),
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
                    classInfo.courseName ?? '...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Giảng viên:',
                    classInfo.lecturerName ?? '...',
                  ),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    'Học kỳ:',
                    classInfo.semester,
                  ),
                  if (classInfo.className != null &&
                      classInfo.className!.isNotEmpty)
                    _buildInfoRow(Icons.tag, 'Tên lớp:', classInfo.className!),
                ],
              ),
            ),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),

          // === PHẦN QUẢN LÝ LỊCH HỌC ===
          _buildSectionHeader(
            context,
            title: 'Lịch học',
            menuItems: [
              const PopupMenuItem(
                value: 'single',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Thêm buổi đơn lẻ'),
                ),
              ),
              const PopupMenuItem(
                value: 'bulk',
                child: ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Thêm lịch hàng loạt'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'single') {
                _showSingleSessionForm(context, adminSvc, classInfo.id);
              }
              if (value == 'bulk') {
                _showRecurringSessionForm(context, adminSvc, classInfo.id);
              }
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<SessionModel>>(
            // === THAY ĐỔI: GỌI HÀM MỚI TỪ ADMINSERVICE ===
            stream: adminSvc.getSessionsForClassStream(classInfo.id),
            builder: (context, sessionSnap) {
              if (sessionSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: LinearProgressIndicator());
              }
              if (sessionSnap.hasError) {
                return Center(
                  child: Text('Lỗi tải buổi học: ${sessionSnap.error}'),
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
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(session.title),
                      subtitle: Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)} - Trạng thái: ${session.status.name}',
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // === PHẦN QUẢN LÝ SINH VIÊN ===
          _buildSectionHeader(
            context,
            title: 'Sinh viên',
            menuItems: [
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
                        onPressed: () async => await adminSvc.unenrollStudent(
                          classInfo.id,
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
      ),
    );
  }

  // Widget helper để tạo tiêu đề và nút bấm cho mỗi khu vực
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required Function(String) onSelected,
    required List<PopupMenuEntry<String>> menuItems,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        PopupMenuButton<String>(
          onSelected: onSelected,
          itemBuilder: (context) => menuItems,
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

  // Hàm hiển thị form tạo buổi đơn lẻ
  void _showSingleSessionForm(
    BuildContext context,
    AdminService adminSvc,
    String classId,
  ) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Tại lớp');
    final durationCtrl = TextEditingController(text: '90');
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
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
                      TextFormField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Địa điểm',
                        ),
                      ),
                      TextFormField(
                        controller: durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng (phút)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                        title: titleCtrl.text,
                        location: locationCtrl.text,
                        startTime: startTime,
                        durationInMinutes:
                            int.tryParse(durationCtrl.text) ?? 90,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Hàm hiển thị form tạo lịch hàng loạt
  void _showRecurringSessionForm(
    BuildContext context,
    AdminService adminSvc,
    String classId,
  ) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: 'Buổi học');
    final locationCtrl = TextEditingController(text: 'Tại lớp');
    final durationCtrl = TextEditingController(text: '90');
    final weeksCtrl = TextEditingController(text: '15');
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm lịch học hàng loạt'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      TextFormField(
                        controller: weeksCtrl,
                        decoration: const InputDecoration(labelText: 'Số tuần'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0
                            ? 'Phải là số lớn hơn 0'
                            : null,
                      ),
                      TextFormField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Địa điểm',
                        ),
                      ),
                      TextFormField(
                        controller: durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng (phút)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chọn ngày giờ cho buổi ĐẦU TIÊN:',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
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
                      await adminSvc.createRecurringSessions(
                        classId: classId,
                        baseTitle: titleCtrl.text.trim(),
                        location: locationCtrl.text.trim(),
                        firstSessionStartTime: startTime,
                        durationInMinutes:
                            int.tryParse(durationCtrl.text) ?? 90,
                        numberOfWeeks: int.tryParse(weeksCtrl.text) ?? 1,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Tạo lịch'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog để chọn và thêm một sinh viên
  void _showAddStudentDialog(
    BuildContext context,
    AdminService adminSvc,
    String classId,
  ) async {
    // Hiển thị loading trong khi fetch dữ liệu
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

    // Lọc ra những sinh viên chưa có trong lớp
    final availableStudents = allStudents
        .where((s) => !enrolledStudentIds.contains(s.uid))
        .toList();

    if (context.mounted) Navigator.of(context).pop(); // Tắt loading

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
                  items: availableStudents.map((student) {
                    return DropdownMenuItem(
                      value: student.uid,
                      child: Text(
                        '${student.displayName} (${student.email})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
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
