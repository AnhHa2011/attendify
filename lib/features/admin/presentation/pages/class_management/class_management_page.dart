// lib/presentation/pages/admin/class_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/data/models/class_model.dart';
import '../../../data/services/admin_service.dart';
import 'admin_class_detail_page.dart';
import 'class_bulk_import_page.dart';
import 'class_form_page.dart';

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
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm theo tên hoặc mã lớp...',
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
          } else if (value == 'bulk') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClassBulkImportPage()),
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
              title: Text('Thêm danh sách lớp học từ file'),
            ),
          ),
        ],
        child: FloatingActionButton(
          heroTag: 'fab_class_management_page',
          tooltip: 'Thêm lớp học',
          onPressed: null,
          child: const Icon(Icons.add), // Để PopupMenuButton xử lý
        ),
      ),
      // Đây chính là phần chịu trách nhiệm lấy và liệt kê danh sách lớp học
      body: StreamBuilder<List<ClassModel>>(
        // 1. Dùng stream này để LẤY danh sách lớp học từ Firebase
        stream: adminService.getAllClassesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }

          final allClasss = snapshot.data ?? [];
          final filteredClasss = allClasss.where((classModel) {
            final query = _searchQuery.toLowerCase();
            return classModel!.className.toLowerCase().contains(query) ||
                classModel.classCode.toLowerCase().contains(query);
          }).toList();

          // === PHẦN BỊ THIẾU ĐÃ ĐƯỢC HOÀN THIỆN ===
          if (filteredClasss.isEmpty) {
            // Hiển thị thông báo tùy theo việc có đang tìm kiếm hay không
            return Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Không tìm thấy lớp học nào.'
                    : 'Chưa có lớp học nào.\nNhấn nút + để thêm mới.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          // 2. Dùng ListView.builder để HIỂN THỊ (liệt kê) danh sách đã lấy được
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: filteredClasss.length,
            itemBuilder: (context, index) {
              final classModel = filteredClasss[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,

                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.school_outlined),
                  ),
                  title: Text(
                    classModel.className,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${classModel.classCode} '),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminClassDetailPage(classCode: classModel.id),
                      ),
                    );
                  },
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
                                  ClassFormPage(classModel: classModel),
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
                            _archiveClass(context, adminService, classModel),
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

  // Hàm xử lý việc lưu trữ lớp học
  void _archiveClass(
    BuildContext context,
    AdminService adminService,
    ClassModel classModel,
  ) async {
    // ... (logic của hàm này đã đúng, không cần thay đổi)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ'),
        content: Text(
          'Lớp học "${classModel.className}" sẽ được ẩn đi. Bạn có chắc chắn?',
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
        await adminService.archiveClass(classModel.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu trữ lớp học thành công.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi::${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
