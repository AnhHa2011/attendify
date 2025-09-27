import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/class_session.dart';

class AttendanceExport extends StatefulWidget {
  final ClassSession session;
  final List<Map<String, dynamic>> presentStudents;
  final List<Map<String, dynamic>> absentStudents;

  const AttendanceExport({
    Key? key,
    required this.session,
    required this.presentStudents,
    required this.absentStudents,
  }) : super(key: key);

  @override
  State<AttendanceExport> createState() => _AttendanceExportState();
}

class _AttendanceExportState extends State<AttendanceExport> {
  bool _isExporting = false;
  bool _includeDetails = true;
  bool _includeStatistics = true;
  bool _includeAbsentStudents = true;
  String _selectedFormat = 'xlsx';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Xuất báo cáo điểm danh'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin buổi học',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Tiêu đề: ${widget.session.title}'),
                    Text(
                      'Ngày: ${DateFormat('dd/MM/yyyy').format(widget.session.startTime)}',
                    ),
                    Text(
                      'Thời gian: ${DateFormat('HH:mm').format(widget.session.startTime)} - ${DateFormat('HH:mm').format(widget.session.endTime)}',
                    ),
                    Text('Địa điểm: ${widget.session.location}'),
                    Text(
                      'Tổng sinh viên: ${widget.presentStudents.length + widget.absentStudents.length}',
                    ),
                    Text('Có mặt: ${widget.presentStudents.length}'),
                    Text('Vắng mặt: ${widget.absentStudents.length}'),
                    Text(
                      'Tỷ lệ điểm danh: ${_getAttendanceRate().toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Export Options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tùy chọn xuất file',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Format selection
                    Text(
                      'Định dạng file:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Excel (.xlsx)'),
                            value: 'xlsx',
                            groupValue: _selectedFormat,
                            onChanged: (value) {
                              setState(() {
                                _selectedFormat = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('CSV (.csv)'),
                            value: 'csv',
                            groupValue: _selectedFormat,
                            onChanged: (value) {
                              setState(() {
                                _selectedFormat = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Content options
                    Text(
                      'Nội dung bao gồm:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      title: const Text('Chi tiết thời gian điểm danh'),
                      subtitle: const Text(
                        'Bao gồm giờ check-in và trạng thái muộn',
                      ),
                      value: _includeDetails,
                      onChanged: (value) {
                        setState(() {
                          _includeDetails = value ?? true;
                        });
                      },
                      dense: true,
                    ),

                    CheckboxListTile(
                      title: const Text('Thống kê tổng quan'),
                      subtitle: const Text(
                        'Tỷ lệ điểm danh, số lượng sinh viên',
                      ),
                      value: _includeStatistics,
                      onChanged: (value) {
                        setState(() {
                          _includeStatistics = value ?? true;
                        });
                      },
                      dense: true,
                    ),

                    CheckboxListTile(
                      title: const Text('Danh sách sinh viên vắng mặt'),
                      subtitle: const Text(
                        'Bao gồm thông tin sinh viên không điểm danh',
                      ),
                      value: _includeAbsentStudents,
                      onChanged: (value) {
                        setState(() {
                          _includeAbsentStudents = value ?? true;
                        });
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Export Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _previewReport,
                    icon: const Icon(Icons.preview),
                    label: const Text('Xem trước'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportReport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download),
                    label: Text(_isExporting ? 'Đang xuất...' : 'Xuất báo cáo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info card
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.3),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'File báo cáo sẽ được lưu vào thư mục Documents và có thể chia sẻ qua ứng dụng khác.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getAttendanceRate() {
    final total = widget.presentStudents.length + widget.absentStudents.length;
    if (total == 0) return 0.0;
    return (widget.presentStudents.length / total) * 100;
  }

  void _previewReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xem trước báo cáo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Báo cáo điểm danh - ${widget.session.title}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.session.startTime)}',
              ),
              Text('Địa điểm: ${widget.session.location}'),
              const SizedBox(height: 12),

              if (_includeStatistics) ...[
                const Text(
                  'THỐNG KÊ:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Tổng số sinh viên: ${widget.presentStudents.length + widget.absentStudents.length}',
                ),
                Text('Có mặt: ${widget.presentStudents.length}'),
                Text('Vắng mặt: ${widget.absentStudents.length}'),
                Text('Tỷ lệ: ${_getAttendanceRate().toStringAsFixed(1)}%'),
                const SizedBox(height: 12),
              ],

              const Text(
                'DANH SÁCH CÓ MẶT:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...widget.presentStudents
                  .take(3)
                  .map(
                    (student) => Text(
                      '- ${student['name']} (${_includeDetails && student['checkInTime'] != null ? DateFormat('HH:mm').format(student['checkInTime']) : 'Có mặt'})',
                    ),
                  ),
              if (widget.presentStudents.length > 3)
                Text(
                  '... và ${widget.presentStudents.length - 3} sinh viên khác',
                ),

              if (_includeAbsentStudents &&
                  widget.absentStudents.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'DANH SÁCH VẮNG MẶT:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...widget.absentStudents
                    .take(3)
                    .map((student) => Text('- ${student['name']}')),
                if (widget.absentStudents.length > 3)
                  Text(
                    '... và ${widget.absentStudents.length - 3} sinh viên khác',
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      String filePath = await _generateFile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Xuất báo cáo thành công!\nFile: ${filePath.split('/').last}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Xem',
              onPressed: () {
                _showFileLocation(filePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất báo cáo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<String> _generateFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'BaoCaoDiemDanh_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.${_selectedFormat}';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    final content = _generateFileContent();
    await file.writeAsString(content);

    return filePath;
  }

  String _generateFileContent() {
    final buffer = StringBuffer();

    if (_selectedFormat == 'csv') {
      return _generateCSVContent();
    } else {
      return _generateTextContent();
    }
  }

  String _generateTextContent() {
    final buffer = StringBuffer();

    buffer.writeln('BÁOCÁO ĐIỂM DANH');
    buffer.writeln('================');
    buffer.writeln('Buổi học: ${widget.session.title}');
    buffer.writeln(
      'Ngày: ${DateFormat('dd/MM/yyyy').format(widget.session.startTime)}',
    );
    buffer.writeln(
      'Thời gian: ${DateFormat('HH:mm').format(widget.session.startTime)} - ${DateFormat('HH:mm').format(widget.session.endTime)}',
    );
    buffer.writeln('Địa điểm: ${widget.session.location}');
    buffer.writeln('');

    if (_includeStatistics) {
      buffer.writeln('THỐNG KÊ:');
      buffer.writeln('----------');
      buffer.writeln(
        'Tổng số sinh viên: ${widget.presentStudents.length + widget.absentStudents.length}',
      );
      buffer.writeln('Có mặt: ${widget.presentStudents.length}');
      buffer.writeln('Vắng mặt: ${widget.absentStudents.length}');
      buffer.writeln(
        'Tỷ lệ điểm danh: ${_getAttendanceRate().toStringAsFixed(1)}%',
      );
      buffer.writeln('');
    }

    buffer.writeln('DANH SÁCH SINH VIÊN CÓ MẶT:');
    buffer.writeln('----------------------------');
    for (int i = 0; i < widget.presentStudents.length; i++) {
      final student = widget.presentStudents[i];
      if (_includeDetails && student['checkInTime'] != null) {
        final status = student['isLate'] == true ? ' (Muộn)' : '';
        buffer.writeln(
          '${i + 1}. ${student['name']} - ${DateFormat('HH:mm').format(student['checkInTime'])}$status',
        );
      } else {
        buffer.writeln('${i + 1}. ${student['name']}');
      }
    }

    if (_includeAbsentStudents && widget.absentStudents.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('DANH SÁCH SINH VIÊN VẮNG MẶT:');
      buffer.writeln('------------------------------');
      for (int i = 0; i < widget.absentStudents.length; i++) {
        final student = widget.absentStudents[i];
        buffer.writeln('${i + 1}. ${student['name']}');
      }
    }

    return buffer.toString();
  }

  String _generateCSVContent() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('BÁOCÁO ĐIỂM DANH');
    buffer.writeln('Buổi học,${widget.session.title}');
    buffer.writeln(
      'Ngày,${DateFormat('dd/MM/yyyy').format(widget.session.startTime)}',
    );
    buffer.writeln(
      'Thời gian,${DateFormat('HH:mm').format(widget.session.startTime)} - ${DateFormat('HH:mm').format(widget.session.endTime)}',
    );
    buffer.writeln('Địa điểm,${widget.session.location}');
    buffer.writeln('');

    if (_includeStatistics) {
      buffer.writeln('THỐNG KÊ');
      buffer.writeln(
        'Tổng số sinh viên,${widget.presentStudents.length + widget.absentStudents.length}',
      );
      buffer.writeln('Có mặt,${widget.presentStudents.length}');
      buffer.writeln('Vắng mặt,${widget.absentStudents.length}');
      buffer.writeln(
        'Tỷ lệ điểm danh,${_getAttendanceRate().toStringAsFixed(1)}%',
      );
      buffer.writeln('');
    }

    // Present students
    buffer.writeln('DANH SÁCH SINH VIÊN CÓ MẶT');
    if (_includeDetails) {
      buffer.writeln('STT,Họ tên,Email,Thời gian check-in,Trạng thái');
    } else {
      buffer.writeln('STT,Họ tên,Email');
    }

    for (int i = 0; i < widget.presentStudents.length; i++) {
      final student = widget.presentStudents[i];
      if (_includeDetails) {
        final checkInTime = student['checkInTime'] != null
            ? DateFormat('HH:mm dd/MM/yyyy').format(student['checkInTime'])
            : '';
        final status = student['isLate'] == true ? 'Muộn' : 'Đúng giờ';
        buffer.writeln(
          '${i + 1},"${student['name']}","${student['email']}","$checkInTime","$status"',
        );
      } else {
        buffer.writeln('${i + 1},"${student['name']}","${student['email']}"');
      }
    }

    if (_includeAbsentStudents && widget.absentStudents.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('DANH SÁCH SINH VIÊN VẮNG MẶT');
      buffer.writeln('STT,Họ tên,Email');

      for (int i = 0; i < widget.absentStudents.length; i++) {
        final student = widget.absentStudents[i];
        buffer.writeln('${i + 1},"${student['name']}","${student['email']}"');
      }
    }

    return buffer.toString();
  }

  void _showFileLocation(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File đã được lưu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đường dẫn file:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bạn có thể tìm file này trong ứng dụng quản lý file của thiết bị.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
