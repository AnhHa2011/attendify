import 'dart:typed_data';
import 'package:attendify/core/data/models/course_model.dart';
import 'package:attendify/core/utils/template_downloader.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/data/models/session_model.dart';
import '../../../../../../core/data/services/session_service.dart';

// ========= Expected headers =========
// title, date(DD/MM/YYYY), startTime(HH:mm), endTime(HH:mm), location, type(lecture|practice|exam|review), description(optional)
const _sessionHeaders = <String>[
  'title',
  'date',
  'starttime',
  'endtime',
  'location',
  'type',
  'description',
];

enum _RowStatus { pending, valid, error, created }

class _SessionRowState {
  final int rowIndex;
  String title;
  String date; // dd/MM/yyyy
  String startTime; // HH:mm
  String endTime; // HH:mm
  String location;
  String type; // lecture|practice|exam|review
  String? description;

  String? error;
  _RowStatus status;

  _SessionRowState({
    required this.rowIndex,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
    required this.description,
    this.status = _RowStatus.pending,
  });
}

class CourseSessionsBulkImportPage extends StatefulWidget {
  final CourseModel course;
  const CourseSessionsBulkImportPage({super.key, required this.course});

  @override
  State<CourseSessionsBulkImportPage> createState() =>
      _CourseSessionsBulkImportPageState();
}

