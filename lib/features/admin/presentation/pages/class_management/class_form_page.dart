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
  int? _startYear;
  int? _endYear;

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
      _classNameCtrl.text = classInfo.className;
      _classCodeCtrl.text = classInfo.classCode;
      _startYear = classInfo.academicYearStart;
      _endYear = classInfo.academicYearEnd;
    }
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    _classCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // validate năm học
    if ((_startYear ?? 0) > (_endYear ?? 9999)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Năm kết thúc phải ≥ năm bắt đầu')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final adminService = context.read<AdminService>();

    try {
      final isDuplicate = await adminService.isClassDuplicate(
        classCode: _classCodeCtrl.text.trim(),
        currentClassId: widget.classInfo?.id, // đúng: bỏ qua chính nó khi edit
      );
      if (isDuplicate) {
        throw Exception('Mã lớp học này đã tồn tại.');
      }

      if (_isEditMode) {
        // ✅ dùng id hiện có của document
        await adminService.updateClass(
          classId: widget.classInfo!.id,
          className: _classNameCtrl.text.trim(),
          academicYearStart: _startYear ?? DateTime.now().year,
          academicYearEnd: _endYear ?? DateTime.now().year,
          classCode: _classCodeCtrl.text.trim(), // nếu cho phép đổi mã lớp
        );
      } else {
        //  tạo mới: KHÔNG truyền id, để service tự tạo doc
        await adminService.createClass(
          className: _classNameCtrl.text.trim(),
          classCode: _classCodeCtrl.text.trim(),
          academicYearStart: _startYear ?? DateTime.now().year,
          academicYearEnd: _endYear ?? DateTime.now().year,
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
            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _startYear, // <-- sửa ở đây
                          items: List.generate(10, (i) {
                            final year = DateTime.now().year - 1 + i;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (v) => setState(() => _startYear = v),
                          decoration: const InputDecoration(
                            labelText: 'Năm bắt đầu',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null ? 'Chọn năm bắt đầu' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _endYear, // <-- sửa ở đây
                          items: List.generate(10, (i) {
                            final year = DateTime.now().year - 1 + i;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (v) => setState(() => _endYear = v),
                          decoration: const InputDecoration(
                            labelText: 'Năm kết thúc',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null ? 'Chọn năm kết thúc' : null,
                        ),
                      ),
                    ],
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
