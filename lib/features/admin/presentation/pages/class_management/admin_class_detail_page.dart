// lib/features/admin/presentation/pages/admin_class_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/models/class_model.dart';
import '../../../../../core/data/models/user_model.dart';
import '../../../../../core/data/services/class_service.dart';
import '../../../data/services/admin_service.dart';
import 'enrollment_bulk_import_page.dart';

class AdminClassDetailPage extends StatelessWidget {
  final String classCode;
  const AdminClassDetailPage({super.key, required this.classCode});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return StreamBuilder<ClassModel>(
      stream: classService.getRichClassStream(classCode),
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
          appBar: AppBar(
            title: Text(classInfo.className),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // === PHẦN THÔNG TIN lớp HỌC ===
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
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.person_outline,
                        'Tên lớp:',
                        classInfo?.className ?? '...',
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
                  if (value == 'import_file') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClassEnrollmentBulkImportPage(
                          classModel: classInfo,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<UserModel>>(
                stream: adminSvc.getClassEnrolledStudentsStream(classInfo.id),
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
                            onPressed: () async =>
                                await adminSvc.unenrollClassStudent(
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
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required Function(String) onSelected,
  }) {
    final Map<String, List<PopupMenuEntry<String>>> menuItems = {
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

  void _showAddStudentDialog(
    BuildContext context,
    AdminService adminSvc,
    String classCode,
  ) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final allStudents = await adminSvc.getAllStudentsStream().first;
      final enrolledStudents = await adminSvc
          .getClassEnrolledStudentsStream(classCode)
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
            title: const Text('Thêm sinh viên vào lớp học'),
            content: availableStudents.isEmpty
                ? const Text(
                    'Tất cả sinh viên đã tham gia lớp học hoặc chưa có sinh viên trong hệ thống.',
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
                            await adminSvc.enrollClassSingleStudent(
                              classCode,
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
}
