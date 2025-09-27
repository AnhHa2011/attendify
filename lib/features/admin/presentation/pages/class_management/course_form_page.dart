// lib/presentation/pages/admin/course_form_page.dart

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

  // ====== Weekday slots (Mon..Sun) with time range ======
  final List<_WeekdaySlot> _weekdaySlots = List.generate(
    7,
    (i) => _WeekdaySlot(weekday: i + 1), // 1=Mon ... 7=Sun
  );

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
          ? widget.courseModel!.startDate.toString()
          : '',
    );
    _endDateCtrl = TextEditingController(
      text: widget.courseModel?.endDate != null
          ? widget.courseModel!.endDate.toString()
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

  // ====== Helpers ======
  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 7:
        return 'Chủ nhật';
      default:
        return 'N/A';
    }
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
    // Nếu muốn 12h: DateFormat('hh:mm a').format(...)
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({
    required _WeekdaySlot slot,
    required bool isStart,
  }) async {
    final initial = isStart
        ? (slot.start ?? const TimeOfDay(hour: 7, minute: 0))
        : (slot.end ?? const TimeOfDay(hour: 9, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        slot.start = picked;
      } else {
        slot.end = picked;
      }
    });
  }

  // Validate chung cho các slot (nếu bật) thì phải có start < end
  String? _validateSlots() {
    for (final s in _weekdaySlots) {
      if (!s.enabled) continue;
      if (s.start == null || s.end == null) {
        return 'Vui lòng chọn giờ cho ${_weekdayLabel(s.weekday)}';
      }
      if (_toMinutes(s.end!) <= _toMinutes(s.start!)) {
        return 'Giờ kết thúc phải sau giờ bắt đầu (${_weekdayLabel(s.weekday)})';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _collectSchedulePayload() {
    // Trả list map day/start/end (24h) để lưu backend
    final out = <Map<String, dynamic>>[];
    for (final s in _weekdaySlots) {
      if (!s.enabled || s.start == null || s.end == null) continue;
      out.add({
        'weekday': s.weekday, // 1..7
        'start': _formatTime(s.start), // "HH:mm"
        'end': _formatTime(s.end),
      });
    }
    return out;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check lecturer chosen
    if (_selectedLecturerId == null || _selectedLecturerId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn giảng viên')));
      return;
    }

    // Validate slots (nếu cần bắt buộc có ít nhất 1 buổi thì kiểm tra ở đây)
    final slotError = _validateSlots();
    if (slotError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(slotError)));
      return;
    }

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
    final startDate = DateFormat('dd/MM/yyyy').parseStrict(_startDateCtrl.text);
    final endDate = DateFormat('dd/MM/yyyy').parseStrict(_endDateCtrl.text);
    try {
      // Kiểm tra trùng mã môn học
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
        return;
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
          startDate: startDate,
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
          startDate: startDate,
          endDate: endDate,
          totalStudents: 0,
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
                decoration: const InputDecoration(
                  labelText: 'Mã môn học',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'Ví dụ: IT4440. Sẽ tự động viết hoa.',
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
                    items: _lecturers
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.uid.toString(),
                            child: Text(
                              '${l.displayName}( ${l.email})',
                              overflow: TextOverflow.ellipsis,
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
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  helperText: '',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  UpperCaseTextFormatter(),
                ],
                validator: (v) =>
                    v!.trim().isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateCtrl,
                readOnly: true, // để chặn nhập tay
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
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _startDateCtrl.text = _dateFormat.format(pickedDate);
                  }
                },
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _endDateCtrl,
                readOnly: true, // để chặn nhập tay
                decoration: const InputDecoration(
                  labelText: 'Ngày kết thúc',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Vui lòng chọn ngày'
                    : null,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _endDateCtrl.text = _dateFormat.format(pickedDate);
                  }
                },
              ),
              const SizedBox(height: 8),

              ..._weekdaySlots.map((slot) {
                final label = _weekdayLabel(slot.weekday);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label),
                          value: slot.enabled,
                          onChanged: (v) => setState(() {
                            slot.enabled = v;
                            if (!v) {
                              slot.start = null;
                              slot.end = null;
                            }
                          }),
                        ),
                        if (slot.enabled)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.schedule, size: 18),
                                  onPressed: () =>
                                      _pickTime(slot: slot, isStart: true),
                                  label: Text(
                                    'Bắt đầu: ${_formatTime(slot.start)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.schedule, size: 18),
                                  onPressed: () =>
                                      _pickTime(slot: slot, isStart: false),
                                  label: Text(
                                    'Kết thúc: ${_formatTime(slot.end)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),

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
