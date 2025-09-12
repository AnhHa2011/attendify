// lib/presentation/pages/admin/course_management_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/course_model.dart';
import '../../../services/firebase/admin_service.dart';

class CourseManagementPage extends StatelessWidget {
  const CourseManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AdminService>();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Mở dialog để thêm môn học mới
          _showAddCourseDialog(context);
        },
        tooltip: 'Thêm môn học',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: adminService.getAllCoursesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(
              child: Text('Chưa có môn học nào trong hệ thống.'),
            );
          }

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text('${course.courseCode} - ${course.courseName}'),
                  subtitle: Text('Số tín chỉ: ${course.credits}'),
                  // Bạn có thể thêm nút sửa/xóa ở đây
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Hàm hiển thị Dialog để thêm môn học mới
  void _showAddCourseDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final creditsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final adminService = dialogContext.read<AdminService>();

        return AlertDialog(
          title: const Text('Thêm môn học mới'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Mã môn học'),
                  validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
                ),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên môn học'),
                  validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
                ),
                TextFormField(
                  controller: creditsCtrl,
                  decoration: const InputDecoration(labelText: 'Số tín chỉ'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await adminService.createCourse(
                    courseCode: codeCtrl.text.trim(),
                    courseName: nameCtrl.text.trim(),
                    credits: int.parse(creditsCtrl.text),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
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
