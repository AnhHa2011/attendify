// lib/presentation/pages/classes/create_class_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/class_model.dart';
import '../../../data/models/course_model.dart'; // Import model mới
import '../../../services/firebase/class_service.dart';
import 'class_detail_page.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();

  // === THAY ĐỔI STATE: LƯU ID THAY VÌ TEXTCONTROLLER ===
  String? _selectedCourseId;
  String? _selectedLecturerId;
  final _semesterCtrl = TextEditingController(text: 'HK1 2025-2026');
  final _maxAbsCtrl = TextEditingController(text: '3');
  // Lịch học vẫn giữ nguyên
  int _day = 1;
  final _startCtrl = TextEditingController(text: '07:30');
  final _endCtrl = TextEditingController(text: '09:30');

  bool _submitting = false;

  @override
  void dispose() {
    _semesterCtrl.dispose();
    _maxAbsCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final svc = context.read<ClassService>();

      // === THAY ĐỔI LOGIC SUBMIT: DÙNG ID ĐÃ CHỌN ===
      final classId = await svc.createClass(
        courseId: _selectedCourseId!,
        lecturerId: _selectedLecturerId!,
        semester: _semesterCtrl.text.trim(),
        schedules: [
          ClassSchedule(day: _day, start: _startCtrl.text, end: _endCtrl.text),
        ],
        maxAbsences: int.parse(_maxAbsCtrl.text),
      );

      if (!mounted) return;

      // Chuyển hướng đến trang chi tiết lớp học
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClassDetailPage(classId: classId)),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tạo lớp thành công')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tạo lớp: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo lớp học mới')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // === THAY ĐỔI: DROPDOWN CHỌN MÔN HỌC ===
                  StreamBuilder<List<CourseModel>>(
                    stream: classService.getAllCoursesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const CircularProgressIndicator();
                      final courses = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        hint: const Text('Chọn môn học'),
                        items: courses.map((course) {
                          return DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              '${course.courseCode} - ${course.courseName}',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCourseId = value),
                        validator: (v) =>
                            v == null ? 'Vui lòng chọn môn học' : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // === THAY ĐỔI: DROPDOWN CHỌN GIẢNG VIÊN ===
                  StreamBuilder<List<Map<String, String>>>(
                    stream: classService
                        .lecturersStream(), // Giả sử hàm này vẫn tồn tại
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const CircularProgressIndicator();
                      final lecturers = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        value: _selectedLecturerId,
                        hint: const Text('Chọn giảng viên phụ trách'),
                        items: lecturers.map((lecturer) {
                          return DropdownMenuItem(
                            value: lecturer['uid'],
                            child: Text(
                              '${lecturer['name']} (${lecturer['email']})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedLecturerId = value),
                        validator: (v) =>
                            v == null ? 'Vui lòng chọn giảng viên' : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // === THAY ĐỔI: NHẬP HỌC KỲ ===
                  TextFormField(
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(labelText: 'Học kỳ'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập học kỳ' : null,
                  ),

                  // Các trường còn lại (lịch học, số buổi vắng) có thể giữ nguyên
                  // ...
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const CircularProgressIndicator()
                        : const Text('Tạo lớp'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
