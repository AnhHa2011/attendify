import 'package:flutter/material.dart';
import 'package:attendify/features/leave/data/models/leave_request_model.dart';

class LeaveRequestTile extends StatelessWidget {
  const LeaveRequestTile({
    super.key,
    required this.model,
    this.onApprove,
    this.onReject,
    this.showActions = false,
  });

  final LeaveRequestModel model;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions; // chỉ GV và khi pending

  @override
  Widget build(BuildContext context) {
    final title = model.className ?? model.classId;
    final sessionStr = _sessionText(model);
    final status = _statusMeta(model.status);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(status.$1),
                  backgroundColor: status.$2.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: status.$2,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: status.$2.withOpacity(0.35)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (sessionStr.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.event, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(sessionStr, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model.reason.isEmpty ? '(không có lý do)' : model.reason,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (model.status != 'pending' &&
                (model.approverNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mode_comment_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ghi chú duyệt: ${model.approverNote!}',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tạo: ${_fmt(model.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Cập nhật: ${_fmt(model.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // label + color
  (String, Color) _statusMeta(String s) {
    switch (s) {
      case 'approved':
        return ('Đã duyệt', Colors.green);
      case 'rejected':
        return ('Từ chối', Colors.red);
      default:
        return ('Đang chờ', Colors.orange);
    }
  }

  String _sessionText(LeaveRequestModel m) {
    // Ưu tiên ngày đã lưu trong đơn; nếu không có thì chỉ hiển thị "Buổi <order>"
    final date = m.sessionDate != null ? _fmt(m.sessionDate!) : null;
    final parts = <String>[
      if ((m.subjectName ?? '').isNotEmpty) m.subjectName!,
      if (date != null) date,
    ];
    return parts.join(' • ');
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
