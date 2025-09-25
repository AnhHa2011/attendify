// lib/features/admin/data/services/course_import_service.dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/course_import_model.dart';

class CourseImportService {
  /// Parse .xlsx theo template hiện tại:
  /// Sheet: 'Danh_Sach_Mon_Hoc'
  /// Headers (12 cột đúng thứ tự):
  /// STT | Mã môn học | Tên môn học | Số tín chỉ | Mô tả môn học |
  /// Giảng viên phụ trách | Email giảng viên |
  /// Số sinh viên tối thiểu | Số sinh viên tối đa |
  /// Thời gian bắt đầu | Thời gian kết thúc | Ghi chú
  ///
  /// weeklySchedule được suy ra theo thứ tự ưu tiên:
  ///  1) (Không có cột riêng) Parse từ 'Ghi chú' nếu có pattern như:
  ///     "Mon 08:00-10:00 A101 | Wed 09:00-11:00 B202"
  ///     Hoặc: "Thứ 2 08:00-10:00 A101", "T3 13:30-15:00 B105", "CN 09:00-11:00 P201"
  ///  2) Nếu không có trong 'Ghi chú' -> để rỗng, và user chỉnh ở UI trước khi import.
  static Future<List<CourseImportModel>> parseCoursesXlsx(
    Uint8List bytes,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    if (!excel.sheets.containsKey('Danh_Sach_Mon_Hoc')) {
      throw Exception("Không tìm thấy sheet 'Danh_Sach_Mon_Hoc'.");
    }
    final sheet = excel['Danh_Sach_Mon_Hoc'];
    if (sheet.maxRows <= 1) return [];

    // Lấy header & map index theo tên (không phụ thuộc vị trí cứng)
    final headers = <String>[];
    for (final cell in sheet.row(0)) {
      headers.add((cell?.value ?? '').toString().trim());
    }
    int indexOf(String name) => headers.indexOf(name);

    final idxCode = indexOf('Mã môn học');
    final idxName = indexOf('Tên môn học');
    final idxCredits = indexOf('Số tín chỉ');
    final idxDesc = indexOf('Mô tả môn học');
    final idxLecturerName = indexOf('Giảng viên phụ trách');
    final idxLecturerEmail = indexOf('Email giảng viên');
    final idxMin = indexOf('Số sinh viên tối thiểu');
    final idxMax = indexOf('Số sinh viên tối đa');
    final idxStart = indexOf('Thời gian bắt đầu');
    final idxEnd = indexOf('Thời gian kết thúc');
    final idxNotes = indexOf('Ghi chú');

    // Bảo vệ: nếu thiếu header bắt buộc sẽ báo lỗi
    final mustHave = {
      'Mã môn học': idxCode,
      'Tên môn học': idxName,
      'Số tín chỉ': idxCredits,
      'Giảng viên phụ trách': idxLecturerName,
      'Thời gian bắt đầu': idxStart,
      'Thời gian kết thúc': idxEnd,
    };
    final missing = mustHave.entries
        .where((e) => e.value < 0)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      throw Exception('Thiếu cột bắt buộc: ${missing.join(", ")}');
    }

    int? parseInt(dynamic x) => int.tryParse((x ?? '').toString().trim());

    DateTime? parseDmy(dynamic x) {
      final s = (x ?? '').toString().trim();
      if (s.isEmpty) return null;
      final parts = s.split('/');
      if (parts.length != 3) return null;
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return null;
      return DateTime(y, m, d);
    }

    // Map tên thứ -> số (ISO 1=Mon..7=Sun). Hỗ trợ cả tiếng Việt & tiếng Anh.
    int? mapDow(String raw) {
      final t = raw.trim().toLowerCase();
      const m = {
        '2': 1,
        't2': 1,
        'thứ 2': 1,
        'thu 2': 1,
        'mon': 1,
        'monday': 1,
        '3': 2,
        't3': 2,
        'thứ 3': 2,
        'tue': 2,
        'tuesday': 2,
        '4': 3,
        't4': 3,
        'thứ 4': 3,
        'wed': 3,
        'wednesday': 3,
        '5': 4,
        't5': 4,
        'thứ 5': 4,
        'thu': 4,
        'thu 5': 4,
        'thursday': 4,
        '6': 5,
        't6': 5,
        'thứ 6': 5,
        'fri': 5,
        'friday': 5,
        '7': 6,
        't7': 6,
        'thứ 7': 6,
        'sat': 6,
        'saturday': 6,
        'cn': 7,
        'chủ nhật': 7,
        'chu nhat': 7,
        'sun': 7,
        'sunday': 7,
      };
      return m[t];
    }