class _CourseSessionsBulkImportPageState
    extends State<CourseSessionsBulkImportPage> {
  List<_SessionRowState> _rows = [];
  String? _fileName;
  String? _message;
  bool _submitting = false;

  // ---- Excel helpers ----
  static String _cellStr(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    final v = row[col]?.value;
    return v == null ? '' : v.toString();
  }

  // ---- Pick + parse ----
  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _fileName = null;
      _message = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null)
      return;

    try {
      final rows = await _parseSessionsXlsx(res.files.single.bytes!);
      setState(() {
        _rows = rows;
        _fileName = res.files.single.name;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi đọc file: $e');
    }
  }

  Future<List<_SessionRowState>> _parseSessionsXlsx(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File không có sheet nào.');
    }

    // Ưu tiên sheet tên "sessions" / "session"
    Sheet? tb = excel.tables.values.first;
    for (final key in excel.tables.keys) {
      final lk = key.toLowerCase().trim();
      if (lk == 'sessions' || lk == 'session') {
        tb = excel.tables[key];
        break;
      }
    }
    if (tb == null || tb.rows.isEmpty) throw Exception('Sheet rỗng.');

    final header = tb.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    if (header.isEmpty) throw Exception('Không tìm thấy header.');
    final headerLower = header.map((e) => e.toLowerCase()).toList();

    for (final h in _sessionHeaders) {
      if (!headerLower.contains(h)) {
        // description là optional -> chỉ warn, không throw
        if (h == 'description') continue;
        throw Exception('Thiếu cột bắt buộc: $h');
      }
    }

    int idxOf(String key) => headerLower.indexOf(key);

    final out = <_SessionRowState>[];
    final seen = <String>{}; // title|date|startTime trùng trong file

    for (var i = 1; i < tb.rows.length; i++) {
      final row = tb.rows[i];
      final valuesEmpty = row.every(
        (c) => (c?.value?.toString().trim() ?? '').isEmpty,
      );
      if (valuesEmpty) continue;

      final title = _cellStr(row, idxOf('title')).trim();
      final date = _cellStr(row, idxOf('date')).trim();
      final startTime = _cellStr(row, idxOf('starttime')).trim();
      final endTime = _cellStr(row, idxOf('endtime')).trim();
      final location = _cellStr(row, idxOf('location')).trim();
      final type = _cellStr(row, idxOf('type')).trim();
      final description = idxOf('description') >= 0
          ? _cellStr(row, idxOf('description')).trim()
          : null;

      if (title.isEmpty &&
          date.isEmpty &&
          startTime.isEmpty &&
          endTime.isEmpty) {
        continue; // bỏ dòng rỗng
      }

      final dupKey = '${title.toLowerCase()}|$date|$startTime';
      if (seen.contains(dupKey)) {
        throw Exception(
          'Dòng ${i + 1}: trùng (title + date + startTime) trong file.',
        );
      }
      seen.add(dupKey);

      out.add(
        _SessionRowState(
          rowIndex: i,
          title: title,
          date: date,
          startTime: startTime,
          endTime: endTime,
          location: location,
          type: type,
          description: (description?.isEmpty ?? true) ? null : description,
        ),
      );
    }

    return out;
  }

  // ---- Validate ----
  String? _validateRow(_SessionRowState r) {
    if (r.title.trim().isEmpty) return 'Thiếu tiêu đề buổi học';
    if (r.date.trim().isEmpty) return 'Thiếu ngày học (dd/MM/yyyy)';
    if (r.startTime.trim().isEmpty) return 'Thiếu giờ bắt đầu (HH:mm)';
    if (r.endTime.trim().isEmpty) return 'Thiếu giờ kết thúc (HH:mm)';
    if (r.location.trim().isEmpty) return 'Thiếu địa điểm';

    final t = r.type.toLowerCase();
    const allowed = ['lecture', 'practice', 'exam', 'review'];
    if (!allowed.contains(t)) {
      return 'Type phải là: lecture | practice | exam | review';
    }

    DateTime? parsedDate;
    try {
      final parts = r.date.split('/');
      if (parts.length != 3) throw Exception();
      final d = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final y = int.parse(parts[2]);
      parsedDate = DateTime(y, m, d);
    } catch (_) {
      return 'Sai định dạng ngày (dd/MM/yyyy)';
    }

    DateTime? st;
    DateTime? et;
    try {
      final s = r.startTime.split(':');
      final e = r.endTime.split(':');
      if (s.length != 2 || e.length != 2) throw Exception();
      st = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        int.parse(s[0]),
        int.parse(s[1]),
      );
      et = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        int.parse(e[0]),
        int.parse(e[1]),
      );
    } catch (_) {
      return 'Sai định dạng giờ (HH:mm)';
    }

    if (!et!.isAfter(st!)) return 'Giờ kết thúc phải > giờ bắt đầu';

    return null;
  }

  bool _allValid() =>
      _rows.isNotEmpty && _rows.every((r) => _validateRow(r) == null);

  SessionType _parseType(String v) {
    switch (v.toLowerCase()) {
      case 'practice':
        return SessionType.practice;
      case 'exam':
        return SessionType.exam;
      case 'review':
        return SessionType.review;
      default:
        return SessionType.lecture;
    }
  }

  // Parse date+time từ một dòng
  ({DateTime start, DateTime end}) _parseRowDateTimes(_SessionRowState r) {
    final parts = r.date.split('/');
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    final s = r.startTime.split(':'), e = r.endTime.split(':');
    final start = DateTime(y, m, d, int.parse(s[0]), int.parse(s[1]));
    final end = DateTime(y, m, d, int.parse(e[0]), int.parse(e[1]));
    return (start: start, end: end);
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    // overlap nếu aStart < bEnd && bStart < aEnd
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  // Lấy min/max thời gian của tất cả dòng hợp lệ (để query 1 phát)
  ({DateTime minStart, DateTime maxEnd}) _minMaxRangeOfRows() {
    DateTime? minS, maxE;
    for (final r in _rows) {
      try {
        final dt = _parseRowDateTimes(r);
        minS = (minS == null || dt.start.isBefore(minS!)) ? dt.start : minS;
        maxE = (maxE == null || dt.end.isAfter(maxE!)) ? dt.end : maxE;
      } catch (_) {
        /* bỏ qua dòng lỗi format, sẽ bị validate chặn sau */
      }
    }
    // fallback để tránh null
    final now = DateTime.now();
    return (minStart: minS ?? now, maxEnd: maxE ?? now);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Đánh dấu lỗi trùng lịch cho các dòng (với DB và với nhau)
  Future<int> _markLecturerConflicts(SessionService sessionService) async {
    final lecturerId = widget.course.lecturerId;
    if (lecturerId.isEmpty) {
      // Không có lecturerId => bỏ qua kiểm tra (hoặc bạn có thể yêu cầu course luôn có lecturerId)
      return 0;
    }

    // Chỉ xét các dòng "hợp lệ về format"
    final candidates =
        <({int idx, _SessionRowState row, DateTime start, DateTime end})>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final err = _validateRow(r);
      if (err == null) {
        final dt = _parseRowDateTimes(r);
        candidates.add((idx: i, row: r, start: dt.start, end: dt.end));
      }
    }
    if (candidates.isEmpty) return 0;

    final range = _minMaxRangeOfRows();

    // 1) Lấy sessions của GV trong khoảng [minStart, maxEnd]
    //    → CẦN có hàm trên SessionService, ví dụ: fetchLecturerSessionsInRange
    final existing = await sessionService.fetchLecturerSessionsInRange(
      lecturerId: lecturerId,
      start: range.minStart,
      end: range.maxEnd,
    );
    // existing: List<SessionModel>
    // 2) Check trùng với DB
    int conflictCount = 0;
    for (final c in candidates) {
      if (c.row.error != null && c.row.status == _RowStatus.error) continue;

      SessionModel? hit;
      for (final ex in existing) {
        if (_isSameDay(c.start, ex.startTime) &&
            _overlaps(c.start, c.end, ex.startTime, ex.endTime)) {
          hit = ex;
          break;
        }
      }

      if (hit != null) {
        c.row.error =
            'GGiảng viên đã có lịch dạy lúc: ${hit.title} '
            '(${_fmtTime(hit.startTime)}–${_fmtTime(hit.endTime)} '
            '${_fmtDate(hit.startTime)}). Vui lòng chọn khoảng thời gian khác!';
        c.row.status = _RowStatus.error;
        conflictCount++;
      } else {
        c.row.error = null;
        c.row.status = _RowStatus.valid;
      }
    }
    // 3) Check trùng giữa các dòng trong file (cùng ngày)
    final accepted = <({int idx, DateTime start, DateTime end})>[];
    for (final c in candidates) {
      if (c.row.status == _RowStatus.error) continue;

      final selfClash = accepted.any(
        (a) =>
            _isSameDay(c.start, a.start) &&
            _overlaps(c.start, c.end, a.start, a.end),
      );

      if (selfClash) {
        c.row.error =
            'Trùng lịch với một buổi khác trong file import (cùng ngày)';
        c.row.status = _RowStatus.error;
        conflictCount++;
      } else {
        accepted.add((idx: c.idx, start: c.start, end: c.end));
      }
    }

    return conflictCount;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---- Submit ----
  Future<void> _submit() async {
    if (_rows.isEmpty) return;

    // validate again
    bool hasError = false;
    for (final r in _rows) {
      r.error = _validateRow(r);
      r.status = r.error == null ? _RowStatus.valid : _RowStatus.error;
      if (r.error != null) hasError = true;
    }
    setState(() {});
    if (hasError) {
      setState(() => _message = 'Có lỗi trong dữ liệu. Vui lòng kiểm tra.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    final sessionService = context.read<SessionService>();

    // ===== NEW: kiểm tra trùng lịch giảng viên =====
    try {
      final conflicts = await _markLecturerConflicts(sessionService);
      if (conflicts > 0) {
        setState(() {
          _submitting = false;
          _message =
              'Lỗi: Phát hiện $conflicts dòng trùng lịch dạy của giảng viên. '
              'Vui lòng điều chỉnh thời gian rồi nhập lại.';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _message = 'Lỗi khi kiểm tra trùng lịch giảng viên: $e';
      });
      return;
    }
    // ==============================================

    // Thống nhất khóa course (docId hay code). Đổi duy nhất ở đây:
    final String courseIdOrCode =
        widget.course.id; // hoặc widget.course.courseCode nếu bạn dùng code

    // Lấy giảng viên từ CourseModel
    final String? lecturerId = widget.course.lecturerId.isNotEmpty
        ? widget.course.lecturerId
        : null;
    final String? lecturerName =
        (widget.course.lecturerName?.isNotEmpty == true)
        ? widget.course.lecturerName
        : null;

    try {
      int created = 0;
      for (final r in _rows) {
        // parse time
        final parts = r.date.split('/');
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        final s = r.startTime.split(':');
        final e = r.endTime.split(':');
        final start = DateTime(y, m, d, int.parse(s[0]), int.parse(s[1]));
        final end = DateTime(y, m, d, int.parse(e[0]), int.parse(e[1]));

        await sessionService.createSession(
          courseCode: courseIdOrCode, // hoặc courseId
          courseName: widget.course.courseName,
          lecturerId: lecturerId,
          lecturerName: lecturerName,
          title: r.title,
          description: r.description,
          startTime: start,
          endTime: end,
          location: r.location,
          type: _parseType(r.type),
          // Nếu service có tham số classCode, bật dòng dưới:
          // classCode: courseIdOrCode,
        );

        r.status = _RowStatus.created;
        created++;
        setState(() {}); // update từng dòng
      }

      setState(() {
        _message = 'Thành công! Đã tạo $created buổi học.';
        _submitting = _submitting;
        _rows = [];
        _fileName = null;
      });
    } catch (e) {
      setState(() => _message = 'Lỗi: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Nhập danh sách buổi học — ${widget.course.courseName}'),
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _header(theme, cs, isWide),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: _rows.isEmpty
                    ? _empty(cs)
                    : _List(
                        rows: _rows,
                        isWide: isWide,
                        onChanged: () => setState(() {}),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, ColorScheme cs, bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 24 : 16),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tải Excel để tạo buổi học cho ${widget.course.courseName}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yêu cầu cột: title, date(dd/MM/yyyy), startTime(HH:mm), endTime(HH:mm), location, type [lecture|practice|exam|review], description(optional).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Btn(
                icon: Icons.download_outlined,
                label: 'Tải template',
                onPressed: () => TemplateDownloader.download('session'),
                variant: _BtnVariant.outlined,
              ),
              _Btn(
                icon: Icons.upload_file_outlined,
                label: 'Chọn file Excel',
                onPressed: _pickFile,
                variant: _BtnVariant.filled,
              ),
              _Btn(
                icon: _submitting
                    ? Icons.hourglass_empty
                    : Icons.cloud_upload_outlined,
                label: _submitting ? 'Đang xử lý...' : 'Thực hiện nhập',
                onPressed: _allValid() && !_submitting ? _submit : null,
                variant: _BtnVariant.primary,
              ),
            ],
          ),
          if (_fileName != null || _message != null) ...[
            const SizedBox(height: 16),
            _Status(fileName: _fileName, message: _message, cs: cs),
          ],
        ],
      ),
    );
  }

  Widget _empty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'Chọn file Excel để xem trước các buổi học',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tải template để biết định dạng yêu cầu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== UI bits reused (không còn lecturer picker) ======

class _List extends StatelessWidget {
  final List<_SessionRowState> rows;
  final bool isWide;
  final VoidCallback onChanged;
  const _List({
    required this.rows,
    required this.isWide,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Xem trước dữ liệu (${rows.length} buổi học)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _RowCard(row: rows[i], isWide: isWide, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  final _SessionRowState row;
  final bool isWide;
  final VoidCallback onChanged;
  const _RowCard({
    required this.row,
    required this.isWide,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasError = row.error != null;

    Color badgeColor() {
      switch (row.status) {
        case _RowStatus.valid:
          return Colors.green;
        case _RowStatus.error:
          return cs.error;
        case _RowStatus.created:
          return cs.tertiary;
        default:
          return cs.outline;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? cs.error.withOpacity(0.3)
              : cs.outline.withOpacity(0.2),
          width: hasError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: hasError
                  ? cs.error.withOpacity(0.05)
                  : cs.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasError ? cs.error : cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasError ? Icons.error_outline : Icons.event,
                    color: hasError ? cs.onError : cs.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      if (row.error != null)
                        Text(
                          row.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor().withOpacity(0.3)),
                  ),
                  child: Text(
                    row.status == _RowStatus.created
                        ? 'Đã tạo'
                        : row.status == _RowStatus.valid
                        ? 'Hợp lệ'
                        : row.status == _RowStatus.error
                        ? 'Lỗi'
                        : 'Chờ',
                    style: TextStyle(
                      color: badgeColor(),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // body
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) {
                final cross = c.maxWidth > 1000
                    ? 4
                    : c.maxWidth > 760
                    ? 3
                    : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 4,
                  childAspectRatio: cross == 4 ? 5 : 6,
                  children: [
                    _TField(
                      label: 'Tiêu đề',
                      value: row.title,
                      icon: Icons.title,
                      onChanged: (v) {
                        row.title = v.trim();
                        _reval(context);
                      },
                    ),
                    _TField(
                      label: 'Ngày (dd/MM/yyyy)',
                      value: row.date,
                      icon: Icons.calendar_today,
                      onChanged: (v) {
                        row.date = v.trim();
                        _reval(context);
                      },
                    ),
                    _TField(
                      label: 'Bắt đầu (HH:mm)',
                      value: row.startTime,
                      icon: Icons.schedule,
                      onChanged: (v) {
                        row.startTime = v.trim();
                        _reval(context);
                      },
                    ),
                    _TField(
                      label: 'Kết thúc (HH:mm)',
                      value: row.endTime,
                      icon: Icons.schedule_outlined,
                      onChanged: (v) {
                        row.endTime = v.trim();
                        _reval(context);
                      },
                    ),
                    _TField(
                      label: 'Địa điểm',
                      value: row.location,
                      icon: Icons.location_on_outlined,
                      onChanged: (v) {
                        row.location = v.trim();
                        _reval(context);
                      },
                    ),
                    // Trường type (dropdown)
                    DropdownButtonFormField<String>(
                      value:
                          row.type.isNotEmpty &&
                              [
                                'lecture',
                                'practice',
                                'exam',
                                'review',
                              ].contains(row.type.toLowerCase())
                          ? row.type.toLowerCase()
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cs.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cs.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Chọn loại buổi học'),
                      items: const [
                        DropdownMenuItem(
                          value: 'lecture',
                          child: Text('Lý thuyết'),
                        ),
                        DropdownMenuItem(
                          value: 'practice',
                          child: Text('Thực hành'),
                        ),
                        DropdownMenuItem(
                          value: 'exam',
                          child: Text('Kiểm tra'),
                        ),
                        DropdownMenuItem(
                          value: 'review',
                          child: Text('Ôn tập'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          row.type = v;
                          final parent = context
                              .findAncestorStateOfType<
                                _CourseSessionsBulkImportPageState
                              >();
                          if (parent != null) {
                            row.error = parent._validateRow(row);
                            row.status = row.error == null
                                ? _RowStatus.valid
                                : _RowStatus.error;
                            onChanged();
                          }
                        }
                      },
                    ),

                    _TField(
                      label: 'Mô tả (optional)',
                      value: row.description ?? '',
                      icon: Icons.notes_outlined,
                      onChanged: (v) {
                        row.description = v.trim().isEmpty ? null : v.trim();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _reval(BuildContext context) {
    final parent = context
        .findAncestorStateOfType<_CourseSessionsBulkImportPageState>();
    if (parent != null) {
      row.error = parent._validateRow(row);
      row.status = row.error == null ? _RowStatus.valid : _RowStatus.error;
      onChanged();
    }
  }
}

class _TField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const _TField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

enum _BtnVariant { outlined, filled, primary }

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _BtnVariant variant;
  const _Btn({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.variant,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (variant) {
      case _BtnVariant.outlined:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      case _BtnVariant.filled:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      case _BtnVariant.primary:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
    }
  }
}

class _Status extends StatelessWidget {
  final String? fileName;
  final String? message;
  final ColorScheme cs;
  const _Status({
    required this.fileName,
    required this.message,
    required this.cs,
  });
  @override
  Widget build(BuildContext context) {
    final bool isError =
        (message?.startsWith('Lỗi') ?? false) ||
        (message?.contains('Có lỗi') ?? false) ||
        (message?.toLowerCase().contains('không thành công') ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null)
            Row(
              children: [
                Icon(Icons.description, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File: $fileName',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          if (message != null) ...[
            if (fileName != null) const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  (message!.startsWith('Lỗi') || message!.contains('Có lỗi'))
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 16,
                  color:
                      (message!.startsWith('Lỗi') ||
                          message!.contains('Có lỗi'))
                      ? cs.error
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      color:
                          (message!.startsWith('Lỗi') ||
                              message!.contains('Có lỗi'))
                          ? cs.error
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
