// lib/features/courses/presentation/pages/course_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
// === THAY ĐỔI 1: IMPORT RICHCLASSMODEL TỪ CLASS_SERVICE ===
import '../../../../core/data/models/rich_course_model.dart';
import '../../../../core/data/services/courses_service.dart';
import 'course_detail_page.dart';
// CreateCoursePage không cần thiết cho trang này nữa nếu logic tạo lớp đã chuyển đi
// import 'create_course_page.dart';

class CourseListPage extends StatelessWidget {
  const CourseListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final courseService = context.read<CourseService>();
    final auth = context.watch<AuthProvider>();
    final lecturerId = auth.user?.uid;

    if (lecturerId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Lớp của tôi'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Lớp của tôi'),
        // actions: [ // Cân nhắc bỏ nút tạo lớp ở đây nếu nó đã có ở nơi khác (vd: admin menu)
        //   IconButton(
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (_) => const CreateCoursePage()),
        //       );
        //     },
        //     icon: const Icon(Icons.add),
        //     tooltip: 'Tạo lớp',
        //   ),
        // ],
      ),
      // === THAY ĐỔI 2: SỬA LẠI STREAMBUILDER VỚI RICHCLASSMODEL ===
      body: StreamBuilder<List<RichCourseModel>>(
        // <<<--- Đổi thành RichCourseModel
        stream: courseService.getRichCoursesStreamForLecturer(lecturerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snap.error}'));
          }
          final richCourses = snap.data ?? [];
          if (richCourses.isEmpty) {
            return const Center(
              child: Text('Bạn chưa được phân công lớp nào.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: richCourses.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final richCourse = richCourses[i];
              // Bóc tách dữ liệu để dễ sử dụng
              final courseInfo = richCourse.courseInfo;

              // === THAY ĐỔI 3: HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ===
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  '${courseInfo.courseCode} - ${courseInfo.courseName}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    // Hiển thị danh sách mã môn học
                    Text(
                      'Học kỳ: ${courseInfo.semester} | Mã tham gia: ${courseInfo.joinCode}',
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Điều hướng vẫn giữ nguyên, CourseDetailPage chỉ cần courseCode
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(courseModel: courseInfo),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