    WeeklySlot? buildSlot(String day, String start, String end, String room) {
      final dow = mapDow(day);
      final hhmm = RegExp(r'^\d{1,2}:\d{2}$');
      if (dow == null || !hhmm.hasMatch(start) || !hhmm.hasMatch(end))
        return null;
      return WeeklySlot(
        dayOfWeek: dow,
        startTime: start,
        endTime: end,
        room: room.trim(),
      );
    }

    // Parse dạng gộp: "Mon 08:00-10:00 A101 | Wed 09:00-11:00 B202"
    List<WeeklySlot> parseScheduleCombined(String text) {
      final slots = <WeeklySlot>[];
      // tách theo | ; hoặc xuống dòng
      final parts = text.split(RegExp(r'[|\n;]'));
      for (var seg in parts) {
        final s = seg.trim();
        if (s.isEmpty) continue;
        // bắt day + hh:mm-hh:mm + room (room là phần còn lại sau time-range)
        final m = RegExp(
          r'^\s*([^\s]+(?:\s+\d)?)\s+(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s+(.+?)\s*$',
        ).firstMatch(s);
        if (m != null) {
          final slot = buildSlot(
            m.group(1)!,
            m.group(2)!,
            m.group(3)!,
            m.group(4)!,
          );
          if (slot != null) slots.add(slot);
        }
      }
      return slots;
    }

    // Parse từ 'Ghi chú' (nếu người dùng viết lẫn trong text)
    List<WeeklySlot> parseScheduleFromNotes(String notes) {
      final slots = <WeeklySlot>[];
      if (notes.trim().isEmpty) return slots;

      // Ưu tiên tách cụm trước, sau đó quét regex trong từng cụm
      final parts = notes.split(RegExp(r'[|\n;]'));
      final pattern = RegExp(
        r'(?:(Mon|Tue|Wed|Thu|Fri|Sat|Sun|CN|Chủ nhật|Chu nhat|Thứ\s*[2-7]|T[2-7]))\s+'
        r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s+([^|;\n]+)',
      );

      for (var seg in parts) {
        for (final m in pattern.allMatches(seg)) {
          final day = m.group(1)!;
          final start = m.group(2)!;
          final end = m.group(3)!;
          final room = m.group(4)!;
          final slot = buildSlot(day, start, end, room);
          if (slot != null) slots.add(slot);
        }
      }

      // Nếu không match theo regex trên, thử parser gộp
      if (slots.isEmpty) {
        slots.addAll(parseScheduleCombined(notes));
      }
      return slots;
    }

    final rows = <CourseImportModel>[];

    for (int r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      String get(int i) => (i >= 0 && i < row.length)
          ? (row[i]?.value ?? '').toString().trim()
          : '';

      final code = get(idxCode);
      final name = get(idxName);
      final credits = parseInt(get(idxCredits)) ?? 0;
      final desc = get(idxDesc);
      final lecturerName = get(idxLecturerName);
      final lecturerEmail = get(idxLecturerEmail);
      final minSv = parseInt(get(idxMin)) ?? 1;
      final maxSv = parseInt(get(idxMax)) ?? 50;
      final startDate = parseDmy(get(idxStart)) ?? DateTime.now();
      final endDate = parseDmy(get(idxEnd)) ?? startDate;
      final notes = get(idxNotes);

      // bỏ dòng trống
      if ([
        code,
        name,
        lecturerName,
        get(idxStart),
        get(idxEnd),
      ].every((e) => (e ?? '').toString().trim().isEmpty)) {
        continue;
      }

      // weeklySchedule: chỉ parse từ 'Ghi chú' (vì template hiện tại không có cột lịch riêng)
      final slots = parseScheduleFromNotes(notes);

      rows.add(
        CourseImportModel(
          courseCode: code,
          courseName: name,
          credits: credits,
          description: desc.isEmpty ? null : desc,
          lecturerEmail: lecturerEmail.isEmpty ? null : lecturerEmail,
          lecturerName: lecturerName.isEmpty ? null : lecturerName,
          minStudents: minSv,
          maxStudents: maxSv,
          startDate: startDate,
          endDate: endDate,
          notes: notes.isEmpty ? null : notes,
          weeklySchedule: slots,
        ),
      );
    }

    return rows;
  }
}
