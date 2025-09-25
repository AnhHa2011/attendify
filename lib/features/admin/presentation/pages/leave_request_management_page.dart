import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaveRequestManagementPage extends StatefulWidget {
  const LeaveRequestManagementPage({super.key});

  @override
  State<LeaveRequestManagementPage> createState() =>
      _LeaveRequestManagementPageState();
}

class _LeaveRequestManagementPageState
    extends State<LeaveRequestManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Quản lý Đơn xin nghỉ'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildLeaveRequestsList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Tìm kiếm theo tên sinh viên...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Lọc theo trạng thái',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tất cả')),
              DropdownMenuItem(value: 'pending', child: Text('Đang chờ')),
              DropdownMenuItem(value: 'approved', child: Text('Đã duyệt')),
              DropdownMenuItem(value: 'rejected', child: Text('Từ chối')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final leaveRequests = snapshot.data?.docs ?? [];

        if (leaveRequests.isEmpty) {
          return const Center(child: Text('Không có đơn xin nghỉ nào'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: leaveRequests.length,
          itemBuilder: (context, index) {
            final doc = leaveRequests[index];
            return _buildLeaveRequestCard(doc);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query query = _firestore.collection('leave_requests');

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  Widget _buildLeaveRequestCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final studentName = data['studentName'] ?? 'N/A';
    final courseName = data['courseName'] ?? 'N/A';
    final reason = data['reason'] ?? 'N/A';
    final status = data['status'] ?? 'pending';
    final sessionDate = data['sessionDate'] != null
        ? (data['sessionDate'] as Timestamp).toDate()
        : DateTime.now();
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    // Filter by search query
    if (_searchQuery.isNotEmpty &&
        !studentName.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Môn học: $courseName'),
            const SizedBox(height: 4),
            Text(
              'Buổi học: ${DateFormat('dd/MM/yyyy HH:mm').format(sessionDate)}',
            ),
            const SizedBox(height: 4),
            Text('Lý do: $reason'),
            const SizedBox(height: 4),
            Text(
              'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        _updateLeaveRequestStatus(doc.id, 'rejected'),
                    child: const Text('Từ chối'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        _updateLeaveRequestStatus(doc.id, 'approved'),
                    child: const Text('Duyệt'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Đã duyệt';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Từ chối';
        break;
      default:
        color = Colors.orange;
        text = 'Đang chờ';
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _updateLeaveRequestStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('leave_requests').doc(docId).update({
        'status': newStatus,
        'reviewedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'Đã duyệt đơn xin nghỉ'
                  : 'Đã từ chối đơn xin nghỉ',
            ),
            backgroundColor: newStatus == 'approved'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
