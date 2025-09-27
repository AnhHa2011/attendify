import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/class_session.dart';
import '../../models/attendance_record.dart';
import '../../services/lecturer_service.dart';
import 'attendance_export_screen.dart';

class AttendanceDetail extends StatefulWidget {
  final ClassSession session;

  const AttendanceDetail({Key? key, required this.session}) : super(key: key);

  @override
  State<AttendanceDetail> createState() => _AttendanceDetailState();
}

class _AttendanceDetailState extends State<AttendanceDetail>
    with TickerProviderStateMixin {
  final LecturerService _lecturerService = LecturerService();
  late TabController _tabController;

  List<AttendanceRecord> _attendanceRecords = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  List<Map<String, dynamic>> _presentStudents = [];
  List<Map<String, dynamic>> _absentStudents = [];

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load attendance records and enrolled students in parallel
      final results = await Future.wait([
        _lecturerService.getSessionAttendance(widget.session.id).first,
        _loadEnrolledStudents(),
      ]);

      final attendanceRecords = results[0] as List<AttendanceRecord>;
      final enrolledStudents = results[1] as List<Map<String, dynamic>>;

      // Create present students list
      final presentStudents = attendanceRecords
          .where((record) => record.isPresent)
          .map(
            (record) => {
              'id': record.studentId,
              'name': record.studentName,
              'email': record.studentEmail,
              'checkInTime': record.checkInTime,
              'location': record.location,
              'isLate': _isLate(record.checkInTime),
            },
          )
          .toList();

      // Create absent students list (enrolled but not present)
      final presentStudentIds = presentStudents.map((s) => s['id']).toSet();
      final absentStudents = enrolledStudents
          .where((student) => !presentStudentIds.contains(student['id']))
          .toList();

      if (mounted) {
        setState(() {
          _attendanceRecords = attendanceRecords;
          _enrolledStudents = enrolledStudents;
          _presentStudents = presentStudents;
          _absentStudents = absentStudents;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadEnrolledStudents() async {
    // This would typically load from enrollments collection
    // For now, return empty list or mock data
    return [];
  }

  bool _isLate(DateTime checkInTime) {
    // Consider late if checked in more than 10 minutes after session start
    return checkInTime.isAfter(
      widget.session.startTime.add(const Duration(minutes: 10)),
    );
  }

  double get attendanceRate {
    if (_enrolledStudents.isEmpty) return 0.0;
    return (_presentStudents.length / _enrolledStudents.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Điểm danh - ${widget.session.title}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            onPressed: _exportAttendance,
            icon: const Icon(Icons.download),
            tooltip: 'Xuất báo cáo',
          ),
          IconButton(
            onPressed: _loadAttendanceData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Tổng quan',
              icon: Badge(
                label: Text('${_enrolledStudents.length}'),
                child: const Icon(Icons.analytics),
              ),
            ),
            Tab(
              text: 'Có mặt',
              icon: Badge(
                label: Text('${_presentStudents.length}'),
                backgroundColor: Colors.green,
                child: const Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: 'Vắng mặt',
              icon: Badge(
                label: Text('${_absentStudents.length}'),
                backgroundColor: Colors.red,
                child: const Icon(Icons.cancel),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPresentStudentsTab(),
                _buildAbsentStudentsTab(),
              ],
            ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Không thể tải dữ liệu điểm danh',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAttendanceData,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Info Card
          _buildSessionInfoCard(),

          const SizedBox(height: 16),

          // Statistics Cards
          _buildStatisticsCards(),

          const SizedBox(height: 16),

          // Attendance Rate Chart
          _buildAttendanceChart(),

          const SizedBox(height: 16),

          // Quick Actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin buổi học',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat(
                    'EEEE, dd/MM/yyyy',
                    'vi_VN',
                  ).format(widget.session.startTime),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('HH:mm').format(widget.session.startTime)} - '
                  '${DateFormat('HH:mm').format(widget.session.endTime)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(widget.session.location),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.qr_code,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.session.isAttendanceOpen
                      ? 'Điểm danh đang mở'
                      : 'Điểm danh đã đóng',
                ),
                const SizedBox(width: 8),
                Icon(
                  widget.session.isAttendanceOpen
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                  color: widget.session.isAttendanceOpen
                      ? Colors.green
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Tổng SV',
            _enrolledStudents.length.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Có mặt',
            _presentStudents.length.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Vắng mặt',
            _absentStudents.length.toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Tỷ lệ',
            '${attendanceRate.toStringAsFixed(1)}%',
            Icons.analytics,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biểu đồ điểm danh',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Simple progress bar representation
            Row(
              children: [
                Expanded(
                  flex: _presentStudents.length,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${_presentStudents.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_absentStudents.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    flex: _absentStudents.length,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${_absentStudents.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Có mặt (${_presentStudents.length})'),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Vắng mặt (${_absentStudents.length})'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thao tác nhanh',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportAttendance,
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất Excel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to manual attendance marking
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Sửa điểm danh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresentStudentsTab() {
    if (_presentStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có sinh viên nào điểm danh'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _presentStudents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = _presentStudents[index];
        return _buildStudentCard(student, true);
      },
    );
  }

  Widget _buildAbsentStudentsTab() {
    if (_absentStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Tất cả sinh viên đều có mặt!'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _absentStudents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = _absentStudents[index];
        return _buildStudentCard(student, false);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isPresent) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          child: Icon(
            isPresent ? Icons.check : Icons.close,
            color: isPresent ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          student['name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student['email'] ?? ''),
            if (isPresent && student['checkInTime'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Điểm danh: ${DateFormat('HH:mm').format(student['checkInTime'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  if (student['isLate'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Muộn',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: isPresent
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.cancel, color: Colors.red),
      ),
    );
  }

  void _exportAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceExport(
          session: widget.session,
          presentStudents: _presentStudents,
          absentStudents: _absentStudents,
        ),
      ),
    );
  }
}
