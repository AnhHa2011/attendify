import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelService {
  // ========== USER IMPORT/EXPORT ==========

  /// Import users from Excel file
  static Future<List<Map<String, dynamic>>> importUsers(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final users = <Map<String, dynamic>>[];
      final headers = <String>[];

      // Get headers from first row
      for (int col = 0; col < (sheet.maxColumns ?? 0); col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        headers.add(cell?.value?.toString() ?? '');
      }

      // Process data rows
      for (int row = 1; row < sheet.maxRows; row++) {
        final user = <String, dynamic>{};
        bool hasData = false;

        for (int col = 0; col < headers.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          final value = cell?.value?.toString() ?? '';

          if (value.isNotEmpty) hasData = true;
          user[headers[col]] = value;
        }

        if (hasData) users.add(user);
      }

      return users;
    } catch (e) {
      throw Exception('Failed to import users: ${e.toString()}');
    }
  }

  /// Export users to Excel file
  static Future<File> exportUsers(List<Map<String, dynamic>> users) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Users'];

      if (users.isEmpty) throw Exception('No users to export');

      // Add headers
      final headers = users.first.keys.toList();
      for (int col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .value = TextCellValue(
          headers[col],
        );
      }

      // Add data
      for (int row = 0; row < users.length; row++) {
        final user = users[row];
        for (int col = 0; col < headers.length; col++) {
          final value = user[headers[col]]?.toString() ?? '';
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
              )
              .value = TextCellValue(
            value,
          );
        }
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/users_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      await file.writeAsBytes(excel.save()!);

      return file;
    } catch (e) {
      throw Exception('Failed to export users: ${e.toString()}');
    }
  }

  // ========== ATTENDANCE EXPORT ==========

  /// Export attendance report to Excel
  static Future<File> exportAttendanceReport({
    required String className,
    required List<Map<String, dynamic>> attendanceData,
    String? courseName,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance Report'];

      // Title and info
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue(
        'ATTENDANCE REPORT',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = TextCellValue(
        'Class: $className',
      );
      if (courseName != null) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
            .value = TextCellValue(
          'Course: $courseName',
        );
      }
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
          .value = TextCellValue(
        'Generated: ${DateTime.now()}',
      );

      // Headers (starting from row 5)
      final headers = [
        'Student ID',
        'Full Name',
        'Email',
        'Total Sessions',
        'Attended',
        'Percentage',
      ];
      for (int col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 5))
            .value = TextCellValue(
          headers[col],
        );
      }

      // Data
      for (int row = 0; row < attendanceData.length; row++) {
        final data = attendanceData[row];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 6))
            .value = TextCellValue(
          data['studentId']?.toString() ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 6))
            .value = TextCellValue(
          data['fullName']?.toString() ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 6))
            .value = TextCellValue(
          data['email']?.toString() ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row + 6))
            .value = IntCellValue(
          data['totalSessions'] ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row + 6))
            .value = IntCellValue(
          data['attended'] ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row + 6))
            .value = TextCellValue(
          '${data['percentage']}%',
        );
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${directory.path}/attendance_${className}_$timestamp.xlsx',
      );
      await file.writeAsBytes(excel.save()!);

      return file;
    } catch (e) {
      throw Exception('Failed to export attendance: ${e.toString()}');
    }
  }

  // ========== COURSE IMPORT/EXPORT ==========

  /// Import courses from Excel file
  static Future<List<Map<String, dynamic>>> importCourses(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final courses = <Map<String, dynamic>>[];
      final expectedHeaders = [
        'courseCode',
        'courseName',
        'credits',
        'minStudents',
        'maxStudents',
        'startDate',
        'endDate',
      ];

      // Validate headers
      for (int col = 0; col < expectedHeaders.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        final header = cell?.value?.toString() ?? '';
        if (header != expectedHeaders[col]) {
          throw Exception(
            'Invalid header at column ${col + 1}. Expected: ${expectedHeaders[col]}, Got: $header',
          );
        }
      }

      // Process data rows
      for (int row = 1; row < sheet.maxRows; row++) {
        final course = <String, dynamic>{};
        bool hasData = false;

        for (int col = 0; col < expectedHeaders.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          final value = cell?.value?.toString() ?? '';

          if (value.isNotEmpty) hasData = true;

          // Type conversion for specific fields
          if (col == 2) {
            // credits
            course[expectedHeaders[col]] = int.tryParse(value) ?? 0;
          } else if (col == 3 || col == 4) {
            // minStudents, maxStudents
            course[expectedHeaders[col]] = int.tryParse(value) ?? 0;
          } else if (col == 5 || col == 6) {
            // startDate, endDate
            course[expectedHeaders[col]] = value; // Keep as string, parse later
          } else {
            course[expectedHeaders[col]] = value;
          }
        }

        if (hasData) courses.add(course);
      }

      return courses;
    } catch (e) {
      throw Exception('Failed to import courses: ${e.toString()}');
    }
  }

  // ========== CLASS IMPORT/EXPORT ==========

  /// Import classes from Excel file
  static Future<List<Map<String, dynamic>>> importClasses(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final classes = <Map<String, dynamic>>[];
      final expectedHeaders = [
        'className',
        'courseCode',
        'lecturerEmail',
        'schedule',
      ];

      // Validate headers
      for (int col = 0; col < expectedHeaders.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        final header = cell?.value?.toString() ?? '';
        if (header != expectedHeaders[col]) {
          throw Exception(
            'Invalid header at column ${col + 1}. Expected: ${expectedHeaders[col]}, Got: $header',
          );
        }
      }

      // Process data rows
      for (int row = 1; row < sheet.maxRows; row++) {
        final classData = <String, dynamic>{};
        bool hasData = false;

        for (int col = 0; col < expectedHeaders.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          final value = cell?.value?.toString() ?? '';

          if (value.isNotEmpty) hasData = true;
          classData[expectedHeaders[col]] = value;
        }

        if (hasData) classes.add(classData);
      }

      return classes;
    } catch (e) {
      throw Exception('Failed to import classes: ${e.toString()}');
    }
  }

  /// Import enrollments from Excel file
  static Future<List<Map<String, dynamic>>> importEnrollments(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final enrollments = <Map<String, dynamic>>[];
      final expectedHeaders = ['studentEmail', 'className'];

      // Validate headers
      for (int col = 0; col < expectedHeaders.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        final header = cell?.value?.toString() ?? '';
        if (header != expectedHeaders[col]) {
          throw Exception(
            'Invalid header at column ${col + 1}. Expected: ${expectedHeaders[col]}, Got: $header',
          );
        }
      }

      // Process data rows
      for (int row = 1; row < sheet.maxRows; row++) {
        final enrollment = <String, dynamic>{};
        bool hasData = false;

        for (int col = 0; col < expectedHeaders.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          final value = cell?.value?.toString() ?? '';

          if (value.isNotEmpty) hasData = true;
          enrollment[expectedHeaders[col]] = value;
        }

        if (hasData) enrollments.add(enrollment);
      }

      return enrollments;
    } catch (e) {
      throw Exception('Failed to import enrollments: ${e.toString()}');
    }
  }
}
