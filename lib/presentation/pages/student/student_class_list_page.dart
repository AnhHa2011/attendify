// lib/presentation/pages/student/student_class_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// THÊM CÁC IMPORT MỚI CẦN THIẾT
import '../../../app/providers/auth_provider.dart';
import '../../../services/firebase/classes/class_service.dart';

import '../../../data/models/class_model.dart';
import '../classes/class_detail_page.dart';

class StudentClassListPage extends StatelessWidget {
  const StudentClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // === THAY ĐỔI 1: SỬ DỤNG SERVICE VÀ AUTH PROVIDER TRỰC TIẾP ===
    // Không dùng StudentClassProvider nữa
    final classService = context.read<ClassService>();
    final auth = context.watch<AuthProvider>();
    final studentId = auth.user?.uid;

    // Trường hợp an toàn: nếu không lấy được ID sinh viên thì báo lỗi
    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Các lớp đã tham gia')),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Các lớp đã tham gia')),
      body: StreamBuilder<List<ClassModel>>(
        // === THAY ĐỔI 2: GỌI HÀM STREAM MỚI DÀNH CHO SINH VIÊN ===
        stream: classService.getRichEnrolledClassesStream(studentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Bạn chưa tham gia lớp học nào.\nHãy vào mục "Tham gia lớp" để bắt đầu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];

              // === THAY ĐỔI 3: HIỂN THỊ CÁC TRƯỜNG DỮ LIỆU MỚI ===
              return ListTile(
                title: Text(
                  '${c.courseCode ?? "N/A"} • ${c.courseName ?? "..."}',
                ),
                subtitle: Text('GV: ${c.lecturerName ?? "..."}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Điều hướng đến trang chi tiết của lớp học
                  // Sinh viên có thể xem chi tiết nhưng không có quyền chỉnh sửa
                  // ClassDetailPage sẽ cần được điều chỉnh sau để phân quyền
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassDetailPage(classId: c.id),
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
