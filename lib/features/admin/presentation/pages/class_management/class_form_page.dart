// lib/presentation/pages/admin/class_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../core/data/models/class_model.dart';
import '../../../../../core/data/models/lecturer_lite.dart';
import '../../../data/services/admin_service.dart';

class ClassFormPage extends StatefulWidget {
  final ClassModel? classModel;
  const ClassFormPage({super.key, this.classModel});

  @override
  State<ClassFormPage> createState() => _ClassFormPageState();
}

class _ClassFormPageState extends State<ClassFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minStudentsCtrl;
  late final TextEditingController _maxStudentsCtrl;

  bool _isLoading = false;
  bool get _isEditMode => widget.classModel != null;

  @override
  void initState() {
    super.initState();

    _codeCtrl = TextEditingController(text: widget.classModel?.classCode ?? '');
    _nameCtrl = TextEditingController(text: widget.classModel?.className ?? '');

    _minStudentsCtrl = TextEditingController(
      text: widget.classModel?.minStudents != null
          ? widget.classModel!.minStudents.toString()
          : '',
    );
    _maxStudentsCtrl = TextEditingController(
      text: widget.classModel?.maxStudents != null
          ? widget.classModel!.maxStudents.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _minStudentsCtrl.dispose();
    _maxStudentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final adminService = context.read<AdminService>();
    final classCode = _codeCtrl.text.trim().toUpperCase();
    final className = _nameCtrl.text.trim();
    final minStudents = int.parse(_minStudentsCtrl.text);
    final maxStudents = int.parse(_maxStudentsCtrl.text);

    try {
      // Khi ở chế độ chỉnh sửa, không cần kiểm tra mã môn học đã tồn tại hay chưa
      // vì mã này không thể thay đổi.
      if (!_isEditMode) {
        final isTaken = await adminService.isCourseCodeTaken(
          classCode,
          currentcourseCode: widget.classModel?.id,
        );
        if (isTaken) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mã lớp học "$classCode" đã tồn tại.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Tạo/Cập nhật
      if (_isEditMode) {
        await adminService.updateClass(
          id: widget.classModel!.id,
          classCode: classCode,
          className: className,
          minStudents: minStudents > 0 ? minStudents : null,
          maxStudents: maxStudents > 0 ? maxStudents : null,
        );
      } else {
        await adminService.createClass(
          classCode: classCode,
          className: className,
          minStudents: minStudents > 0 ? minStudents : 10, // default
          maxStudents: maxStudents > 0 ? maxStudents : 50, // default
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'Cập nhật thành công!' : 'Thêm lớp học thành công!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Cập nhật lớp học' : 'Thêm lớp học mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ====== Class Code ======
              TextFormField(
                controller: _codeCtrl,
                // Thêm thuộc tính `enabled`
                enabled: !_isEditMode,
                decoration: InputDecoration(
                  labelText: 'Mã lớp học',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                  // Thay đổi helperText để người dùng hiểu rõ hơn
                  helperText: _isEditMode
                      ? 'Mã lớp học không thể thay đổi.'
                      : 'Ví dụ: IT4440. Sẽ tự động viết hoa.',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  UpperCaseTextFormatter(),
                ],
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),

              // ====== Class Name ======
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên lớp học',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),

              // ====== Min students ======
              TextFormField(
                controller: _minStudentsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số lượng sinh viên tối thiểu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Không được để trống';
                  }
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Phải là số > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ====== Max students ======
              TextFormField(
                controller: _maxStudentsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số lượng sinh viên tối đa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Không được để trống';
                  }
                  final maxN = int.tryParse(v);
                  final minN = int.tryParse(_minStudentsCtrl.text);
                  if (maxN == null || maxN <= 0) return 'Phải là số > 0';
                  if (minN != null && maxN <= minN) {
                    return 'Tối đa phải > tối thiểu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_alt_outlined),
                label: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(_isEditMode ? 'Lưu thay đổi' : 'Thêm lớp học'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====== Helpers ======
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
