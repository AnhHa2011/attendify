// lib/features/admin/presentation/pages/course_management/course_import_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../data/models/course_import_model.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/course_import_service.dart';

/// Định dạng ngày dd/MM/yyyy
final _dmy = DateFormat('dd/MM/yyyy');

/// Item đơn giản cho dropdown giảng viên
class _LecturerItem {
  final String id;
  final String name;
  final String email;
  const _LecturerItem({
    required this.id,
    required this.name,
    required this.email,
  });
}

class _RowEditors {
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController credits;
  final TextEditingController lecturerName;
  final TextEditingController lecturerEmail;
  final TextEditingController minStudents;
  final TextEditingController maxStudents;
  final TextEditingController startDate;
  final TextEditingController endDate;
  final TextEditingController notes;
  final TextEditingController description;
  List<WeeklySlot> weeklySchedule;

  _RowEditors(CourseImportModel m)
    : code = TextEditingController(text: m.courseCode),
      name = TextEditingController(text: m.courseName),
      credits = TextEditingController(text: m.credits.toString()),
      lecturerName = TextEditingController(text: m.lecturerName ?? ''),
      lecturerEmail = TextEditingController(
        text: (m.lecturerEmail ?? '').trim().toLowerCase(),
      ),
      minStudents = TextEditingController(text: m.minStudents.toString()),
      maxStudents = TextEditingController(text: m.maxStudents.toString()),
      startDate = TextEditingController(text: _dmy.format(m.startDate)),
      endDate = TextEditingController(text: _dmy.format(m.endDate)),
      notes = TextEditingController(text: m.notes ?? ''),
      description = TextEditingController(text: m.description ?? ''),
      weeklySchedule = List<WeeklySlot>.from(m.weeklySchedule);

  CourseImportModel toModel() {
    DateTime parseDmy(String s) => _dmy.parseStrict(s);
    int parseInt(String s, {int fallback = 0}) =>
        int.tryParse(s.trim().isEmpty ? '$fallback' : s) ?? fallback;

    return CourseImportModel(
      courseCode: code.text.trim(),
      courseName: name.text.trim(),
      credits: parseInt(credits.text, fallback: 0),
      minStudents: parseInt(minStudents.text, fallback: 1),
      maxStudents: parseInt(maxStudents.text, fallback: 50),
      startDate: parseDmy(startDate.text.trim()),
      endDate: parseDmy(endDate.text.trim()),
      description: description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      lecturerName: lecturerName.text.trim().isEmpty
          ? null
          : lecturerName.text.trim(),
      lecturerEmail: lecturerEmail.text.trim().isEmpty
          ? null
          : lecturerEmail.text.trim().toLowerCase(),
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      weeklySchedule: weeklySchedule,
    );
  }
}

class CourseImportPage extends StatefulWidget {
  const CourseImportPage({super.key});

  @override
  State<CourseImportPage> createState() => _CourseImportPageState();
}

class _CourseImportPageState extends State<CourseImportPage> {
  // ================== STATE CHÍNH ==================
  final List<_RowEditors> _rows = [];
  final List<String> _errors = [];
  bool _isLoading = false;
  String? _fileName;

  // lecturers dropdown
  List<_LecturerItem> _lecturers = [];
  bool _lecturerLoading = true;

  // validate theo ô
  final Map<int, Map<String, String?>> _cellErrors =
      {}; // rowIndex -> field -> error
  final _reCode = RegExp(r'^[A-Za-z0-9_]{1,20}$'); // mã: chữ-số-gạch dưới, ≤20
  final _reEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // check tồn tại code
  Set<String> _existingCodes =
      {}; // courseCode đã có trong hệ thống (normalized)
  bool _loadingCodes = true;

  String _norm(String s) => s.trim().toLowerCase();

