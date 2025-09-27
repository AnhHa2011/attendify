import 'package:attendify/features/student/data/services/student_leave_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:attendify/core/presentation/widgets/leave_request_tile.dart';

import '../../../../core/data/models/leave_request_model.dart';
import '../../../../core/data/models/leave_request_remote_datasource.dart';

class LecturerLeaveApprovalPage extends StatefulWidget {
  const LecturerLeaveApprovalPage({super.key});
  @override
  State<LecturerLeaveApprovalPage> createState() =>
      _LecturerLeaveApprovalPageState();
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        children: [
          _chip('Tất cả', value == null, () => onChanged(null)),
          _chip('Đang chờ', value == 'pending', () => onChanged('pending')),
          _chip('Đã duyệt', value == 'approved', () => onChanged('approved')),
          _chip('Từ chối', value == 'rejected', () => onChanged('rejected')),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _LecturerLeaveApprovalPageState extends State<LecturerLeaveApprovalPage> {
  final _ds = StudentLeaveRequestService();

  String? _statusFilter = 'pending'; // mặc định hiển thị pending
  String? _classCode, _className; // lớp được chọn
  String? _sessionId; // buổi (tùy chọn)
  DateTime? _sessionStart;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ====== Lấy danh sách lớp của GV (hỗ trợ 2 schema: lecturerId hoặc lecturers[]) ======
  Stream<QuerySnapshot<Map<String, dynamic>>> _myClasses() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    final classes = FirebaseFirestore.instance.collection('classes');

    // Ưu tiên lecturerId
    final s1 = classes.where('lecturerId', isEqualTo: uid).snapshots();

    // Fallback nếu DB dùng mảng lecturers
    final s2 = classes.where('lecturers', arrayContains: uid).snapshots();

    // Gộp 2 stream thành 1 (đơn giản: chạy s1; nếu rỗng → s2)
    return s1.asyncExpand((snap) async* {
      if (snap.docs.isNotEmpty) {
        yield snap;
      } else {
        yield* s2;
      }
    });
  }

  // ====== Lấy buổi theo lớp (dùng startTime; không orderBy để giảm yêu cầu index) ======
  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsByClass(
    String classCode,
  ) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('classCode', isEqualTo: classCode)
        .snapshots();
  }

