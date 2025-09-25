// lib/features/admin/presentation/pages/course_management/course_import_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../data/models/course_import_model.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/course_import_service.dart';

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
      lecturerEmail = TextEditingController(text: m.lecturerEmail ?? ''),
      minStudents = TextEditingController(text: m.minStudents.toString()),
      maxStudents = TextEditingController(text: m.maxStudents.toString()),
      startDate = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(m.startDate),
      ),
      endDate = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(m.endDate),
      ),
      notes = TextEditingController(text: m.notes ?? ''),
      description = TextEditingController(text: m.description ?? ''),
      weeklySchedule = List<WeeklySlot>.from(m.weeklySchedule);

  CourseImportModel toModel() {
    DateTime parseDmy(String s) => DateFormat('dd/MM/yyyy').parseStrict(s);
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
          : lecturerEmail.text.trim(),
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
  final List<_RowEditors> _rows = [];
  bool _isLoading = false;
  String? _fileName;
  final List<String> _errors = [];

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
        setState(() => _rows.addAll(models.map((e) => _RowEditors(e))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errors.add('Lỗi khi đọc Excel: $e'));
      }
    }
  }

  Future<void> _import() async {
    if (_rows.isEmpty) {
      setState(() => _errors.add('Không có bản ghi hợp lệ để import'));
      return;
    }
    // Validate cơ bản
    final List<String> localErrors = [];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i].toModel();
      if (r.courseCode.isEmpty)
        localErrors.add('Dòng ${i + 1}: Mã môn học trống.');
      if (r.courseName.isEmpty)
        localErrors.add('Dòng ${i + 1}: Tên môn học trống.');
      if (r.credits < 1 || r.credits > 6)
        localErrors.add('Dòng ${i + 1}: Tín chỉ phải 1–6.');
      if (r.endDate.isBefore(r.startDate))
        localErrors.add('Dòng ${i + 1}: Kết thúc phải ≥ Bắt đầu.');
      if (r.maxStudents < r.minStudents)
        localErrors.add('Dòng ${i + 1}: Max SV phải ≥ Min SV.');
    }
    if (localErrors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(localErrors);
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final admin = context.read<AdminService>();
      final list = _rows.map((e) => e.toModel()).toList();
      await admin.bulkImportCoursesFromImportModels(list);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import thành công!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errors.add('Import thất bại: $e'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _rows.isEmpty || _isLoading ? null : _import,
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
                        constraints: const BoxConstraints(minWidth: 1100),
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 56,
                          columns: const [
                            DataColumn(label: Text('Mã')),
                            DataColumn(label: Text('Tên')),
                            DataColumn(label: Text('Tín chỉ')),
                            DataColumn(label: Text('GV')),
                            DataColumn(label: Text('Email GV')),
                            DataColumn(label: Text('Min SV')),
                            DataColumn(label: Text('Max SV')),
                            DataColumn(label: Text('Bắt đầu')),
                            DataColumn(label: Text('Kết thúc')),
                            DataColumn(label: Text('Lịch học')),
                            DataColumn(label: Text('Ghi chú')),
                          ],
                          rows: List.generate(_rows.length, (i) {
                            final r = _rows[i];
                            return DataRow(
                              cells: [
                                DataCell(_cellText(r.code, width: 120)),
                                DataCell(_cellText(r.name, width: 200)),
                                DataCell(_cellNumber(r.credits, width: 64)),
                                DataCell(_cellText(r.lecturerName, width: 140)),
                                DataCell(
                                  _cellText(r.lecturerEmail, width: 180),
                                ),
                                DataCell(_cellNumber(r.minStudents, width: 80)),
                                DataCell(_cellNumber(r.maxStudents, width: 80)),
                                DataCell(
                                  _cellText(r.startDate, width: 110),
                                ), // dd/MM/yyyy
                                DataCell(_cellText(r.endDate, width: 110)),
                                DataCell(_scheduleEditorButton(context, r)),
                                DataCell(_cellText(r.notes, width: 200)),
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

  Widget _cellText(TextEditingController c, {double? width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _cellNumber(TextEditingController c, {double? width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _scheduleEditorButton(BuildContext context, _RowEditors r) {
    final preview = r.weeklySchedule.isEmpty
        ? 'Chưa có'
        : r.weeklySchedule
              .map(
                (s) => 'T${s.dayOfWeek} ${s.startTime}-${s.endTime} ${s.room}',
              )
              .join(' | ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(preview, overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final updated = await showDialog<List<WeeklySlot>>(
              context: context,
              builder: (_) => _ScheduleEditorDialog(initial: r.weeklySchedule),
            );
            if (updated != null) {
              setState(() => r.weeklySchedule = updated);
            }
          },
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Sửa'),
        ),
      ],
    );
  }
}

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