  DateTime? _parseDmy(String s) {
    try {
      return _dmy.parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  bool get _hasAnyError => _cellErrors.values.any((m) => m.isNotEmpty);

  // đếm số lần một mã xuất hiện trong bảng đang edit
  int _dupCountInFile(String codeNorm) {
    int c = 0;
    for (final r in _rows) {
      if (_norm(r.code.text) == codeNorm && codeNorm.isNotEmpty) c++;
    }
    return c;
  }

  @override
  void initState() {
    super.initState();
    _loadLecturers();
    _loadExistingCodes();
  }

  Future<void> _loadLecturers() async {
    try {
      final list = await context
          .read<AdminService>()
          .getAllLecturersStream()
          .first;

      final seen = <String>{};
      _lecturers = [];

      for (final e in list) {
        final id = e.uid;
        final name = (e.displayName ?? '').trim();
        final email = (e.email ?? '').trim().toLowerCase();
        if (email.isEmpty) continue;
        if (!seen.add(email)) continue; // khử trùng theo email
        _lecturers.add(_LecturerItem(id: id, name: name, email: email));
      }

      _lecturers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } finally {
      if (mounted) setState(() => _lecturerLoading = false);
    }
  }

  Future<void> _loadExistingCodes() async {
    try {
      final courses = await context
          .read<AdminService>()
          .getAllCoursesStream()
          .first;
      // _existingCodes = courses
      //     .map((c) => _norm(c.courseCode ?? ''))
      //     .where((s) => s.isNotEmpty)
      //     .toSet();
    } catch (_) {
      _existingCodes = {};
    } finally {
      if (mounted) setState(() => _loadingCodes = false);
    }
  }

  // ================== VALIDATE ==================
  bool _validateRow(int i) {
    final r = _rows[i];
    final errs = <String, String?>{};

    // code
    final rawCode = r.code.text.trim();
    final codeNorm = _norm(rawCode);
    if (rawCode.isEmpty) {
      errs['code'] = 'Bắt buộc';
    } else if (!_reCode.hasMatch(rawCode)) {
      errs['code'] = 'Chỉ chữ-số-gạch dưới, ≤ 20';
    } else {
      // trùng trong file?
      if (_dupCountInFile(codeNorm) > 1) {
        errs['code'] = 'Mã bị trùng trong file';
      }
      // đã tồn tại trên hệ thống?
      else if (_existingCodes.contains(codeNorm)) {
        errs['code'] = 'Mã đã tồn tại trong hệ thống';
      }
    }

    // name
    final name = r.name.text.trim();
    if (name.isEmpty)
      errs['name'] = 'Bắt buộc';
    else if (name.length > 100)
      errs['name'] = '≤ 100 ký tự';

    // credits
    final credits = int.tryParse(r.credits.text.trim());
    if (credits == null)
      errs['credits'] = 'Phải là số';
    else if (credits < 1 || credits > 6)
      errs['credits'] = '1–6';

    // email (nếu nhập)
    final email = r.lecturerEmail.text.trim();
    if (email.isNotEmpty && !_reEmail.hasMatch(email)) {
      errs['email'] = 'Email không hợp lệ';
    }

    // min/max
    final minSv = int.tryParse(r.minStudents.text.trim());
    final maxSv = int.tryParse(r.maxStudents.text.trim());
    if (minSv == null || minSv <= 0) errs['min'] = 'Số nguyên dương';
    if (maxSv == null || maxSv <= 0) errs['max'] = 'Số nguyên dương';
    if (minSv != null && maxSv != null && maxSv < minSv) {
      errs['max'] = 'Phải ≥ Min';
    }

    // dates
    final start = _parseDmy(r.startDate.text.trim());
    final end = _parseDmy(r.endDate.text.trim());
    if (start == null) errs['start'] = 'Định dạng dd/MM/yyyy';
    if (end == null) errs['end'] = 'Định dạng dd/MM/yyyy';
    if (start != null && end != null && end.isBefore(start)) {
      errs['end'] = 'Kết thúc ≥ Bắt đầu';
    }

    _cellErrors[i] = errs;
    return errs.isEmpty;
  }

  bool _validateAll() {
    bool ok = true;
    for (var i = 0; i < _rows.length; i++) {
      if (!_validateRow(i)) ok = false;
    }
    setState(() {}); // refresh error UI
    return ok;
  }

  // ================== FILE PICK & IMPORT ==================
  Future<void> _pickXlsx() async {
    setState(() {
      _errors.clear();
      _rows.clear();
      _fileName = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null) {
      setState(() => _errors.add('Không có file nào được chọn'));
      return;
    }

    final bytes = res.files.single.bytes!;
    final name = res.files.single.name;
    setState(() => _fileName = name);

    try {
      final models = await CourseImportService.parseCoursesXlsx(bytes);
      if (mounted) {
        setState(() {
          _rows.addAll(models.map((e) => _RowEditors(e)));
          for (var i = 0; i < _rows.length; i++) {
            _validateRow(i); // pre-validate
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errors.add('Lỗi khi đọc Excel: $e'));
    }
  }

  Future<void> _import() async {
    // Khoá import nếu còn lỗi
    if (!_validateAll()) {
      setState(() {
        _errors
          ..clear()
          ..add(
            'Có ô chưa hợp lệ (trùng mã, sai định dạng…). Vui lòng sửa các ô viền đỏ trước khi import.',
          );
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final admin = context.read<AdminService>();
      final list = _rows.map((e) => e.toModel()).toList();
      // await admin.bulkImportCoursesFromImportModels(list);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import thành công!')));
      }
    } catch (e) {
      if (mounted) setState(() => _errors.add('Import thất bại: $e'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    const rowMin = 56.0; // tránh lỗi BoxConstraints
    const rowMax = 64.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Môn Học (.xlsx) - Chỉnh sửa trước khi lưu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickXlsx,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Chọn file .xlsx'),
                ),
                const SizedBox(width: 12),
                if (_fileName != null)
                  Text(
                    _fileName!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      _rows.isEmpty ||
                          _isLoading ||
                          _hasAnyError ||
                          _loadingCodes
                      ? null
                      : _import,
                  icon: const Icon(Icons.check),
                  label: const Text('Xác nhận import'),
                ),
              ],
            ),
            if (_isLoading) const LinearProgressIndicator(),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors
                      .map(
                        (e) => Text(
                          '• $e',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('Chưa có dữ liệu để chỉnh sửa.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1200),
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: rowMin,
                          dataRowMaxHeight: rowMax,
                          columns: const [
                            DataColumn(label: Text('Mã')),
                            DataColumn(label: Text('Tên')),
                            DataColumn(label: Text('Tín chỉ')),
                            DataColumn(label: Text('Giảng viên (email)')),
                            DataColumn(label: Text('Min SV')),
                            DataColumn(label: Text('Max SV')),
                            DataColumn(label: Text('Bắt đầu')),
                            DataColumn(label: Text('Kết thúc')),
                            DataColumn(label: Text('Lịch học')),
                            DataColumn(label: Text('Ghi chú')),
                          ],
                          rows: List.generate(_rows.length, (i) {
                            final r = _rows[i];
                            final hasErr =
                                (_cellErrors[i]?.isNotEmpty ?? false);
                            return DataRow(
                              color: hasErr
                                  ? MaterialStatePropertyAll(
                                      Theme.of(context)
                                          .colorScheme
                                          .errorContainer
                                          .withOpacity(.15),
                                    )
                                  : null,
                              cells: [
                                DataCell(
                                  _cellText(
                                    r.code,
                                    rowIndex: i,
                                    fieldKey: 'code',
                                    width: 120,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _cellText(
                                    r.name,
                                    rowIndex: i,
                                    fieldKey: 'name',
                                    width: 200,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _cellNumber(
                                    r.credits,
                                    rowIndex: i,
                                    fieldKey: 'credits',
                                    width: 64,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _lecturerDropdownCell(
                                    r,
                                    rowIndex: i,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _cellNumber(
                                    r.minStudents,
                                    rowIndex: i,
                                    fieldKey: 'min',
                                    width: 80,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _cellNumber(
                                    r.maxStudents,
                                    rowIndex: i,
                                    fieldKey: 'max',
                                    width: 80,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _datePickerCell(
                                    r.startDate,
                                    rowIndex: i,
                                    fieldKey: 'start',
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _datePickerCell(
                                    r.endDate,
                                    rowIndex: i,
                                    fieldKey: 'end',
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _scheduleEditorButton(
                                    context,
                                    r,
                                    minHeight: rowMin,
                                  ),
                                ),
                                DataCell(
                                  _cellText(
                                    r.notes,
                                    rowIndex: i,
                                    fieldKey: 'notes',
                                    width: 200,
                                    minHeight: rowMin,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Cells helpers =====
  Widget _cellText(
    TextEditingController c, {
    required int rowIndex,
    required String fieldKey,
    double? width,
    double? minHeight,
  }) {
    final err = _cellErrors[rowIndex]?[fieldKey];
    return SizedBox(
      width: width,
      height: minHeight,
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() => _validateRow(rowIndex)),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
          errorText: err,
        ),
      ),
    );
  }

  Widget _cellNumber(
    TextEditingController c, {
    required int rowIndex,
    required String fieldKey,
    double? width,
    double? minHeight,
  }) {
    final err = _cellErrors[rowIndex]?[fieldKey];
    return SizedBox(
      width: width,
      height: minHeight,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() => _validateRow(rowIndex)),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
          errorText: err,
        ),
      ),
    );
  }

  /// Dropdown giảng viên: hiển thị "Tên (email)", lưu email + tự điền name
  Widget _lecturerDropdownCell(
    _RowEditors r, {
    required int rowIndex,
    double? minHeight,
  }) {
    final err = _cellErrors[rowIndex]?['email'];

    // giá trị hiện tại chuẩn hoá
    final currentRaw = r.lecturerEmail.text.trim().toLowerCase();
    final hasMatch = _lecturers.any((x) => x.email == currentRaw);
    final effectiveValue = hasMatch ? currentRaw : null;

    final items = _lecturers
        .map(
          (e) => DropdownMenuItem<String>(
            value: e.email,
            child: Text(
              '${e.name} (${e.email})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    return SizedBox(
      height: minHeight,
      width: 300,
      child: _lecturerLoading
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : DropdownButtonFormField<String>(
              value: effectiveValue,
              items: items,
              onChanged: (val) {
                setState(() {
                  final v = (val ?? '').trim().toLowerCase();
                  r.lecturerEmail.text = v;
                  final found = _lecturers.firstWhere(
                    (x) => x.email == v,
                    orElse: () =>
                        const _LecturerItem(id: '', name: '', email: ''),
                  );
                  r.lecturerName.text = found.name;
                  _validateRow(rowIndex);
                });
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                hintText: 'Chọn giảng viên',
                errorText: err,
              ),
            ),
    );
  }

  /// Nút chọn ngày -> ghi về controller theo dd/MM/yyyy + hiển thị lỗi dưới nút
  Widget _datePickerCell(
    TextEditingController ctrl, {
    required int rowIndex,
    required String fieldKey,
    double? minHeight,
  }) {
    final err = _cellErrors[rowIndex]?[fieldKey];
    return SizedBox(
      height: minHeight,
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              ctrl.text.isEmpty ? 'Chọn ngày' : ctrl.text,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () async {
              final init = _parseDmy(ctrl.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: init,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'Chọn ngày',
                confirmText: 'OK',
                cancelText: 'Hủy',
              );
              if (picked != null) {
                setState(() {
                  ctrl.text = _dmy.format(picked);
                  _validateRow(rowIndex);
                });
              }
            },
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                err,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scheduleEditorButton(
    BuildContext context,
    _RowEditors r, {
    double? minHeight,
  }) {
    final preview = r.weeklySchedule.isEmpty
        ? 'Chưa có'
        : r.weeklySchedule
              .map(
                (s) => 'T${s.dayOfWeek} ${s.startTime}-${s.endTime} ${s.room}',
              )
              .join(' | ');

    return SizedBox(
      height: minHeight,
      width: 340,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(preview, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final updated = await showDialog<List<WeeklySlot>>(
                context: context,
                builder: (_) =>
                    _ScheduleEditorDialog(initial: r.weeklySchedule),
              );
              if (updated != null) setState(() => r.weeklySchedule = updated);
            },
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Sửa'),
          ),
        ],
      ),
    );
  }
}

// ===== Schedule editor dialog =====
class _ScheduleEditorDialog extends StatefulWidget {
  final List<WeeklySlot> initial;
  const _ScheduleEditorDialog({required this.initial});

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  late List<_SlotRow> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initial
        .map(
          (e) => _SlotRow(
            dayOfWeek: e.dayOfWeek,
            start: TextEditingController(text: e.startTime),
            end: TextEditingController(text: e.endTime),
            room: TextEditingController(text: e.room),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa lịch học'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Thứ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Bắt đầu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Kết thúc',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Phòng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _slots.length,
                itemBuilder: (_, i) => _slotRow(_slots[i]),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _slots.add(
                      _SlotRow(
                        dayOfWeek: 1,
                        start: TextEditingController(text: '08:00'),
                        end: TextEditingController(text: '10:00'),
                        room: TextEditingController(text: ''),
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm dòng'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final hhmm = RegExp(r'^\d{1,2}:\d{2}$');
            final result = <WeeklySlot>[];
            for (final s in _slots) {
              if (!hhmm.hasMatch(s.start.text) || !hhmm.hasMatch(s.end.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sai định dạng giờ HH:mm')),
                );
                return;
              }
              result.add(
                WeeklySlot(
                  dayOfWeek: s.dayOfWeek,
                  startTime: s.start.text,
                  endTime: s.end.text,
                  room: s.room.text,
                ),
              );
            }
            Navigator.pop(context, result);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  Widget _slotRow(_SlotRow s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<int>(
              value: s.dayOfWeek,
              items: List.generate(7, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('T$d')))
                  .toList(),
              onChanged: (v) => setState(() => s.dayOfWeek = v ?? 1),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: s.start,
              decoration: const InputDecoration(
                hintText: 'HH:mm',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: s.end,
              decoration: const InputDecoration(
                hintText: 'HH:mm',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextField(
              controller: s.room,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _slots.remove(s)),
          ),
        ],
      ),
    );
  }
}

class _SlotRow {
  int dayOfWeek;
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController room;
  _SlotRow({
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.room,
  });
}
