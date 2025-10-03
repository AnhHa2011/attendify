// lib/features/admin/presentation/pages/course_management/course_form_page.dart

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../../../../core/data/models/course_model.dart';
import '../../../../../core/data/models/lecturer_lite.dart';
import '../../../data/services/admin_service.dart';

class CourseFormPage extends StatefulWidget {
  final CourseModel? courseModel;
  const CourseFormPage({super.key, this.courseModel});

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _creditsCtrl;
  late final TextEditingController _minStudentsCtrl;
  late final TextEditingController _maxStudentsCtrl;
  late final TextEditingController _semesterCtrl;
  late final TextEditingController _joinCodeCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = false;
  bool get _isEditMode => widget.courseModel != null;

  // ====== Lecturer dropdown state ======
  List<LecturerLite> _lecturers = [];
  String? _selectedLecturerId;
  bool _lecturersLoading = true;
  String? _lecturersError;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(
      text: widget.courseModel?.courseCode ?? '',
    );
    _nameCtrl = TextEditingController(
      text: widget.courseModel?.courseName ?? '',
    );
    _creditsCtrl = TextEditingController(
      text: widget.courseModel?.credits != null
          ? widget.courseModel!.credits.toString()
          : '',
    );
    _minStudentsCtrl = TextEditingController(
      text: widget.courseModel?.minStudents != null
          ? widget.courseModel!.minStudents.toString()
          : '',
    );
    _maxStudentsCtrl = TextEditingController(
      text: widget.courseModel?.maxStudents != null
          ? widget.courseModel!.maxStudents.toString()
          : '',
    );
    _semesterCtrl = TextEditingController(
      text: widget.courseModel?.semester != null
          ? widget.courseModel!.semester.toString()
          : '',
    );
    _joinCodeCtrl = TextEditingController(
      text: widget.courseModel?.joinCode != null
          ? widget.courseModel!.joinCode.toString()
          : '',
    );
    _descriptionCtrl = TextEditingController(
      text: widget.courseModel?.description != null
          ? widget.courseModel!.description.toString()
          : '',
    );
    _startDateCtrl = TextEditingController(
      text: widget.courseModel?.startDate != null
          ? _dateFormat.format(widget.courseModel!.startDate)
          : '',
    );
    _endDateCtrl = TextEditingController(
      text: widget.courseModel?.endDate != null
          ? _dateFormat.format(widget.courseModel!.endDate)
          : '',
    );

    // Lecturer default when edit
    _selectedLecturerId = widget.courseModel?.lecturerId;

