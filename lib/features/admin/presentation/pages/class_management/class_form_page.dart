// lib/features/admin/presentation/pages/class_form_page.dart
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

  final _classNameCtrl = TextEditingController();
  final _classCodeCtrl = TextEditingController();
  // <<< THAY ĐỔI 1: Bỏ semester controller
  // final _semesterCtrl = TextEditingController();
  List<String> _selectedCourseIds = [];
  String? _selectedLecturerId;
  // <<< THAY ĐỔI 2: Thêm biến state cho học kỳ được chọn
  String? _selectedSemester;

  bool _isSubmitting = false;
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
      _selectedCourseIds = List<String>.from(classInfo.courseIds);
      _selectedLecturerId = classInfo.lecturerId;
      _classNameCtrl.text = classInfo.className;
      _classCodeCtrl.text = classInfo.classCode;
      // <<< THAY ĐỔI 3: Gán giá trị cho biến state mới khi ở chế độ sửa
      _selectedSemester = classInfo.semester;
    } else {
      // <<< THAY ĐỔI 4: Gán giá trị mặc định khi ở chế độ thêm mới
      _selectedSemester = _generateRecentSemesters().first;
    }
  }

  // <<< THAY ĐỔI 5: Thêm hàm helper để tạo danh sách học kỳ
  List<String> _generateRecentSemesters() {
    final List<String> semesters = [];
    final now = DateTime.now();
    int currentYear = now.year;
    int currentMonth = now.month;

    int semesterNum;
    int academicYearStart;

    // Logic xác định học kỳ và năm học HIỆN TẠI vẫn giữ nguyên
    if (currentMonth >= 9 && currentMonth <= 12) {
      // HK1
      semesterNum = 1;
      academicYearStart = currentYear;
    } else if (currentMonth >= 1 && currentMonth <= 6) {
      // HK2
      semesterNum = 2;
      academicYearStart = currentYear - 1;
    } else {
      // HK3 (Hè)
      semesterNum = 3;
      academicYearStart = currentYear - 1;
    }

    // Vòng lặp để sinh ra 6 học kỳ TÍNH TỪ HIỆN TẠI TRỞ VỀ TƯƠNG LAI
    for (int i = 0; i < 6; i++) {
      // 1. Thêm học kỳ hiện tại vào danh sách
      semesters.add(
        'HK$semesterNum ${academicYearStart}-${academicYearStart + 1}',
      );

      // 2. Tính toán cho học kỳ TIẾP THEO
      semesterNum++;
      // Nếu học kỳ tiếp theo lớn hơn 3 (tức là đã hết HK3)
      if (semesterNum > 3) {
        semesterNum = 1; // Quay trở lại HK1
        academicYearStart++; // Và tăng năm học lên
      }
    }
    return semesters;
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    _classCodeCtrl.dispose();
    // <<< THAY ĐỔI 6: Bỏ dispose cho controller cũ
    // _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Thêm kiểm tra cho _selectedSemester
    if (!_formKey.currentState!.validate() || _selectedSemester == null) return;
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một môn học'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final adminService = context.read<AdminService>();

    try {
      final isDuplicate = await adminService.isClassDuplicate(
        classCode: _classCodeCtrl.text.trim(),
        currentClassId: widget.classInfo?.id,
      );

      if (isDuplicate) {
        throw Exception('Mã lớp học này đã tồn tại.');
      }

      // <<< THAY ĐỔI 7: Dùng _selectedSemester thay vì _semesterCtrl.text
      if (_isEditMode) {
        await adminService.updateClass(
          classId: widget.classInfo!.id,
          courseIds: _selectedCourseIds,
          lecturerId: _selectedLecturerId!,
          semester: _selectedSemester!,
          className: _classNameCtrl.text.trim(),
          classCode: _classCodeCtrl.text.trim(),
        );
      } else {
        await adminService.createClass(
          courseIds: _selectedCourseIds,
          lecturerId: _selectedLecturerId!,
          semester: _selectedSemester!,
          className: _classNameCtrl.text.trim(),
          classCode: _classCodeCtrl.text.trim(),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // <<< THAY ĐỔI 8: Gọi hàm để lấy danh sách học kỳ
    final recentSemesters = _generateRecentSemesters();

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
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }

          final courses = snapshot.data![0] as List<CourseModel>;
          final lecturers = snapshot.data![1] as List<UserModel>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _classNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên lớp học',
                      border: OutlineInputBorder(),
                      hintText: 'Ví dụ: Lớp Tín chỉ K15',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Vui lòng nhập tên lớp' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _classCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mã lớp học',
                      border: OutlineInputBorder(),
                      hintText: 'Ví dụ: LTC_IT_K15_01',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Vui lòng nhập mã lớp' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn các môn học cho lớp này:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: courses.map((course) {
                        final isSelected = _selectedCourseIds.contains(
                          course.id,
                        );
                        return FilterChip(
                          label: Text(
                            '${course.courseCode} - ${course.courseName}',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCourseIds.add(course.id);
                              } else {
                                _selectedCourseIds.remove(course.id);
                              }
                            });
                          },
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        );
                      }).toList(),
                    ),
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

                  // <<< THAY ĐỔI 9: Thay thế TextFormField bằng DropdownButtonFormField
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
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.save),
                    label: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
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
