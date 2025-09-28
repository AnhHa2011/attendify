import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TemplateService {
  /// Templates definition with headers for each import type
  static const Map<String, List<String>> templates = {
    'users': ['email', 'fullName', 'role', 'studentId', 'className'],
    'courses': [
      'courseCode',
      'courseName',
      'credits',
      'minStudents',
      'maxStudents',
      'startDate',
      'endDate',
    ],
    'classes': ['className', 'courseCode', 'lecturerEmail', 'schedule'],
    'enrollments': ['studentEmail', 'className'],
  };

  /// Sample data for each template type
  static const Map<String, List<Map<String, dynamic>>> sampleData = {
    'users': [
      {
        'email': 'student1@example.com',
        'fullName': 'Nguyen Van A',
        'role': 'student',
        'studentId': 'SV001',
        'className': 'CNTT01',
      },
      {
        'email': 'lecturer1@example.com',
        'fullName': 'Tran Thi B',
        'role': 'lecturer',
        'studentId': '',
        'className': '',
      },
      {
        'email': 'admin@example.com',
        'fullName': 'Le Van C',
        'role': 'admin',
        'studentId': '',
        'className': '',
      },
    ],
    'courses': [
      {
        'courseCode': 'CS101',
        'courseName': 'Introduction to Computer Science',
        'credits': '3',
        'minStudents': '10',
        'maxStudents': '40',
        'startDate': '2024-01-15',
        'endDate': '2024-05-15',
      },
      {
        'courseCode': 'MATH201',
        'courseName': 'Discrete Mathematics',
        'credits': '4',
        'minStudents': '15',
        'maxStudents': '35',
        'startDate': '2024-01-15',
        'endDate': '2024-05-15',
      },
    ],
    'classes': [
      {
        'className': 'CS101-A1',
        'courseCode': 'CS101',
        'lecturerEmail': 'lecturer1@example.com',
        'schedule': 'Monday 08:00-10:00, Wednesday 08:00-10:00',
      },
      {
        'className': 'MATH201-B1',
        'courseCode': 'MATH201',
        'lecturerEmail': 'lecturer2@example.com',
        'schedule': 'Tuesday 10:00-12:00, Thursday 10:00-12:00',
      },
    ],
    'enrollments': [
      {'studentEmail': 'student1@example.com', 'className': 'CS101-A1'},
      {'studentEmail': 'student2@example.com', 'className': 'CS101-A1'},
      {'studentEmail': 'student1@example.com', 'className': 'MATH201-B1'},
    ],
  };

  /// Generate and download template Excel file
  static Future<File> generateTemplate(String templateType) async {
    try {
      if (!templates.containsKey(templateType)) {
        throw Exception('Unknown template type: $templateType');
      }

      final excel = Excel.createExcel();
      final sheet = excel[templateType.toUpperCase()];

      // Get headers and sample data
      final headers = templates[templateType]!;
      final samples = sampleData[templateType] ?? [];

      // Add instructions sheet
      final instructionSheet = excel['INSTRUCTIONS'];
      _addInstructions(instructionSheet, templateType, headers);

      // Add template headers
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[col]);
        // Make headers bold (if supported)
        cell.cellStyle = CellStyle(bold: true);
      }

      // Add sample data
      for (int row = 0; row < samples.length; row++) {
        final sample = samples[row];
        for (int col = 0; col < headers.length; col++) {
          final header = headers[col];
          final value = sample[header]?.toString() ?? '';
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
              )
              .value = TextCellValue(
            value,
          );
        }
      }

      // Save template file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${templateType}_template_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.save()!);

      return file;
    } catch (e) {
      throw Exception('Failed to generate template: ${e.toString()}');
    }
  }

  /// Add instructions to the instruction sheet
  static void _addInstructions(
    Sheet instructionSheet,
    String templateType,
    List<String> headers,
  ) {
    var row = 0;

    // Title
    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      'ATTENDIFY - ${templateType.toUpperCase()} IMPORT TEMPLATE',
    );

    row++; // Empty row

    // General instructions
    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      'INSTRUCTIONS:',
    );

    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      '1. Do not modify the column headers',
    );

    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      '2. Fill in your data starting from row 2',
    );

    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      '3. Remove sample data before importing',
    );

    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      '4. Save the file as .xlsx format',
    );

    row++; // Empty row

    // Column descriptions
    instructionSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue(
      'COLUMN DESCRIPTIONS:',
    );

    final descriptions = _getColumnDescriptions(templateType);
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i];
      final description = descriptions[header] ?? 'No description available';
      instructionSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
          .value = TextCellValue(
        '$header: $description',
      );
    }

    row++; // Empty row

    // Template-specific notes
    final notes = _getTemplateNotes(templateType);
    if (notes.isNotEmpty) {
      instructionSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
          .value = TextCellValue(
        'IMPORTANT NOTES:',
      );

      for (final note in notes) {
        instructionSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
            .value = TextCellValue(
          '• $note',
        );
      }
    }
  }

  /// Get column descriptions for each template type
  static Map<String, String> _getColumnDescriptions(String templateType) {
    switch (templateType) {
      case 'users':
        return {
          'email': 'User email address (must be unique)',
          'fullName': 'Full name of the user',
          'role': 'User role: admin, lecturer, or student',
          'studentId': 'Student ID (required for students only)',
          'className': 'Class name (for students only)',
        };
      case 'courses':
        return {
          'courseCode': 'Unique course code (e.g., CS101)',
          'courseName': 'Full course name',
          'credits': 'Number of credits (integer)',
          'minStudents': 'Minimum number of students required',
          'maxStudents': 'Maximum number of students allowed',
          'startDate': 'Course start date (YYYY-MM-DD)',
          'endDate': 'Course end date (YYYY-MM-DD)',
        };
      case 'classes':
        return {
          'className': 'Unique class name (e.g., CS101-A1)',
          'courseCode': 'Course code this class belongs to',
          'lecturerEmail': 'Email of the assigned lecturer',
          'schedule': 'Class schedule (e.g., Monday 08:00-10:00)',
        };
      case 'enrollments':
        return {
          'studentEmail': 'Email of the student to enroll',
          'className': 'Name of the class to enroll in',
        };
      default:
        return {};
    }
  }

  /// Get template-specific notes
  static List<String> _getTemplateNotes(String templateType) {
    switch (templateType) {
      case 'users':
        return [
          'Email addresses must be unique across all users',
          'Role must be exactly: admin, lecturer, or student',
          'Student ID is required only for users with role "student"',
          'Class name is optional for students',
        ];
      case 'courses':
        return [
          'Course codes must be unique',
          'Credits, minStudents, and maxStudents must be positive integers',
          'Date format must be YYYY-MM-DD',
          'Start date must be before end date',
        ];
      case 'classes':
        return [
          'Class names must be unique',
          'Course code must exist in the system',
          'Lecturer email must exist and have lecturer role',
          'Schedule format is flexible but should be clear',
        ];
      case 'enrollments':
        return [
          'Student email must exist and have student role',
          'Class name must exist in the system',
          'Students cannot be enrolled in the same class twice',
        ];
      default:
        return [];
    }
  }

  /// Share template file
  static Future<void> shareTemplate(File templateFile) async {
    try {
      await Share.shareXFiles([
        XFile(templateFile.path),
      ], text: 'Attendify Import Template');
    } catch (e) {
      throw Exception('Failed to share template: ${e.toString()}');
    }
  }

  /// Get list of available templates
  static List<String> getAvailableTemplates() {
    return templates.keys.toList();
  }

  /// Validate template structure
  static bool validateTemplate(String templateType, List<String> fileHeaders) {
    if (!templates.containsKey(templateType)) return false;

    final expectedHeaders = templates[templateType]!;
    if (fileHeaders.length != expectedHeaders.length) return false;

    for (int i = 0; i < expectedHeaders.length; i++) {
      if (fileHeaders[i] != expectedHeaders[i]) return false;
    }

    return true;
  }
}
