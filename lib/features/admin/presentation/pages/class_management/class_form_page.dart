// lib/presentation/pages/admin/class_form_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/data/models/class_model.dart';
import '../../../../common/data/models/course_model.dart';
import '../../../../common/data/models/user_model.dart';
import '../../../data/services/admin_service.dart';

class ClassFormPage extends StatefulWidget {
  final ClassModel? classInfo; // Nếu null là Thêm mới, ngược lại là Sửa
  const ClassFormPage({super.key, this.classInfo});

  @override
  State<ClassFormPage> createState() => _ClassFormPageState();
}

class _ClassFormPageState extends State<ClassFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _semesterCtrl = TextEditingController();
  final _classNameCtrl = TextEditingController();
  String? _selectedCourseId;
  String? _selectedLecturerId;
  bool _isLoading = false;

  // Dùng Future.wait để lấy cả 2 danh sách cùng lúc, tối ưu hiệu năng
  late Future<List<dynamic>> _dataFuture;

  bool get _isEditMode => widget.classInfo != null;

  @override
  void initState() {
    super.initState();
    final adminService = context.read<AdminService>();
    _dataFuture = Future.wait([
      adminService.getAllCoursesStream().first,
      adminService.getAllLecturersStream().first,
    ]);

    if (_isEditMode) {
      final classInfo = widget.classInfo!;
      _selectedCourseId = classInfo.courseId;
      _selectedLecturerId = classInfo.lecturerId;
      _semesterCtrl.text = classInfo.semester;
      _classNameCtrl.text = classInfo.className ?? '';
    }
  }

  @override
  void dispose() {
    _semesterCtrl.dispose();
    _classNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final adminService = context.read<AdminService>();

    try {
      final isDuplicate = await adminService.isClassDuplicate(
        courseId: _selectedCourseId!,
        semester: _semesterCtrl.text.trim(),
        className: _classNameCtrl.text.trim().isEmpty
            ? null
            : _classNameCtrl.text.trim(),
        currentClassId: widget.classInfo?.id,
      );

      if (isDuplicate) {
        throw Exception('Lớp học này (Môn + Học kỳ + Tên lớp) đã tồn tại.');
      }

      if (_isEditMode) {
        await adminService.updateClass(
          classId: widget.classInfo!.id,
          courseId: _selectedCourseId!,
          lecturerId: _selectedLecturerId!,
          semester: _semesterCtrl.text.trim(),
          className: _classNameCtrl.text.trim().isEmpty
              ? null
              : _classNameCtrl.text.trim(),
        );
      } else {
        await adminService.createClass(
          courseId: _selectedCourseId!,
          lecturerId: _selectedLecturerId!,
          semester: _semesterCtrl.text.trim(),
          className: _classNameCtrl.text.trim().isEmpty
              ? null
              : _classNameCtrl.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Cập nhật thành công!' : 'Tạo lớp thành công!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Cập nhật lớp học' : 'Tạo lớp học mới'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Lỗi tải dữ liệu Môn học hoặc Giảng viên: ${snapshot.error}',
              ),
            );
          }

          final courses = snapshot.data![0] as List<CourseModel>;
          final lecturers = snapshot.data![1] as List<UserModel>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn môn học',
                      border: OutlineInputBorder(),
                    ),
                    items: courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              '${course.courseCode} - ${course.courseName}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCourseId = value),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn môn học' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLecturerId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn giảng viên phụ trách',
                      border: OutlineInputBorder(),
                    ),
                    items: lecturers
                        .map(
                          (lecturer) => DropdownMenuItem(
                            value: lecturer.uid,
                            child: Text(lecturer.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLecturerId = value),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn giảng viên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      border: OutlineInputBorder(),
                      hintText: 'Ví dụ: HK1 2025-2026',
                    ),
                    // === NÂNG CẤP: BẮT FORMAT CHO HỌC KỲ ===
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập học kỳ';
                      }
                      final semesterRegex = RegExp(r'^HK[1-3]\s\d{4}-\d{4}$');
                      if (!semesterRegex.hasMatch(value.trim())) {
                        return 'Sai định dạng. Ví dụ đúng: HK1 2025-2026';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _classNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên lớp (không bắt buộc)',
                      border: OutlineInputBorder(),
                      hintText: 'Ví dụ: L01 hoặc CLC02',
                    ),
                    // === NÂNG CẤP: BẮT FORMAT CHO TÊN LỚP (NẾU CÓ) ===
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null; // Bỏ qua nếu không nhập
                      }
                      final classNameRegex = RegExp(r'^[A-Z]+\d{2}$');
                      if (!classNameRegex.hasMatch(
                        value.trim().toUpperCase(),
                      )) {
                        return 'Sai định dạng. Ví dụ đúng: L01, CLC02';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.add_circle_outline),
                    label: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Text(_isEditMode ? 'Lưu thay đổi' : 'Tạo lớp'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
