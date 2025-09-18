// lib/presentation/pages/admin/admin_class_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// THÊM CÁC IMPORT MỚI CẦN THIẾT
import '../../../services/firebase/classes/class_service.dart';
import '../../../data/models/class_model.dart';
import '../classes/class_detail_page.dart';

class AdminClassListPage extends StatefulWidget {
  const AdminClassListPage({super.key});

  @override
  State<AdminClassListPage> createState() => _AdminClassListPageState();
}

class _AdminClassListPageState extends State<AdminClassListPage> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    // === THAY ĐỔI 1: SỬ DỤNG SERVICE TRỰC TIẾP ===
    // Không dùng AdminClassProvider nữa
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Lớp học')),
      body: Column(
        children: [
          // Filter theo giảng viên
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Map<String, String>>>(
              // Gọi hàm từ service
              stream: classService.lecturersStream(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedLecturerUid,
                  hint: const Text('Lọc theo giảng viên'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả giảng viên'),
                    ),
                    ...list.map(
                      (m) => DropdownMenuItem<String>(
                        value: m['uid'],
                        child: Text('${m['name']} — ${m['email']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedLecturerUid = v),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClassModel>>(
              // === THAY ĐỔI 2: GỌI CÁC HÀM STREAM "LÀM GIÀU" DỮ LIỆU ===
              stream: _selectedLecturerUid == null
                  ? classService.getRichClassesStream()
                  : classService.getRichClassesStreamForLecturer(
                      _selectedLecturerUid!,
                    ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Đã xảy ra lỗi: ${snap.error}'));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('Không có lớp học nào.'));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];

                    // === THAY ĐỔI 3: HIỂN THỊ CÁC TRƯỜNG DỮ LIỆU MỚI ===
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          '${c.courseCode ?? "N/A"} • ${c.courseName ?? "..."}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GV: ${c.lecturerName ?? "..."}'),
                            Text('Học kỳ: ${c.semester}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Điều hướng không thay đổi
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassDetailPage(classId: c.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
