// lib/features/student/data/models/student_attendance_stats.dart

class StudentAttendanceStats {
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int leaveRequestCount;
  final double attendanceRate;

  const StudentAttendanceStats({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.leaveRequestCount,
    required this.attendanceRate,
  });

  factory StudentAttendanceStats.empty() {
    return const StudentAttendanceStats(
      totalSessions: 0,
      presentCount: 0,
      absentCount: 0,
      leaveRequestCount: 0,
      attendanceRate: 0.0,
    );
  }

  factory StudentAttendanceStats.calculate({
    required int totalSessions,
    required int presentCount,
    required int absentCount,
    required int leaveRequestCount,
  }) {
    final rate = totalSessions > 0 
        ? (presentCount / totalSessions) * 100 
        : 0.0;
    
    return StudentAttendanceStats(
      totalSessions: totalSessions,
      presentCount: presentCount,
      absentCount: absentCount,
      leaveRequestCount: leaveRequestCount,
      attendanceRate: rate,
    );
  }

  @override
  String toString() {
    return 'StudentAttendanceStats(total: $totalSessions, present: $presentCount, absent: $absentCount, leave: $leaveRequestCount, rate: ${attendanceRate.toStringAsFixed(1)}%)';
  }
}
