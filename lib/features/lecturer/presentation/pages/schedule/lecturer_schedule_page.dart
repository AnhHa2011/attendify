// lib/features/lecturer/presentation/schedule/lecturer_schedule_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../../../../app/providers/auth_provider.dart';
import '../../../../../core/presentation/pages/schedule_page.dart';
import '../../../services/lecturer_service.dart';

class LecturerSchedulePage extends StatefulWidget {
  const LecturerSchedulePage({super.key});

  @override
  State<LecturerSchedulePage> createState() => _LecturerSchedulePageState();
}

class _LecturerSchedulePageState extends State<LecturerSchedulePage> {
  final _lecturerService = LecturerService();
  bool _isExporting = false;

  Future<void> _exportToICS() async {
    final auth = context.read<AuthProvider>();
    final lecturerId = auth.user?.uid;

    if (lecturerId == null) {
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
      final icsContent = await _lecturerService.exportScheduleToICS(lecturerId);

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
    final lecturerId = auth.user?.uid;

    if (lecturerId == null) {
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
        currentUid: lecturerId,
        isLecturer: true, // Lecturer view
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
