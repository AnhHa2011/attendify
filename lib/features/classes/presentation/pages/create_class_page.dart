// lib/features/classes/presentation/pages/create_class_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/data/models/course_model.dart';
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
  String? _selectedSemester; // Dùng biến này thay cho TextEditingController
  final _maxAbsCtrl = TextEditingController(text: '3');

  // State cho lịch học
  int _dayOfWeek = 1; // Mặc định là Thứ 2
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 30);

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo giá trị mặc định cho học kỳ là học kỳ gần nhất
    _selectedSemester = _generateRecentSemesters().first;
  }

  @override
  void dispose() {
    _maxAbsCtrl.dispose();
    super.dispose();
  }

  // Hàm helper để tạo danh sách 6 học kỳ gần nhất
  List<String> _generateRecentSemesters() {
    final List<String> semesters = [];
    final now = DateTime.now();
    int currentYear = now.year;
    int currentMonth = now.month;

    // Xác định học kỳ và năm học hiện tại
    int semesterNum;
    int academicYearStart;

    if (currentMonth >= 9 && currentMonth <= 12) {
      // Học kỳ 1
      semesterNum = 1;
      academicYearStart = currentYear;
    } else if (currentMonth >= 1 && currentMonth <= 6) {
      // Học kỳ 2
      semesterNum = 2;
      academicYearStart = currentYear - 1;
    } else {
      // Học kỳ 3 (Hè)
      semesterNum = 3;
      academicYearStart = currentYear - 1;
    }

    // Sinh ra 6 học kỳ gần nhất bằng cách lùi dần
    for (int i = 0; i < 6; i++) {
      semesters.add(
        'HK$semesterNum ${academicYearStart}-${academicYearStart + 1}',
      );

      // Lùi học kỳ
      semesterNum--;
      if (semesterNum == 0) {
        semesterNum = 3; // Lùi từ HK1 về HK3
        academicYearStart--; // Lùi năm học
      }
    }
    return semesters;
  }

  Future<void> _submit() async {
    // Cập nhật điều kiện kiểm tra, thêm _selectedSemester
    if (!_formKey.currentState!.validate() ||
        _selectedCourseId == null ||
        _selectedLecturerId == null ||
        _selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }
    setState(() => _submitting = true);

    try {
      final svc = context.read<ClassService>();

      final classId = await svc.createClass(
        courseId: _selectedCourseId!,
        lecturerId: _selectedLecturerId!,
        semester: _selectedSemester!, // Sử dụng giá trị từ state
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
    final classService = context.read<ClassService>();
    final recentSemesters = _generateRecentSemesters();

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
                  // Dropdown chọn môn học
                  StreamBuilder<List<CourseModel>>(
                    stream: classService.getAllCoursesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Text(
                          'Không có môn học nào hoặc đã xảy ra lỗi.',
                        );
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

                  // Dropdown chọn giảng viên
                  StreamBuilder<List<Map<String, String>>>(
                    stream: classService.lecturersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Text(
                          'Không có giảng viên nào hoặc đã xảy ra lỗi.',
                        );
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

                  // Dropdown chọn học kỳ
                  DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    items: recentSemesters.map((semester) {
                      return DropdownMenuItem(
                        value: semester,
                        child: Text(semester),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSemester = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn học kỳ' : null,
                  ),
                  const SizedBox(height: 16),

                  // Hiển thị lịch học đã chọn
                  // TODO: Thêm UI để người dùng có thể thay đổi ngày và giờ
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Lịch học'),
                    subtitle: Text(
                      'Thứ ${_dayOfWeek + 1}, lúc ${_startTime.format(context)}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () {
                      // Bạn có thể thêm chức năng cho phép chỉnh sửa lịch học tại đây
                    },
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
