import 'package:attendify/features/leave/data/services/leave_request_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendify/features/leave/data/models/leave_request_model.dart';
import 'package:attendify/features/leave/presentation/widgets/leave_request_tile.dart';

import '../../../leave/presentation/pages/create_leave_request_page.dart';

class LeaveRequestStatusPage extends StatefulWidget {
  const LeaveRequestStatusPage({super.key});
  @override
  State<LeaveRequestStatusPage> createState() => _LeaveRequestStatusPageState();
}

class _LeaveRequestStatusPageState extends State<LeaveRequestStatusPage> {
  final _ds = LeaveRequestService();
  String? _statusFilter; // null = all; 'pending' | 'approved' | 'rejected'

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Bạn cần đăng nhập.')));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đơn xin nghỉ của tôi'),
      ),
      body: Column(
        children: [
          _StatusChips(
            value: _statusFilter,
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          Expanded(
            child: StreamBuilder<List<LeaveRequestModel>>(
              stream: _ds.myRequestsFiltered(
                studentId: uid,
                status: _statusFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final items = snapshot.data!;
                if (items.isEmpty)
                  return const Center(child: Text('Không có đơn.'));
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => LeaveRequestTile(model: items[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => CreateLeaveRequestPage()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Xin nghỉ'),
      ),
    );
  }
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
