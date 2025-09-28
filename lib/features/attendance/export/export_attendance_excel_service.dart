import 'package:attendify/app_imports.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../../../core/data/models/attendance_model.dart';
import '../../../core/data/models/enrollment_mdel.dart';

class ExportAttendanceExcelService {
  /// Trả về path đã lưu (nếu nền tảng có path). Web thì thường trả null.
  static Future<String?> export({
    required CourseModel course,
    required List<UserModel> users,
    required List<EnrollmentModel> enrollments,
    required List<AttendanceModel> attendances,
    required List<LeaveRequestModel> leaveRequests,
    required List<SessionModel> sessions,
  }) async {
    final excel = Excel.createExcel();
    // Đổi tên (hoặc xoá) sheet mặc định
    if (excel.getDefaultSheet() == 'Sheet1') {
      excel.rename('Sheet1', 'Attendance');
    }
    final sheet = excel['Attendance'];

    // ===== 2 dòng thông tin môn học
    sheet.appendRow([TextCellValue('Mã môn'), TextCellValue('Tên môn')]);
    sheet.appendRow([
      TextCellValue(course.courseCode),
      TextCellValue(course.courseName),
    ]);
    // Sau khi thêm 2 dòng môn học
    sheet.appendRow([]);
    // ===== Header
    // 5 cột cố định
    final baseHeaders = <CellValue>[
      TextCellValue('MSSV'),
      TextCellValue('Họ tên'),
      TextCellValue('Email'),
      TextCellValue('Mã môn'),
      TextCellValue('Tên môn'),
    ];

    // Cột theo buổi học (sắp theo thời gian)
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final sessionHeaders = sessions
        .map((s) => TextCellValue(dateFmt.format(s.startTime)))
        .toList();

    // 3 cột tổng cuối
    final totalHeaders = <CellValue>[
      TextCellValue('Có mặt'),
      TextCellValue('Vắng có phép'),
      TextCellValue('Vắng không phép'),
    ];

    sheet.appendRow([...baseHeaders, ...sessionHeaders, ...totalHeaders]);
    // Map uid -> User
    final userById = {for (final u in users) u.uid: u};

    // Tính vị trí cột để đặt công thức COUNTIF
    final int baseCols = baseHeaders.length; // 5
    final int firstSessionCol = baseCols + 1; // F = 6 (1-based)
    final int lastSessionCol = baseCols + sessions.length;

    String colLetter(int colIndex1Based) {
      // A1 notation converter
      int n = colIndex1Based;
      final buf = StringBuffer();
      while (n > 0) {
        n--; // make it 0-based
        buf.writeCharCode('A'.codeUnitAt(0) + (n % 26));
        n ~/= 26;
      }
      return buf.toString().split('').reversed.join();
    }

    for (int i = 0; i < enrollments.length; i++) {
      final e = enrollments[i];
      final studentId = e.studentUid;
      final user = userById[studentId];

      final row = <CellValue>[
        TextCellValue(e.studentUid),
        TextCellValue(user?.displayName ?? ''),
        TextCellValue(user?.email ?? ''),
        TextCellValue(course.courseCode),
        TextCellValue(course.courseName),
      ];

      // Đánh dấu cho từng buổi: P/E/U
      for (final session in sessions) {
        // mặc định U
        String mark = 'U';

        // có mặt?
        final att = attendances.firstWhere(
          (a) => a.studentId == studentId && a.sessionId == session.id,
          orElse: () => AttendanceModel.empty(),
        );
        if (att.status == 'present') {
          mark = 'P';
        } else {
          // xin phép được duyệt?
          final leave = leaveRequests.firstWhere(
            (l) =>
                l.studentId == studentId &&
                l.sessionId == session.id &&
                l.status == 'approved',
            orElse: () => LeaveRequestModel.empty(),
          );
          if (leave.id.isNotEmpty) {
            mark = 'E';
          }
        }

        row.add(TextCellValue(mark));
      }

      // Thêm 3 cột tổng = công thức COUNTIF trên hàng hiện tại
      // Dòng hiện tại trong Excel (1-based):
      // 2 dòng info + 1 dòng header => data start tại dòng 4
      final rowIndex = 4 + i;
      final startCol = colLetter(firstSessionCol);
      final endCol = colLetter(lastSessionCol);
      final range = '$startCol$rowIndex:$endCol$rowIndex';

      row.addAll([
        FormulaCellValue('=COUNTIF($range,"P")'),
        FormulaCellValue('=COUNTIF($range,"E")'),
        FormulaCellValue('=COUNTIF($range,"U")'),
      ]);

      sheet.appendRow(row);
    }

    // Ghi file
    final bytes = Uint8List.fromList(excel.encode()!);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'attendance_${course.courseCode}_$stamp';

    final savedPath = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    return kIsWeb ? null : savedPath;
  }
}
