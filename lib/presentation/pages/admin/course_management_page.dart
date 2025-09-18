// lib/presentation/pages/admin/course_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/course_model.dart';
import '../../../services/firebase/admin_service.dart';
import 'course_form_page.dart';

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AdminService>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm theo tên hoặc mã môn...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _searchController.clear,
                  )
                : null,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CourseFormPage()),
          );
        },
        tooltip: 'Thêm môn học',
        child: const Icon(Icons.add),
      ),
      // Đây chính là phần chịu trách nhiệm lấy và liệt kê danh sách môn học
      body: StreamBuilder<List<CourseModel>>(
        // 1. Dùng stream này để LẤY danh sách môn học từ Firebase
        stream: adminService.getAllCoursesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }

          final allCourses = snapshot.data ?? [];
          final filteredCourses = allCourses.where((course) {
            final query = _searchQuery.toLowerCase();
            return course.courseName.toLowerCase().contains(query) ||
                course.courseCode.toLowerCase().contains(query);
          }).toList();

          // === PHẦN BỊ THIẾU ĐÃ ĐƯỢC HOÀN THIỆN ===
          if (filteredCourses.isEmpty) {
            // Hiển thị thông báo tùy theo việc có đang tìm kiếm hay không
            return Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Không tìm thấy môn học nào.'
                    : 'Chưa có môn học nào.\nNhấn nút + để thêm mới.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          // 2. Dùng ListView.builder để HIỂN THỊ (liệt kê) danh sách đã lấy được
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.school_outlined),
                  ),
                  title: Text(
                    course.courseName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${course.courseCode} - ${course.credits} tín chỉ',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CourseFormPage(course: course),
                            ),
                          );
                        },
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.archive_outlined,
                          color: Colors.orange,
                        ),
                        onPressed: () =>
                            _archiveCourse(context, adminService, course),
                        tooltip: 'Lưu trữ',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Hàm xử lý việc lưu trữ môn học
  void _archiveCourse(
    BuildContext context,
    AdminService adminService,
    CourseModel course,
  ) async {
    // ... (logic của hàm này đã đúng, không cần thay đổi)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ'),
        content: Text(
          'Môn học "${course.courseName}" sẽ được ẩn đi. Bạn có chắc chắn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Lưu trữ',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await adminService.archiveCourse(course.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu trữ môn học thành công.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
