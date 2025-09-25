import '../../../../../app_imports.dart';

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
  final _semesterCtrl = TextEditingController();
  List<String> _selectedCourseIds = []; // <<<--- LƯU DANH SÁCH ID MÔN HỌC
  String? _selectedLecturerId;

  bool _isSubmitting = false;
  late Future<List<dynamic>> _dataFuture;

  bool get _isEditMode => widget.classInfo != null;

  @override
  void initState() {
    super.initState();
    final adminService = context.read<AdminService>();
    // Dùng Future.wait để lấy cả 2 danh sách cùng lúc, tối ưu hiệu năng
    _dataFuture = Future.wait([
      adminService.getAllCoursesStream().first,
      adminService.getAllLecturersStream().first, // Gọi hàm mới
    ]);

    // Nếu là form sửa, điền dữ liệu cũ vào
    if (_isEditMode) {
      final classInfo = widget.classInfo!;
      _selectedCourseIds = List<String>.from(
        classInfo.courseIds,
      ); // Tạo list mới
      _selectedLecturerId = classInfo.lecturerId;
      _classNameCtrl.text = classInfo.className;
      _classCodeCtrl.text = classInfo.classCode;
      _semesterCtrl.text = classInfo.semester;
    }
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    _classCodeCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
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

      if (_isEditMode) {
        await adminService.updateClass(
          classId: widget.classInfo!.id,
          courseIds: _selectedCourseIds,
          lecturerId: _selectedLecturerId!,
          semester: _semesterCtrl.text.trim(),
          className: _classNameCtrl.text.trim(),
          classCode: _classCodeCtrl.text.trim(),
        );
      } else {
        await adminService.createClass(
          courseIds: _selectedCourseIds,
          lecturerId: _selectedLecturerId!,
          semester: _semesterCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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

                  // === UI CHỌN NHIỀU MÔN HỌC BẰNG FILTERCHIP ===
                  // const Text(
                  //   'Chọn các môn học cho lớp này:',
                  //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  // ),
                  // const SizedBox(height: 8),
                  // Container(
                  //   padding: const EdgeInsets.all(12),
                  //   decoration: BoxDecoration(
                  //     border: Border.all(color: Colors.grey.shade400),
                  //     borderRadius: BorderRadius.circular(8),
                  //   ),
                  //   child: Wrap(
                  //     spacing: 8.0,
                  //     runSpacing: 4.0,
                  //     children: courses.map((course) {
                  //       final isSelected = _selectedCourseIds.contains(
                  //         course.id,
                  //       );
                  //       return FilterChip(
                  //         label: Text(
                  //           '${course.courseCode} - ${course.courseName}',
                  //         ),
                  //         selected: isSelected,
                  //         onSelected: (selected) {
                  //           setState(() {
                  //             if (selected) {
                  //               _selectedCourseIds.add(course.id);
                  //             } else {
                  //               _selectedCourseIds.remove(course.id);
                  //             }
                  //           });
                  //         },
                  //         selectedColor: Theme.of(
                  //           context,
                  //         ).colorScheme.primaryContainer,
                  //       );
                  //     }).toList(),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),

                  // DropdownButtonFormField<String>(
                  //   initialValue: _selectedLecturerId,
                  //   decoration: const InputDecoration(
                  //     labelText: 'Chọn giảng viên phụ trách',
                  //     border: OutlineInputBorder(),
                  //   ),
                  //   items: lecturers
                  //       .map(
                  //         (lecturer) => DropdownMenuItem(
                  //           value: lecturer.uid,
                  //           child: Text(lecturer.displayName),
                  //         ),
                  //       )
                  //       .toList(),
                  //   onChanged: (value) =>
                  //       setState(() => _selectedLecturerId = value),
                  //   validator: (v) =>
                  //       v == null ? 'Vui lòng chọn giảng viên' : null,
                  // ),
                  // const SizedBox(height: 16),
                  TextFormField(
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      border: OutlineInputBorder(),
                      hintText: 'Ví dụ: HK1 2025-2026',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Vui lòng nhập học kỳ' : null,
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
