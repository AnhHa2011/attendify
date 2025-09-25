// lib/presentation/pages/classes/create_class_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/data/models/course_model.dart'; // Import model mới
import '../../data/services/class_service.dart';
import '../../../common/data/models/class_schedule_model.dart';
import 'class_detail_page.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCourseId;
  String? _selectedLecturerId;
  final _semesterCtrl = TextEditingController(text: 'HK1 2025-2026');
  final _maxAbsCtrl = TextEditingController(text: '3');

  // Sửa lại state cho lịch học để dễ quản lý
  int _dayOfWeek = 1; // Thứ 2
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 30);

  bool _submitting = false;

  @override
  void dispose() {
    _semesterCtrl.dispose();
    _maxAbsCtrl.dispose();
    super.dispose();
  }

  // === HÀM HELPER ĐỂ CHUYỂN ĐỔI STRING SANG TIMEOFDAY ===
  // (Bạn có thể bỏ qua hàm này nếu bạn dùng TimePicker để chọn giờ)
  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCourseId == null ||
        _selectedLecturerId == null) {
      // Thêm kiểm tra null cho Dropdown
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }
    setState(() => _submitting = true);

    try {
      final svc = context.read<ClassService>();

      // === PHẦN SỬA LỖI QUAN TRỌNG NHẤT ===
      // Sử dụng đúng tên tham số (dayOfWeek, startTime) và đúng kiểu dữ liệu.
      final classId = await svc.createClass(
        courseId: _selectedCourseId!,
        lecturerId: _selectedLecturerId!,
        semester: _semesterCtrl.text.trim(),
        schedules: [
          ClassSchedule(dayOfWeek: _dayOfWeek, startTime: _startTime),
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
    // Để code gọn hơn, có thể khai báo service ở đây
    final classService = context.read<ClassService>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tạo lớp học mới'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Dropdown chọn môn học (Code của bạn đã đúng)
                  StreamBuilder<List<CourseModel>>(
                    stream: classService.getAllCoursesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Không có môn học nào.');
                      }
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
                          labelText: 'Môn học',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dropdown chọn giảng viên (Code của bạn đã đúng)
                  StreamBuilder<List<Map<String, String>>>(
                    stream: classService.lecturersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Không có giảng viên nào.');
                      }
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
                          labelText: 'Giảng viên',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nhập học kỳ
                  TextFormField(
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập học kỳ' : null,
                  ),
                  const SizedBox(height: 16),

                  // TODO: Thêm UI để người dùng có thể chọn ngày và giờ ở đây
                  // Ví dụ đơn giản:
                  Text(
                    'Lịch học hiện tại: Thứ ${_dayOfWeek + 1}, lúc ${_startTime.format(context)}',
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
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
