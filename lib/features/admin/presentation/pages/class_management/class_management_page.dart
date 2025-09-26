// lib/features/admin/presentation/pages/class_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/data/models/class_model.dart';
import '../../../../common/data/models/course_model.dart';
import '../../../data/services/admin_service.dart';
import 'class_bulk_import_page.dart';
import 'class_enrollments_bulk_import_page.dart';
import 'class_form_page.dart';
import 'admin_class_detail_page.dart';

class ClassManagementPage extends StatefulWidget {
  const ClassManagementPage({super.key});

  @override
  State<ClassManagementPage> createState() => _ClassManagementPageState();
}

class _ClassManagementPageState extends State<ClassManagementPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text),
    );
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
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên lớp, mã lớp,...', // Cập nhật hint text
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _searchController.clear,
                  )
                : null,
          ),
        ),
      ),
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'single') {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ClassFormPage()));
            // } else if (value == 'bulk') {
            //   Navigator.of(context).push(
            //     MaterialPageRoute(builder: (_) => const ClassBulkImportPage()),
            //   );
          } else if (value == 'bulk_enroll') {
            // <<< TÍCH HỢP: Xử lý sự kiện cho mục menu mới
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ClassEnrollmentsBulkImportPage(),
              ),
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'single',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Thêm 1 lớp học'),
            ),
          ),
          // PopupMenuItem(
          //   value: 'bulk',
          //   child: ListTile(
          //     leading: Icon(Icons.upload_file),
          //     title: Text('Thêm lớp học từ file'),
          //   ),
          // ),
          // <<< TÍCH HỢP: Thêm mục menu để import nhiều lớp học
          PopupMenuItem(
            value: 'bulk_enroll',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Thêm nhiều lớp học từ file'),
            ),
          ),
        ],
        child: FloatingActionButton(
          heroTag: 'fab_class_management_page',
          tooltip: 'Thêm lớp học',
          onPressed: null,
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ClassModel>>(
              stream: adminService.getAllClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${snapshot.error}'),
                  );
                }

                final allClasses = snapshot.data ?? [];
                // CẬP NHẬT LOGIC TÌM KIẾM
                final filteredClasses = allClasses.where((c) {
                  final query = _searchQuery.toLowerCase();
                  return c.className.toLowerCase().contains(query) ||
                      c.classCode.toLowerCase().contains(query);
                }).toList();

                if (filteredClasses.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Không tìm thấy lớp học nào.'
                          : 'Chưa có lớp học nào.\nNhấn nút + để thêm mới.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: filteredClasses.length,
                  itemBuilder: (context, index) {
                    final classInfo = filteredClasses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.class_outlined),
                        ),

                        // === THAY ĐỔI HIỂN THỊ CHÍNH ===
                        title: Text(
                          '${classInfo.classCode} - ${classInfo.className}',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminClassDetailPage(classId: classInfo.id),
                            ),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClassFormPage(classInfo: classInfo),
                                ),
                              ),
                              tooltip: 'Chỉnh sửa',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.archive_outlined,
                                color: Colors.orange,
                              ),
                              onPressed: () => _archiveClass(
                                context,
                                adminService,
                                classInfo,
                              ),
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
          ),
        ],
      ),
    );
  }

  void _archiveClass(
    BuildContext context,
    AdminService service,
    ClassModel classInfo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ'),
        // Cập nhật lại nội dung dialog
        content: Text(
          'Lớp học "${classInfo.className}" sẽ bị ẩn đi. Bạn có chắc chắn?',
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

    if (confirm == true && mounted) {
      try {
        await service.archiveClass(classInfo.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu trữ lớp học thành công.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// === WIDGET HELPER ĐẶT TẠI ĐÂY CHO TIỆN LỢI ===
class _ClassCourseInfo extends StatelessWidget {
  final List<String> courseIds;
  const _ClassCourseInfo({required this.courseIds});

  @override
  Widget build(BuildContext context) {
    if (courseIds.isEmpty) {
      return const Text(
        'Chưa có môn học',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    // Sử dụng FutureBuilder để lấy thông tin chi tiết của các môn học từ ID
    return FutureBuilder<List<CourseModel>>(
      // Gọi hàm mới trong service mà chúng ta sẽ thêm vào
      future: context.read<AdminService>().getCoursesByIds(courseIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'Lỗi tải môn học',
            style: TextStyle(color: Colors.red),
          );
        }

        // Ghép mã các môn học lại thành một chuỗi để hiển thị
        final courseText = snapshot.data!.map((c) => c.courseCode).join(' | ');
        return Text(
          courseText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        );
      },
    );
  }
}
