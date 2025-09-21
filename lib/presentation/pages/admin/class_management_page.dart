// lib/presentation/pages/admin/class_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/class_model.dart';
import '../../../services/firebase/admin/admin_service.dart';
import 'class_form_page.dart';
import 'admin_class_detail_page.dart'; // <<<--- IMPORT TRANG MỚI

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
      appBar: AppBar(title: const Text('Quản lý lớp học')),
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'single') {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ClassFormPage()));
          } else if (value == 'bulk') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chức năng Import từ file sẽ được thêm sau.'),
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
          PopupMenuItem(
            value: 'bulk',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Thêm từ file'),
            ),
          ),
        ],
        child: FloatingActionButton(
          heroTag: 'fab_class_management_page',
          tooltip: 'Thêm lớp học',
          child: const Icon(Icons.add),
          onPressed: null, // Để PopupMenuButton xử lý
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên môn, mã môn, GV...',
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
                final filteredClasses = allClasses.where((c) {
                  final query = _searchQuery.toLowerCase();
                  return (c.courseName?.toLowerCase() ?? '').contains(query) ||
                      (c.courseCode?.toLowerCase() ?? '').contains(query) ||
                      (c.lecturerName?.toLowerCase() ?? '').contains(query) ||
                      c.semester.toLowerCase().contains(query);
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
                        title: Text(
                          '${classInfo.courseCode ?? ''} - ${classInfo.courseName ?? '...'}',
                        ),
                        subtitle: Text(
                          'GV: ${classInfo.lecturerName ?? '...'} | HK: ${classInfo.semester}',
                        ),

                        // <<<--- THAY ĐỔI QUAN TRỌNG TẠI ĐÂY ---<<<
                        onTap: () {
                          // Điều hướng đến trang chi tiết của Admin, truyền theo cả đối tượng classInfo
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminClassDetailPage(classInfo: classInfo),
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
        content: Text(
          'Lớp học "${classInfo.courseName}" sẽ bị ẩn đi. Bạn có chắc chắn?',
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
