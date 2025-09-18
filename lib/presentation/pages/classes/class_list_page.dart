// lib/presentation/pages/classes/class_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/providers/auth_provider.dart';
import '../../../services/firebase/classes/class_service.dart';

import '../../../data/models/class_model.dart';
import 'class_detail_page.dart';
import 'create_class_page.dart';

class ClassListPage extends StatelessWidget {
  const ClassListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // === THAY ĐỔI 1: SỬ DỤNG SERVICE VÀ AUTH PROVIDER TRỰC TIẾP ===
    // Không dùng ClassProvider nữa
    final classService = context.read<ClassService>();
    final auth = context.watch<AuthProvider>();
    final lecturerId = auth.user?.uid;

    // Trường hợp an toàn: nếu không lấy được ID giảng viên thì báo lỗi
    if (lecturerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lớp của tôi')),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp của tôi'),
        actions: [
          IconButton(
            onPressed: () {
              // Chức năng tạo lớp mới không thay đổi
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateClassPage()),
              );
            },
            icon: const Icon(Icons.add),
            tooltip: 'Tạo lớp',
          ),
        ],
      ),
      body: StreamBuilder<List<ClassModel>>(
        // === THAY ĐỔI 2: GỌI HÀM STREAM "LÀM GIÀU" DỮ LIỆU ===
        stream: classService.getRichClassesStreamForLecturer(lecturerId),
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
              child: Text('Bạn chưa được phân công lớp nào.'),
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
                subtitle: Text(
                  'Học kỳ: ${c.semester}\nMã tham gia: ${c.joinCode}',
                ),
                isThreeLine: true, // Cho phép subtitle hiển thị 2 dòng
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Điều hướng vẫn giữ nguyên, ClassDetailPage chỉ cần classId
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
