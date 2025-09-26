// lib/features/admin/presentation/pages/admin_course_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';

class AdminCourseDetailPage extends StatelessWidget {
  final String courseId;
  const AdminCourseDetailPage({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final courseService = context.read<AdminService>();

    return StreamBuilder<CourseModel>(
      stream: courseService.getRichCourseByIdStream(courseId),
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

        final courseInfo = snapshot.data!;
        final adminSvc = context.read<AdminService>();

        return Scaffold(
          appBar: AppBar(title: Text('Thông tin môn học')),
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
                        courseInfo.courseName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildInfoRow(
                        Icons.tag,
                        'Mã môn:',
                        courseInfo.courseCode,
                      ),
                      _buildInfoRow(
                        Icons.tag,
                        'Số tín chỉ:',
                        courseInfo.credits.toString(),
                      ),
                      _buildInfoRow(
                        Icons.tag,
                        'Giảng viên:',
                        courseInfo.lecturerName ??
                            '${courseInfo.lecturerName} ${courseInfo.lecturerEmail ?? '(${courseInfo.lecturerEmail})'}',
                      ),
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
                  switch (value) {
                    case 'add_single':
                      _showAddStudentDialog(context, adminSvc, courseInfo.id);

                    // case 'import_file':
                    //   _showAddStudentDialog(context, adminSvc, courseInfo.id);
                  }
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<UserModel>>(
                stream: adminSvc.getEnrolledStudentsStream(courseInfo.id),
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
                          child: Text('Chưa có sinh viên nào trong môn.'),
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
                                .unenrollStudent(courseInfo.id, student.uid),
                            tooltip: 'Xoá khỏi môn',
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

  void _showAddStudentDialog(
    BuildContext context,
    AdminService adminSvc,
    String courseId,
  ) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    // Load dữ liệu
    final allStudents = await adminSvc.getAllStudentsStream().first;
    final classEnrolledStudents = await adminSvc
        .getAllEnrolledStudentsStream()
        .first;
    final courseEnrolledStudents = await adminSvc
        .getCourseEnrolledStudentsStream(courseId)
        .first;
    final allClasses = await adminSvc.getAllClassesStream().first;

    final enrolledStudentIds = courseEnrolledStudents
        .map((s) => s.studentUid)
        .toSet();
    final availableStudents = allStudents
        .where((s) => !enrolledStudentIds.contains(s.uid))
        .toList();

    if (context.mounted) Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedStudentId;
        String? selectedClassId = 'ALL'; // Default là "All"

        return StatefulBuilder(
          builder: (context, setState) {
            // Filter sinh viên theo class được chọn
            List<UserModel> filteredStudents;
            if (selectedClassId == 'ALL') {
              filteredStudents = availableStudents;
            } else {
              // Lấy danh sách student IDs của class được chọn
              final classStudentIds = classEnrolledStudents
                  .where((enrollment) => enrollment.classId == selectedClassId)
                  .map((enrollment) => enrollment.studentUid)
                  .toSet();

              filteredStudents = availableStudents
                  .where((student) => classStudentIds.contains(student.uid))
                  .toList();
            }

            return AlertDialog(
              title: const Text('Thêm sinh viên vào môn'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown chọn class
                    const Text(
                      'Chọn lớp học:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedClassId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        // Option "All" mặc định
                        const DropdownMenuItem(
                          value: 'ALL',
                          child: Text('Tất cả lớp'),
                        ),
                        // Các class khác
                        ...allClasses.map(
                          (classItem) => DropdownMenuItem(
                            value: classItem.id,
                            child: Text(
                              '${classItem.className} (${classItem.classCode})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedClassId = value;
                          selectedStudentId = null; // Reset student selection
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Dropdown chọn sinh viên
                    const Text(
                      'Chọn sinh viên:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    if (filteredStudents.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          selectedClassId == 'ALL'
                              ? 'Tất cả sinh viên đã có trong môn hoặc chưa có sinh viên nào trong hệ thống.'
                              : 'Không có sinh viên khả dụng trong lớp này.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedStudentId,
                        hint: Text(
                          'Chọn sinh viên (${filteredStudents.length} khả dụng)',
                        ),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: filteredStudents
                            .map(
                              (student) => DropdownMenuItem(
                                value: student.uid,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${student.displayName} (${student.email})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStudentId = value;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Vui lòng chọn một sinh viên' : null,
                      ),

                    const SizedBox(height: 8),

                    // Hiển thị thông tin thống kê
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedClassId == 'ALL'
                                  ? 'Hiển thị ${filteredStudents.length} sinh viên từ tất cả lớp'
                                  : 'Hiển thị ${filteredStudents.length} sinh viên từ lớp đã chọn',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed:
                      (filteredStudents.isEmpty || selectedStudentId == null)
                      ? null
                      : () async {
                          try {
                            await adminSvc.enrollSingleStudent(
                              courseId,
                              selectedStudentId!,
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Thêm sinh viên thành công!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi: ${e.toString()}'),
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
        );
      },
    );
  }
}
