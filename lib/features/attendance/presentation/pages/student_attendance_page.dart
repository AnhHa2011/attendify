import 'package:flutter/material.dart';
import 'package:attendify/features/attendance/data/datasources/attendance_remote_ds.dart';
import 'package:attendify/features/attendance/domain/attendance_stats.dart';
import '../../domain/attendance_stats.dart';

class StudentAttendancePage extends StatefulWidget {
  final String classId;
  final String className;
  const StudentAttendancePage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final _ds = AttendanceRemoteDS();
  bool _loading = true;
  String? _error;
  // phần tử: { sessionId, sessionName, startTime(DateTime?), attendance(AttendanceModel) }
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ds.historyForStudent(
        classId: widget.classId,
        studentId: _ds.currentUid, // dùng uid hiện tại từ DS
      );
      setState(() => _history = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Chuyên cần - ${widget.className}';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Lỗi: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    // Tính tỷ lệ (bỏ excused khỏi mẫu số)
    final statuses = _history
        .map((e) => (e['attendance']).status as String)
        .toList();
    final stats = computeStats(statuses);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _RateCard(stats: stats),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có dữ liệu buổi phù hợp để hiển thị.'),
                ),
              ),
            ..._history.map(_HistoryTile.new),
          ],
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final percent = (stats.rate * 100).toStringAsFixed(0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tỉ lệ chuyên cần: $percent%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: stats.rate, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text(
              'Có mặt: ${stats.present}   Trễ: ${stats.late}   Vắng: ${stats.absent}   Có phép: ${stats.excused}',
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.it);
  final Map<String, dynamic> it;

  @override
  Widget build(BuildContext context) {
    final att = it['attendance'];
    final status = att.status as String? ?? 'absent';
    final start = it['startTime'] as DateTime?;
    final isFuture = start != null ? start.isAfter(DateTime.now()) : false;

    final color = switch (status) {
      'present' => Colors.green,
      'late' => Colors.orange,
      'excused' => Colors.blueGrey,
      _ => Colors.red,
    };

    final lines = <String>[];
    if (start != null) lines.add('Thời gian: ${_fmt(start)}');
    if ((att.note ?? '').toString().isNotEmpty)
      lines.add('Ghi chú: ${att.note}');
    if ((att.source ?? '').toString().isNotEmpty)
      lines.add('Nguồn: ${att.source}');
    if (isFuture) lines.add('(*) Buổi tương lai (đã xin nghỉ)');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          it['sessionName']?.toString() ??
              it['sessionId']?.toString() ??
              'Buổi học',
        ),
        subtitle: Text(lines.join(' • ')),
        trailing: Chip(
          label: Text(_displayStatus(status)),
          backgroundColor: color.withOpacity(0.18),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  String _displayStatus(String s) {
    switch (s) {
      case 'present':
        return 'Có mặt';
      case 'late':
        return 'Trễ';
      case 'excused':
        return 'Có phép';
      case 'absent':
      default:
        return 'Vắng';
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
