import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/class_session.dart';
import '../../services/lecturer_service.dart';
import '../../widgets/session_detail_dialog.dart';
import 'session_create_screen.dart';

class LecturerScheduleScreen extends StatefulWidget {
  const LecturerScheduleScreen({Key? key}) : super(key: key);

  @override
  State<LecturerScheduleScreen> createState() => _LecturerScheduleScreenState();
}

class _LecturerScheduleScreenState extends State<LecturerScheduleScreen>
    with TickerProviderStateMixin {
  final LecturerService _lecturerService = LecturerService();
  late TabController _tabController;

  DateTime _selectedDate = DateTime.now();
  List<ClassSession> _allSessions = [];
  List<ClassSession> _todaySessions = [];
  List<ClassSession> _thisWeekSessions = [];
  List<ClassSession> _upcomingSessions = [];

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endOfMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      );

      _lecturerService
          .getLecturerSchedule(startDate: startOfMonth, endDate: endOfMonth)
          .listen((sessions) {
            if (mounted) {
              setState(() {
                _allSessions = sessions;
                _categorizeSessionsByTime();
                isLoading = false;
              });
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _categorizeSessionsByTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekFromNow = now.add(const Duration(days: 7));

    _todaySessions = _allSessions.where((session) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      return sessionDate.isAtSameMomentAs(today);
    }).toList();

    _thisWeekSessions = _allSessions.where((session) {
      return session.startTime.isAfter(today) &&
          session.startTime.isBefore(weekFromNow);
    }).toList();

    _upcomingSessions = _allSessions.where((session) {
      return session.startTime.isAfter(weekFromNow);
    }).toList();

    // Sort sessions
    _todaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    _thisWeekSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    _upcomingSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _exportCalendar() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Đang xuất lịch...'),
            ],
          ),
        ),
      );

      // Mock export functionality
      await Future.delayed(const Duration(seconds: 2));

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xuất lịch thành công! (Mock implementation)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xuất lịch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thời khóa biểu'),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportCalendar,
            tooltip: 'Xuất lịch ICS',
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
              _loadSessions();
            },
            tooltip: 'Hôm nay',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Hôm nay',
              icon: Badge(
                label: Text('${_todaySessions.length}'),
                child: const Icon(Icons.today),
              ),
            ),
            Tab(
              text: 'Tuần này',
              icon: Badge(
                label: Text('${_thisWeekSessions.length}'),
                child: const Icon(Icons.date_range),
              ),
            ),
            Tab(
              text: 'Sắp tới',
              icon: Badge(
                label: Text('${_upcomingSessions.length}'),
                child: const Icon(Icons.schedule),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionCreate(selectedDate: _selectedDate),
            ),
          );

          if (result == true) {
            _loadSessions();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Tạo buổi học mới',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsList(
                  _todaySessions,
                  'Không có lớp học nào hôm nay',
                ),
                _buildSessionsList(
                  _thisWeekSessions,
                  'Không có lớp học nào trong tuần',
                ),
                _buildSessionsList(
                  _upcomingSessions,
                  'Không có lớp học nào sắp tới',
                ),
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
            'Không thể tải lịch học',
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
            onPressed: _loadSessions,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<ClassSession> sessions, String emptyMessage) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(emptyMessage, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút + để tạo buổi học mới',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _buildSessionCard(session);
        },
      ),
    );
  }

  Widget _buildSessionCard(ClassSession session) {
    final startTime = DateFormat('HH:mm').format(session.startTime);
    final endTime = DateFormat('HH:mm').format(session.endTime);
    final duration = session.duration;
    final date = DateFormat('dd/MM/yyyy').format(session.startTime);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => SessionDetailDialog(session: session),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getSessionStatusColor(session).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getSessionStatusIcon(session),
                      color: _getSessionStatusColor(session),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      session.statusText,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getSessionStatusColor(
                      session,
                    ).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _getSessionStatusColor(session),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date and time info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$startTime - $endTime',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${duration.inHours}h ${duration.inMinutes % 60}m',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),

              // Action buttons for ongoing sessions
              if (session.isOngoing || session.isUpcoming)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      if (session.isOngoing)
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _lecturerService.generateAttendanceQR(
                                session.id,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã mở điểm danh'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.qr_code, size: 16),
                          label: const Text('Mở điểm danh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (session.isAttendanceOpen) const SizedBox(width: 8),
                      if (session.isAttendanceOpen)
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await _lecturerService.closeAttendance(
                                session.id,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã đóng điểm danh'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Đóng điểm danh'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSessionStatusColor(ClassSession session) {
    if (session.isOngoing) return Colors.green;
    if (session.isUpcoming) return Colors.orange;
    if (session.isFinished) return Colors.grey;
    return Colors.blue;
  }

  IconData _getSessionStatusIcon(ClassSession session) {
    if (session.isOngoing) return Icons.play_circle;
    if (session.isUpcoming) return Icons.schedule;
    if (session.isFinished) return Icons.check_circle;
    return Icons.event;
  }
}
