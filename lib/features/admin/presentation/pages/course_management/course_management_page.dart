// lib/features/admin/presentation/pages/course_management_page.dart

import 'dart:typed_data';

import 'package:attendify/core/data/services/session_service.dart';
import 'package:attendify/features/attendance/export/export_attendance_excel_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../../../../../core/data/models/course_model.dart';
import '../../../data/services/admin_service.dart';
import '../../../domain/repositories/export/export_syllabus_pdf_service.dart';
import 'import/course_bulk_import_page.dart';
import 'course_form_page.dart';
import 'detail/admin_course_detail_page.dart';
import 'package:printing/printing.dart';

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
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportSyllabus(BuildContext context, CourseModel course) async {
    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Gọi service để lấy dữ liệu bytes của file PDF
      final Uint8List pdfData = await ExportSyllabusPdfService.export(course);

      if (!mounted) return;
      Navigator.of(context).pop(); // Đóng loading

      // 2. Dùng package printing để xử lý file
      // Trên Web: Sẽ tự động mở tab mới và kích hoạt download
      // Trên Mobile: Sẽ mở màn hình preview để in hoặc lưu file
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name:
            'Syllabus_${course.courseCode}_${course.semester}', // Tên file khi tải về
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Đóng loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất đề cương thất bại: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportAttendance(BuildContext context, CourseModel course) async {
    final adminSvc = context.read<AdminService>();
    final sessionSvc = context.read<SessionService>();

    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Lấy dữ liệu cần export
      final users = await adminSvc.getEnrolledStudentsStream(course.id).first;
      final enrollments = await adminSvc.getEnrollmentsByCourse(course.id);
      final attendances = await adminSvc.getAttendancesByCourse(course.id);
      final leaveRequests = await adminSvc.getLeaveRequestsByCourse(course.id);
      final sessions = await sessionSvc.sessionsOfCourse(course.id).first;

      // Gọi export
      final savedPath = await ExportAttendanceExcelService.export(
        course: course,
        users: users,
        enrollments: enrollments,
        attendances: attendances,
        leaveRequests: leaveRequests,
        sessions: sessions,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // đóng loading

      // Thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Đã tải báo cáo (xem trong Downloads của trình duyệt)'
                : 'Đã lưu báo cáo tại: $savedPath',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Mở file (mobile/desktop)
      if (savedPath != null) {
        // Cần thêm package open_filex để mở file
        // await OpenFilex.open(savedPath);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // đóng loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất thống kê thất bại: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _normalize(String? s) {
    if (s == null) return '';
    final lower = s.toLowerCase();

    // Bỏ dấu tiếng Việt nhanh gọn (không thêm dependency)
    const viet =
        'áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';
    const latn =
        'aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooouuuuuuuuuuyyyyy';
    final map = {for (var i = 0; i < viet.length; i++) viet[i]: latn[i]};
    final sb = StringBuffer();
    for (final ch in lower.characters) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
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
            hintText: 'Tìm theo tên môn, mã môn, GV...', // Cập nhật hint text
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
            ).push(MaterialPageRoute(builder: (_) => const CourseFormPage()));
          } else if (value == 'bulk') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CourseBulkImportPage()),
            );
          }
          //  else if (value == 'bulk_enroll') {
          //   // <<< TÍCH HỢP: Xử lý sự kiện cho mục menu mới
          //   Navigator.of(context).push(
          //     MaterialPageRoute(
          //       builder: (_) => const CourseEnrollmentsBulkImportPage(),
          //     ),
          //   );
          // }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'single',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Thêm 1 môn học'),
            ),
          ),
          PopupMenuItem(
            value: 'bulk',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Thêm môn học từ file'),
            ),
          ),
          // <<< TÍCH HỢP: Thêm mục menu để import nhiều môn học
          // PopupMenuItem(
          //   value: 'bulk_enroll',
          //   child: ListTile(
          //     leading: Icon(Icons.upload_file),
          //     title: Text('Thêm nhiều môn học từ file'),
          //   ),
          // ),
        ],
        child: FloatingActionButton(
          heroTag: 'fab_course_management_page',
          tooltip: 'Thêm môn học',
          onPressed: null,
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CourseModel>>(
              stream: adminService.getAllCoursesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${snapshot.error}'),
                  );
                }

                final allcourses = snapshot.data ?? [];
                // CẬP NHẬT LOGIC TÌM KIẾM
                final filteredcourses = allcourses.where((c) {
                  final query = _searchQuery.toLowerCase();
                  return c.courseName.toLowerCase().contains(query) ||
                      c.courseCode.toLowerCase().contains(query) ||
                      (c.lecturerId?.toLowerCase() ?? '').contains(query) ||
                      (c.lecturerDisplayName?.toLowerCase() ?? '').contains(
                        query,
                      ) ||
                      (c.semester ?? '').toLowerCase().contains(query);
                }).toList();

                if (filteredcourses.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Không tìm thấy môn học nào.'
                          : 'Chưa có môn học nào.\nNhấn nút + để thêm mới.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: filteredcourses.length,
                  itemBuilder: (context, index) {
                    final courseInfo = filteredcourses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.class_outlined),
                        ),

                        // === THAY ĐỔI HIỂN THỊ CHÍNH ===
                        title: Text(
                          '${courseInfo.courseCode} - ${courseInfo.courseName}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dùng widget helper để hiển thị danh sách môn học
                            Text(
                              'GV: ${courseInfo.lecturerDisplayName} | HK: ${courseInfo.semester}',
                            ),
                          ],
                        ),
                        isThreeLine: true, // Cho phép subtitle có 3 dòng

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminCourseDetailPage(
                                courseCode: courseInfo.id,
                              ),
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
                                      CourseFormPage(courseModel: courseInfo),
                                ),
                              ),
                              tooltip: 'Chỉnh sửa',
                            ),
                            // Thêm IconButton để export
                            IconButton(
                              icon: const Icon(
                                Icons.download_outlined,
                                color: Colors.blue,
                              ),
                              onPressed: () =>
                                  _exportSyllabus(context, courseInfo),
                              tooltip: 'Xuất Syllabus (PDF)',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.archive_outlined,
                                color: Colors.orange,
                              ),
                              onPressed: () => _archiveCourse(
                                context,
                                adminService,
                                courseInfo,
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

  void _archiveCourse(
    BuildContext context,
    AdminService service,
    CourseModel courseInfo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ'),
        // Cập nhật lại nội dung dialog
        content: Text(
          'môn học "${courseInfo.courseName}" sẽ bị ẩn đi. Bạn có chắc chắn?',
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
        await service.archiveCourse(courseInfo.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu trữ môn học thành công.'),
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
class _CourseCourseInfo extends StatelessWidget {
  final List<String> courseCodes;
  const _CourseCourseInfo({required this.courseCodes});

  @override
  Widget build(BuildContext context) {
    if (courseCodes.isEmpty) {
      return const Text(
        'Chưa có môn học',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    // Sử dụng FutureBuilder để lấy thông tin chi tiết của các môn học từ ID
    return FutureBuilder<List<CourseModel>>(
      // Gọi hàm mới trong service mà chúng ta sẽ thêm vào
      future: context.read<AdminService>().getCoursesByIds(courseCodes),
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
