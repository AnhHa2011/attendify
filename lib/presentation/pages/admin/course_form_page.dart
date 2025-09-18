// lib/presentation/pages/admin/course_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/course_model.dart';
import '../../../services/firebase/admin/admin_service.dart';

class CourseFormPage extends StatefulWidget {
  final CourseModel? course;
  const CourseFormPage({super.key, this.course});

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _creditsCtrl;
  bool _isLoading = false;

  bool get _isEditMode => widget.course != null;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.course?.courseCode ?? '');
    _nameCtrl = TextEditingController(text: widget.course?.courseName ?? '');
    _creditsCtrl = TextEditingController(
      text: widget.course?.credits.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _creditsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // B1: Kiểm tra các validator cơ bản của form
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final adminService = context.read<AdminService>();
    final courseCode = _codeCtrl.text.trim().toUpperCase();
    final courseName = _nameCtrl.text.trim();
    final credits = int.parse(_creditsCtrl.text);

    try {
      // B2: KIỂM TRA TRÙNG LẶP MÃ MÔN HỌC
      final isTaken = await adminService.isCourseCodeTaken(
        courseCode,
        currentCourseId: widget.course?.id,
      );

      if (isTaken) {
        // Nếu mã đã tồn tại, hiển thị lỗi và dừng lại
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mã môn học "$courseCode" đã tồn tại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Dừng hàm tại đây
      }

      // B3: Nếu không trùng, tiến hành tạo mới hoặc cập nhật
      if (_isEditMode) {
        await adminService.updateCourse(
          courseId: widget.course!.id,
          courseCode: courseCode,
          courseName: courseName,
          credits: credits,
        );
      } else {
        await adminService.createCourse(
          courseCode: courseCode,
          courseName: courseName,
          credits: credits,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Cập nhật thành công!' : 'Thêm môn học thành công!',
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
            content: Text(
              'Lỗi: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
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
        title: Text(_isEditMode ? 'Cập nhật môn học' : 'Thêm môn học mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          // CẢI TIẾN: Tự động validate khi người dùng tương tác
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã môn học',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'Ví dụ: IT4440. Sẽ tự động viết hoa.',
                ),
                // CẢI TIẾN: Tự động viết hoa và cấm khoảng trắng
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'\s'),
                  ), // Cấm khoảng trắng
                  UpperCaseTextFormatter(),
                ],
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _creditsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số tín chỉ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // CẢI TIẾN: Validator kiểm tra số > 0
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Không được để trống';
                  }
                  final credits = int.tryParse(v);
                  if (credits == null || credits <= 0) {
                    return 'Số tín chỉ phải là một số lớn hơn 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
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
                    : Text(_isEditMode ? 'Lưu thay đổi' : 'Thêm môn học'),
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

// Lớp helper để tự động viết hoa, thêm vào cuối file
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
