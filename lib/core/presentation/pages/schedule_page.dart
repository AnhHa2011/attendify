// lib/features/schedule/presentation/pages/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/services/schedule_service.dart';
import '../widgets/session_tile.dart';

enum ScheduleView { day, week, month }

class SchedulePage extends StatefulWidget {
  final String currentUid; // uid của giảng viên / sinh viên
  final bool isLecturer; // true = giảng viên, false = sinh viên

  const SchedulePage({
    super.key,
    required this.currentUid,
    required this.isLecturer,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  ScheduleView _view = ScheduleView.week;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final schedule = context.read<ScheduleService>();

    if (widget.currentUid.isEmpty) {
      return const Scaffold(
        appBar: _AppBarTitle(),
        body: Center(child: Text('Không xác định được người dùng.')),
      );
    }

    final range = _rangeFor(_view, _anchor);
    final stream = widget.isLecturer
        ? schedule.lecturerSessions(
            lecturerId: widget.currentUid,
            from: range.start,
            to: range.end,
          )
        : schedule.studentSessions(
            studentId: widget.currentUid,
            from: range.start,
            to: range.end,
          );

    return Scaffold(
      appBar: const _AppBarTitle(),
      body: Column(
        children: [
          _HeaderBar(
            view: _view,
            range: range,
            onPrev: () => setState(() => _anchor = _shift(_view, _anchor, -1)),
            onNext: () => setState(() => _anchor = _shift(_view, _anchor, 1)),
            onToday: () => setState(() => _anchor = DateTime.now()),
            onChangeView: (v) => setState(() => _view = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Không tải được thời khoá biểu.\n${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final sessions = snap.data ?? const [];
                if (sessions.isEmpty) {
                  return const Center(
                    child: Text('Không có buổi học trong khoảng đã chọn.'),
                  );
                }

                // Nhóm theo ngày
                final groups = _groupByDay(sessions);
                final dayKeys = groups.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: dayKeys.length,
                  itemBuilder: (ctx, i) {
                    final day = dayKeys[i];
                    final list = groups[day]!;
                    final dt = DateTime.parse(day);
                    final header = DateFormat(
                      'EEE, dd/MM/yyyy',
                      'vi',
                    ).format(dt);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            header,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        ...list.map((s) => SessionTile(session: s)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Helpers

  static DateTimeRange _rangeFor(ScheduleView v, DateTime anchor) {
    final d0 = DateTime(anchor.year, anchor.month, anchor.day);
    switch (v) {
      case ScheduleView.day:
        return DateTimeRange(start: d0, end: d0.add(const Duration(days: 1)));
      case ScheduleView.week:
        final weekStart = d0.subtract(Duration(days: d0.weekday - 1)); // Thứ 2
        final weekEnd = weekStart.add(const Duration(days: 7));
        return DateTimeRange(start: weekStart, end: weekEnd);
      case ScheduleView.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        return DateTimeRange(start: first, end: next);
    }
  }

  static DateTime _shift(ScheduleView v, DateTime anchor, int delta) {
    switch (v) {
      case ScheduleView.day:
        return anchor.add(Duration(days: delta));
      case ScheduleView.week:
        return anchor.add(Duration(days: 7 * delta));
      case ScheduleView.month:
        return DateTime(anchor.year, anchor.month + delta, anchor.day);
    }
  }

  static Map<String, List<Map<String, dynamic>>> _groupByDay(
    List<Map<String, dynamic>> sessions,
  ) {
    String dayKey(DateTime dt) =>
        DateTime(dt.year, dt.month, dt.day).toIso8601String();

    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in sessions) {
      final start = s['startTime'] as DateTime? ?? DateTime.now();
      final key = dayKey(start);
      (map[key] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final sa = (a['startTime'] as DateTime?) ?? DateTime.now();
        final sb = (b['startTime'] as DateTime?) ?? DateTime.now();
        return sa.compareTo(sb);
      });
    }
    return map;
  }
}

class _AppBarTitle extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarTitle();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Thời khoá biểu'));
}

/// Header gọn cho mobile: prev / label / next / hôm nay (icon) / dropdown (Ngày–Tuần–Tháng)
class _HeaderBar extends StatelessWidget {
  final ScheduleView view;
  final DateTimeRange range;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<ScheduleView> onChangeView;

  const _HeaderBar({
    required this.view,
    required this.range,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onChangeView,
  });

  String _label() {
    final fDMY = DateFormat('dd/MM/yyyy');
    final fMY = DateFormat('MM/yyyy');
    switch (view) {
      case ScheduleView.day:
        return fDMY.format(range.start);
      case ScheduleView.week:
        return '${fDMY.format(range.start)} – '
            '${fDMY.format(range.end.subtract(const Duration(days: 1)))}';
      case ScheduleView.month:
        return fMY.format(range.start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Trước',
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            // Tiêu đề co giãn để tránh tràn
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_label(), style: theme.textTheme.titleMedium),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sau',
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
            // Hôm nay: dùng icon cho gọn
            IconButton(
              tooltip: 'Hôm nay',
              icon: const Icon(Icons.today_outlined),
              onPressed: onToday,
            ),
            const SizedBox(width: 4),
            // Dropdown chọn chế độ xem
            DropdownButtonHideUnderline(
              child: DropdownButton<ScheduleView>(
                value: view,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: ScheduleView.day,
                    child: Text('Ngày'),
                  ),
                  DropdownMenuItem(
                    value: ScheduleView.week,
                    child: Text('Tuần'),
                  ),
                  DropdownMenuItem(
                    value: ScheduleView.month,
                    child: Text('Tháng'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChangeView(v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
