// lib/features/student/presentation/schedule/student_schedule_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../data/services/student_service.dart';
import '../../../../core/presentation/pages/schedule_page.dart';

class StudentSchedulePage extends StatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
  final _studentService = StudentService();
  bool _isExporting = false;

  Future<void> _exportToICS() async {
    final auth = context.read<AuthProvider>();
    final studentId = auth.user?.uid;

    if (studentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xác thực người dùng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isExporting = true);

    try {
      final icsContent = await _studentService.exportScheduleToICS(studentId);

      // Create temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/lich_hoc_sinh_vien.ics');
      await file.writeAsString(icsContent);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Lịch học sinh viên - Attendify',
        text: 'Lịch học cá nhân từ ứng dụng Attendify',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xuất lịch học thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất lịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final studentId = auth.user?.uid;

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Thời khóa biểu'),
        ),
        body: const Center(child: Text('Không thể xác thực người dùng.')),
      );
    }

    return Scaffold(
      body: SchedulePage(
        currentUid: studentId,
        isLecturer: false, // Student view
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _exportToICS,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.file_download),
        label: Text(_isExporting ? 'Đang xuất...' : 'Xuất ICS'),
        backgroundColor: _isExporting ? Colors.grey : null,
      ),
    );
  }
}
