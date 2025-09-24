// lib/features/admin/presentation/page/admin_class_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/data/services/admin_service.dart';
import '../../../common/data/models/user_model.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../classes/presentation/pages/class_detail_page.dart';

class AdminClassListPage extends StatefulWidget {
  const AdminClassListPage({super.key});

  @override
  State<AdminClassListPage> createState() => _AdminClassListPageState();
}

class _AdminClassListPageState extends State<AdminClassListPage> {
  String? _selectedLecturerUid;

  @override
  Widget build(BuildContext context) {
    // Tách riêng 2 service để rõ ràng về vai trò
    final classService = context.read<ClassService>();
    final adminService = context.read<AdminService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách lớp học')),
      body: Column(
        children: [
          // === THAY ĐỔI 2: SỬA LẠI BỘ LỌC GIẢNG VIÊN ===
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<UserModel>>(
              // <<<--- Đổi thành UserModel
              stream: adminService
                  .getAllLecturersStream(), // <<<--- Gọi hàm từ AdminService
              builder: (context, snap) {
                final lecturers = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedLecturerUid,
                  hint: const Text('Lọc theo giảng viên'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả giảng viên'),
                    ),
                    ...lecturers.map(
                      (lecturer) => DropdownMenuItem<String>(
                        value: lecturer.uid,
                        child: Text(
                          '${lecturer.displayName} — ${lecturer.email}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedLecturerUid = v),
                );
              },
            ),
          ),
          // === THAY ĐỔI 3: SỬA LẠI STREAMBUILDER CHÍNH ĐỂ DÙNG RICHCLASSMODEL ===
          Expanded(
            child: StreamBuilder<List<RichClassModel>>(
              // <<<--- Đổi thành RichClassModel
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
                final richClasses = snap.data ?? [];
                if (richClasses.isEmpty) {
                  return const Center(child: Text('Không có lớp học nào.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                  itemCount: richClasses.length,
                  itemBuilder: (context, i) {
                    final richClass = richClasses[i];
                    // Bóc tách dữ liệu để dễ sử dụng
                    final classInfo = richClass.classInfo;
                    final courses = richClass.courses;
                    final lecturer = richClass.lecturer;

                    // === THAY ĐỔI 4: HIỂN THỊ DỮ LIỆU TỪ RICHCLASSMODEL ===
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          '${classInfo.classCode} - ${classInfo.className}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hiển thị danh sách mã môn học
                            Text(
                              courses.map((c) => c.courseCode).join(' | '),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('GV: ${lecturer?.displayName ?? "..."}'),
                            Text('Học kỳ: ${classInfo.semester}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Điều hướng bằng ID từ classInfo
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClassDetailPage(classId: classInfo.id),
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