    // Load lecturers
    Future.microtask(_loadLecturers);
  }

  Future<void> _loadLecturers() async {
    try {
      final adminService = context.read<AdminService>();

      // TODO: Đổi tên & map theo service thực tế.
      // Yêu cầu: trả danh sách có id + displayName (hoặc name)
      final raw = await adminService.fetchLecturers();
      final list = raw
          .map<LecturerLite>(
            (e) => LecturerLite(
              uid: e.uid,
              displayName: e.displayName.toString(),
              email: e.email.toString(),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _lecturers = list;
        _lecturersLoading = false;
        // nếu đang edit mà _selectedLecturerId null, thử auto chọn theo trùng tên (tuỳ bạn)
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lecturersError = e.toString();
        _lecturersLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _creditsCtrl.dispose();
    _minStudentsCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _semesterCtrl.dispose();
    _joinCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  // // ====== Helpers ======
  // String _weekdayLabel(int weekday) {
  //   switch (weekday) {
  //     case 1:
  //       return 'Thứ 2';
  //     case 2:
  //       return 'Thứ 3';
  //     case 3:
  //       return 'Thứ 4';
  //     case 4:
  //       return 'Thứ 5';
  //     case 5:
  //       return 'Thứ 6';
  //     case 6:
  //       return 'Thứ 7';
  //     case 7:
  //       return 'Chủ nhật';
  //     default:
  //       return 'N/A';
  //   }
  // }

  // String _formatTime(TimeOfDay? t) {
  //   if (t == null) return '--:--';
  //   final h = t.hour.toString().padLeft(2, '0');
  //   final m = t.minute.toString().padLeft(2, '0');
  //   return '$h:$m';
  //   // Nếu muốn 12h: DateFormat('hh:mm a').format(...)
  // }

  // int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // Future<void> _pickTime({
  //   required _WeekdaySlot slot,
  //   required bool isStart,
  // }) async {
  //   final initial = isStart
  //       ? (slot.start ?? const TimeOfDay(hour: 7, minute: 0))
  //       : (slot.end ?? const TimeOfDay(hour: 9, minute: 0));

  //   final picked = await showTimePicker(
  //     context: context,
  //     initialTime: initial,
  //     helpText: isStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
  //   );
  //   if (picked == null) return;

  //   setState(() {
  //     if (isStart) {
  //       slot.start = picked;
  //     } else {
  //       slot.end = picked;
  //     }
  //   });
  // }

  // // Validate chung cho các slot (nếu bật) thì phải có start < end
  // String? _validateSlots() {
  //   for (final s in _weekdaySlots) {
  //     if (!s.enabled) continue;
  //     if (s.start == null || s.end == null) {
  //       return 'Vui lòng chọn giờ cho ${_weekdayLabel(s.weekday)}';
  //     }
  //     if (_toMinutes(s.end!) <= _toMinutes(s.start!)) {
  //       return 'Giờ kết thúc phải sau giờ bắt đầu (${_weekdayLabel(s.weekday)})';
  //     }
  //   }
  //   return null;
  // }

  // List<Map<String, dynamic>> _collectSchedulePayload() {
  //   // Trả list map day/start/end (24h) để lưu backend
  //   final out = <Map<String, dynamic>>[];
  //   for (final s in _weekdaySlots) {
  //     if (!s.enabled || s.start == null || s.end == null) continue;
  //     out.add({
  //       'weekday': s.weekday, // 1..7
  //       'start': _formatTime(s.start), // "HH:mm"
  //       'end': _formatTime(s.end),
  //     });
  //   }
  //   return out;
  // }

  // Hàm helper để hiển thị dialog xác nhận
  Future<bool?> _showPastDateConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Người dùng phải chọn một hành động
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cảnh báo'),
          content: const Text(
            'Ngày bắt đầu nằm trong quá khứ. Bạn có chắc chắn muốn lưu không?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy bỏ'),
              onPressed: () {
                Navigator.of(context).pop(false); // Trả về false
              },
            ),
            FilledButton(
              child: const Text('Vẫn lưu'),
              onPressed: () {
                Navigator.of(context).pop(true); // Trả về true
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLecturerId == null || _selectedLecturerId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn giảng viên')));
      return;
    }

    // --- START: THÊM LOGIC KIỂM TRA NGÀY TRONG QUÁ KHỨ ---

    final startDate = _dateFormat.parseStrict(_startDateCtrl.text);
    final now = DateTime.now();
    // Tạo một đối tượng DateTime cho ngày hôm nay lúc 00:00:00 để so sánh
    final today = DateTime(now.year, now.month, now.day);

    // Nếu ngày bắt đầu là một ngày trước ngày hôm nay
    if (startDate.isBefore(today)) {
      final shouldProceed = await _showPastDateConfirmationDialog();

      // Nếu người dùng chọn "Hủy bỏ" hoặc đóng dialog, dừng quá trình
      if (shouldProceed != true) {
        return;
      }
    }

    // // Validate slots (nếu cần bắt buộc có ít nhất 1 buổi thì kiểm tra ở đây)
    // final slotError = _validateSlots();
    // if (slotError != null) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(SnackBar(content: Text(slotError)));
    //   return;
    // }

    setState(() => _isLoading = true);

    final adminService = context.read<AdminService>();
    final courseCode = _codeCtrl.text.trim().toUpperCase();
    final courseName = _nameCtrl.text.trim();
    final credits = int.parse(_creditsCtrl.text);
    final minStudents = int.parse(_minStudentsCtrl.text);
    final maxStudents = int.parse(_maxStudentsCtrl.text);
    final lecturerId = _selectedLecturerId!;
    final semester = _semesterCtrl.text.trim();
    final joinCode = _joinCodeCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final endDate = _dateFormat.parseStrict(_endDateCtrl.text);

    try {
      // Khi ở chế độ chỉnh sửa, không cần kiểm tra mã môn học đã tồn tại hay chưa
      // vì mã này không thể thay đổi.
      if (!_isEditMode) {
        final isTaken = await adminService.isCourseCodeTaken(
          courseCode,
          currentcourseCode: widget.courseModel?.id,
        );
        if (isTaken) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mã môn học "$courseCode" đã tồn tại.'),
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
        await adminService.updateCourse(
          id: widget.courseModel!.id,
          lecturerId: lecturerId,
          semester: semester,
          courseName: courseName,
          courseCode: courseCode,
          joinCode: joinCode,
          credits: credits,
          description: description,
          minStudents: minStudents,
          maxStudents: maxStudents,
          startDate: startDate, // Dùng biến đã parse
          endDate: endDate,
        );
      } else {
        await adminService.createCourse(
          lecturerId: lecturerId,
          semester: semester,
          courseName: courseName,
          courseCode: courseCode,
          joinCode: joinCode,
          credits: credits,
          description: description,
          minStudents: minStudents,
          maxStudents: maxStudents,
          startDate: startDate, // Dùng biến đã parse
          totalStudents: 0,
          endDate: endDate,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'Cập nhật thành công!' : 'Thêm môn học thành công!',
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Cập nhật môn học' : 'Thêm môn học mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ====== course Code ======
              TextFormField(
                controller: _codeCtrl,
                // Thêm thuộc tính `enabled`
                enabled: !_isEditMode,
                decoration: InputDecoration(
                  labelText: 'Mã môn học',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                  // Thay đổi helperText để người dùng hiểu rõ hơn
                  helperText: _isEditMode
                      ? 'Mã môn học không thể thay đổi.'
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

              // ====== course Name ======
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

              // ====== Lecturer Dropdown ======
              Builder(
                builder: (context) {
                  if (_lecturersLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (_lecturersError != null) {
                    return Text(
                      'Lỗi tải danh sách giảng viên: $_lecturersError',
                      style: TextStyle(color: cs.error),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedLecturerId,
                    // THÊM DÒNG NÀY: Cho phép dropdown chiếm hết chiều rộng
                    isExpanded: true,
                    items: _lecturers
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.uid.toString(),
                            // SỬA ĐỔI CHILD: Bọc Text trong Row > Expanded
                            // để đảm bảo ellipsis hoạt động đúng cách.
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${l.displayName} (${l.email})',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1, // Đảm bảo chỉ có 1 dòng
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Chọn giảng viên',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    onChanged: (v) => setState(() => _selectedLecturerId = v),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng chọn giảng viên'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // ====== Credits ======
              TextFormField(
                controller: _creditsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số tín chỉ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Không được để trống';
                  }
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Số tín chỉ phải là số > 0';
                  return null;
                },
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
                  if (v == null || v.trim().isEmpty)
                    return 'Không được để trống';
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

              // ====== semester ======
              TextFormField(
                controller: _semesterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Học kỳ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'HKI 2025-2026',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  UpperCaseTextFormatter(),
                ],
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              // ====== description ======
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // =========== START: CẬP NHẬT TỪ ĐÂY ===========

              // TextFormField cho NGÀY BẮT ĐẦU
              TextFormField(
                controller: _startDateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Ngày bắt đầu',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Vui lòng chọn ngày'
                    : null,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _startDateCtrl.text.isNotEmpty
                        ? _dateFormat.parseStrict(_startDateCtrl.text)
                        : DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _startDateCtrl.text = _dateFormat.format(pickedDate);
                    // UX Improvement: Nếu ngày kết thúc đã được chọn và bây giờ nó
                    // không còn hợp lệ (trước hoặc bằng ngày bắt đầu mới), hãy xóa nó.
                    if (_endDateCtrl.text.isNotEmpty) {
                      final endDate = _dateFormat.parseStrict(
                        _endDateCtrl.text,
                      );
                      if (!endDate.isAfter(pickedDate)) {
                        _endDateCtrl.clear();
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 16), // Tăng khoảng cách cho đẹp hơn
              // TextFormField cho NGÀY KẾT THÚC
              TextFormField(
                controller: _endDateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Ngày kết thúc',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) {
                  // 1. Kiểm tra rỗng
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn ngày';
                  }
                  // 2. Nếu ngày bắt đầu chưa được chọn, không cần validate thêm
                  if (_startDateCtrl.text.isEmpty) {
                    return null;
                  }
                  // 3. So sánh hai ngày
                  try {
                    final startDate = _dateFormat.parseStrict(
                      _startDateCtrl.text,
                    );
                    final endDate = _dateFormat.parseStrict(value);
                    if (!endDate.isAfter(startDate)) {
                      return 'Ngày kết thúc phải sau ngày bắt đầu';
                    }
                  } catch (e) {
                    // Xảy ra nếu định dạng ngày bị lỗi (khó xảy ra với date picker)
                    return 'Định dạng ngày không hợp lệ';
                  }
                  return null; // Hợp lệ
                },
                onTap: () async {
                  // Gợi ý ngày bắt đầu cho date picker là ngày bắt đầu của khóa học (nếu có)
                  final initialPickerDate = _startDateCtrl.text.isNotEmpty
                      ? _dateFormat
                            .parseStrict(_startDateCtrl.text)
                            .add(const Duration(days: 1))
                      : DateTime.now();

                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initialPickerDate,
                    // Ngày đầu tiên có thể chọn là ngày sau ngày bắt đầu
                    firstDate: _startDateCtrl.text.isNotEmpty
                        ? _dateFormat
                              .parseStrict(_startDateCtrl.text)
                              .add(const Duration(days: 1))
                        : DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _endDateCtrl.text = _dateFormat.format(pickedDate);
                    // Kích hoạt lại việc validate của form sau khi chọn
                    _formKey.currentState?.validate();
                  }
                },
              ),

              // =========== END: CẬP NHẬT TỚI ĐÂY ===========
              const SizedBox(height: 28),

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

class _WeekdaySlot {
  final int weekday; // 1=Mon ... 7=Sun
  bool enabled;
  TimeOfDay? start;
  TimeOfDay? end;

  _WeekdaySlot({
    required this.weekday,
    this.enabled = false,
    this.start,
    this.end,
  });
}
