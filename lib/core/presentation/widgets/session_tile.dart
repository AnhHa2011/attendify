// lib/features/schedule/presentation/widgets/session_tile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 👇 thêm dòng này
import '../../utils/ics_saver.dart';

DateTime _asDate(dynamic ts) {
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  return DateTime.now();
}

class SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const SessionTile({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final startTime = _asDate(session['startTime']).toLocal();
    final endTime = _asDate(session['endTime']).toLocal();
    final f = DateFormat('HH:mm');
    final subject = (session['title'] ?? 'Buổi học').toString();
    final room = (session['location'] ?? '').toString();

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.schedule)),
      title: Text(
        '$subject • ${f.format(startTime)}–${f.format(endTime)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${f.format(startTime)}–${f.format(endTime)}${room.isNotEmpty ? ' • $room' : ''}',
      ),
      // Web hiện nút tải .ics; mobile/desktop có thể cũng dùng được (giữ kIsWeb nếu bạn chỉ muốn hiện trên web)
      trailing: IconButton(
        tooltip: 'Thêm vào lịch (.ics)',
        icon: const Icon(Icons.event_available),
        onPressed: () => _downloadIcs(session),
      ),
    );
  }

  void _downloadIcs(Map<String, dynamic> s) {
    final start = _asDate(s['startTime']);
    final end = _asDate(s['endTime']);
    final uid = (s['id'] ?? '${start.millisecondsSinceEpoch}@attendify')
        .toString();

    String fmt(DateTime dt) =>
        '${dt.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
    final summary = (s['courseName'] ?? s['className'] ?? 'Buổi học')
        .toString();
    final location = (s['room'] ?? '').toString();

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Attendify//Schedule//VN',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${fmt(DateTime.now())}',
      'DTSTART:${fmt(start)}',
      'DTEND:${fmt(end)}',
      if (location.isNotEmpty) 'LOCATION:$location',
      'SUMMARY:$summary',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    // gọi helper (web: Blob download; mobile/desktop: lưu vào temp và mở)
    IcsSaver.save('$uid.ics', ics);
  }
}
