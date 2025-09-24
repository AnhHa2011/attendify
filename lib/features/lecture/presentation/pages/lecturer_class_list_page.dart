// lib/features/lecture/presentation/pages/lecturer_class_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../app/providers/auth_provider.dart';
// === THAY ĐỔI 1: IMPORT RICHCLASSMODEL TỪ CLASS_SERVICE ===
import '../../../classes/data/services/class_service.dart';
import '../../../classes/presentation/pages/class_detail_page.dart';
// Chức năng tạo lớp nên do Admin quản lý, giảng viên có thể không cần
// import '../../../classes/presentation/pages/create_class_page.dart';

class LecturerClassListPage extends StatelessWidget {
  const LecturerClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();
    final auth = context.watch<AuthProvider>();
    final lecturerId = auth.user?.uid;

    if (lecturerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lớp của tôi')),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp của tôi'),
        // actions: [ // Cân nhắc bỏ nút tạo lớp ở đây
        //   IconButton(
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (_) => const CreateClassPage()),
        //       );
        //     },
        //     icon: const Icon(Icons.add),
        //     tooltip: 'Tạo lớp',
        //   ),
        // ],
      ),
      // === THAY ĐỔI 2: SỬA LẠI STREAMBUILDER VỚI RICHCLASSMODEL ===
      body: StreamBuilder<List<RichClassModel>>(
        // <<<--- Đổi thành RichClassModel
        stream: classService.getRichClassesStreamForLecturer(lecturerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snap.error}'));
          }
          final richClasses = snap.data ?? [];
          if (richClasses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Bạn chưa được phân công lớp nào.\nVui lòng liên hệ Admin để tạo lớp.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: richClasses.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final richClass = richClasses[i];
              // Bóc tách dữ liệu để dễ sử dụng
              final classInfo = richClass.classInfo;
              final courses = richClass.courses;

              // === THAY ĐỔI 3: HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ===
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                title: Text('${classInfo.classCode} - ${classInfo.className}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    // Hiển thị danh sách mã môn học
                    Text(
                      'Môn: ${courses.map((c) => c.courseCode).join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text('Học kỳ: ${classInfo.semester}'),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Điều hướng không thay đổi, chỉ cần truyền classId
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassDetailPage(classId: classInfo.id),
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