  // ====== Lấy các đơn pending theo lớp (và session nếu có) ======
  Stream<List<LeaveRequestModel>> _pendingRequests() {
    if (_classCode == null) return const Stream.empty();

    Query col = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('classCode', isEqualTo: _classCode)
        .where('status', isEqualTo: 'pending'); // không orderBy → bớt index

    if (_sessionId != null) {
      col = col.where('sessionId', isEqualTo: _sessionId);
    }

    return col.snapshots().map(
      (s) => s.docs.map((d) => LeaveRequestModel.fromDoc(d)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duyệt đơn xin nghỉ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ========== Chọn lớp ==========
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myClasses(),
              builder: (c, s) {
                if (s.hasError) {
                  return Text(
                    'Lỗi tải lớp: ${s.error}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator();
                }

                final docs = s.data!.docs;
                if (docs.isEmpty) {
                  return const Text('Bạn chưa được gán lớp nào.');
                }

                // sắp xếp nhẹ theo tên nếu có
                docs.sort((a, b) {
                  final am = a.data();
                  final bm = b.data();
                  final an = (am['name'] ?? am['className'] ?? a.id)
                      .toString()
                      .toLowerCase();
                  final bn = (bm['name'] ?? bm['className'] ?? b.id)
                      .toString()
                      .toLowerCase();
                  return an.compareTo(bn);
                });

                final valid = docs.any((d) => d.id == _classCode)
                    ? _classCode
                    : null;

                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: valid,
                  items: docs.map((d) {
                    final m = d.data();
                    final name = (m['name'] ?? m['className'] ?? d.id)
                        .toString();
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                      onTap: () => _className = name,
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _classCode = v;
                      _sessionId = null;
                      _sessionStart = null;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Lớp'),
                );
              },
            ),

            const SizedBox(height: 10),

            // ========== Chọn buổi (tuỳ chọn) ==========
            if (_classCode != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _sessionsByClass(_classCode!),
                builder: (c, s) {
                  if (s.hasError) {
                    return Text(
                      'Lỗi tải buổi: ${s.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  if (!s.hasData) return const LinearProgressIndicator();

                  final list = s.data!.docs.toList()
                    ..sort((a, b) {
                      final ad =
                          (a.data()['startTime'] as Timestamp?)?.toDate() ??
                          DateTime(0);
                      final bd =
                          (b.data()['startTime'] as Timestamp?)?.toDate() ??
                          DateTime(0);
                      return ad.compareTo(bd);
                    });

                  final valid = list.any((d) => d.id == _sessionId)
                      ? _sessionId
                      : '';

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: valid,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Tất cả buổi'),
                      ),
                      ...list.map((d) {
                        final m = d.data();
                        final t = (m['startTime'] as Timestamp?)?.toDate();
                        final order = m['order'];
                        final label = t != null
                            ? 'Buổi ${order ?? ''} • ${_fmt(t)}'
                            : (m['name'] ?? d.id).toString();
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                          onTap: () => _sessionStart = t,
                        );
                      }),
                    ],
                    onChanged: (v) => setState(
                      () => _sessionId = (v?.isEmpty ?? true) ? null : v,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Buổi (tuỳ chọn)',
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),

            // ========== Danh sách pending ==========
            Expanded(
              child: _classCode == null
                  ? const Center(child: Text('Hãy chọn lớp để xem yêu cầu.'))
                  : Column(
                      children: [
                        _StatusChips(
                          value: _statusFilter,
                          onChanged: (v) => setState(() => _statusFilter = v),
                        ),
                        Expanded(
                          child: StreamBuilder<List<LeaveRequestModel>>(
                            stream: _ds.byClassFiltered(
                              classCode: _classCode!,
                              sessionId: _sessionId,
                              status: _statusFilter,
                            ),
                            builder: (c, s) {
                              if (s.hasError) {
                                return Center(
                                  child: Text(
                                    'Lỗi: ${s.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              }
                              if (!s.hasData)
                                return const LinearProgressIndicator();
                              final items = s.data!;
                              if (items.isEmpty)
                                return const Center(
                                  child: Text('Không có đơn.'),
                                );
                              return ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final m = items[i];
                                  final showActions = m.status == 'pending';
                                  return LeaveRequestTile(
                                    model: m,
                                    showActions: showActions,
                                    onApprove: showActions
                                        ? () =>
                                              _onAction(model: m, approve: true)
                                        : null,
                                    onReject: showActions
                                        ? () => _onAction(
                                            model: m,
                                            approve: false,
                                          )
                                        : null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction({
    required LeaveRequestModel model,
    required bool approve,
  }) async {
    final noteCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? 'Duyệt đơn?' : 'Từ chối đơn?'),
        content: TextField(
          controller: noteCtl,
          decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await LeaveRequestRemoteDataSource().updateStatusAndAttendance(
        req: model,
        approve: approve,
        approverId: FirebaseAuth.instance.currentUser?.uid ?? '',
        approverNote: noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Đã duyệt & cập nhật chuyên cần' : 'Đã từ chối',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.model, required this.onAction});
  final LeaveRequestModel model;
  final Future<void> Function({
    required LeaveRequestModel model,
    required bool approve,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (model.sessionDate != null) _fmt(model.sessionDate!),
      'SV: ${model.studentName ?? model.studentId}',
    ].join(' • ');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.courseName ?? model.courseCode!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 6),
            Text('Lý do xin nghỉ: ${model.reason}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(model: model, approve: false),
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onAction(model: model, approve: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
