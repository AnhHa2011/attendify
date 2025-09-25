import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';
import '../../services/lecturer_service.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({Key? key}) : super(key: key);

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsState();
}

class _LeaveRequestsState extends State<LeaveRequestsPage>
    with TickerProviderStateMixin {
  final LecturerService _lecturerService = LecturerService();
  late TabController _tabController;

  List<LeaveRequest> _allRequests = [];
  List<LeaveRequest> _pendingRequests = [];
  List<LeaveRequest> _processedRequests = [];

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadLeaveRequests() {
    setState(() {
      isLoading = true;
      error = null;
    });

    _lecturerService.getLeaveRequests().listen(
      (requests) {
        if (mounted) {
          setState(() {
            _allRequests = requests;
            _pendingRequests = requests
                .where((req) => req.status == LeaveRequestStatus.pending)
                .toList();
            _processedRequests = requests
                .where((req) => req.status != LeaveRequestStatus.pending)
                .toList();
            isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            error = e.toString();
            isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _respondToRequest(
    LeaveRequest request,
    LeaveRequestStatus status,
  ) async {
    String? response;

    // Show dialog to get lecturer response
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ResponseDialog(
        request: request,
        isApproval: status == LeaveRequestStatus.approved,
      ),
    );

    if (result != null) {
      response = result['response'];

      try {
        await _lecturerService.respondToLeaveRequest(
          request.id,
          status,
          response,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == LeaveRequestStatus.approved
                    ? 'Đã duyệt đơn xin nghỉ'
                    : 'Đã từ chối đơn xin nghỉ',
              ),
              backgroundColor: status == LeaveRequestStatus.approved
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xử lý đơn: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đơn xin nghỉ'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Tất cả',
              icon: Badge(
                label: Text('${_allRequests.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
            Tab(
              text: 'Chờ duyệt',
              icon: Badge(
                label: Text('${_pendingRequests.length}'),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Đã xử lý',
              icon: Badge(
                label: Text('${_processedRequests.length}'),
                child: const Icon(Icons.check_circle),
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
                _buildRequestsList(_allRequests),
                _buildRequestsList(_pendingRequests),
                _buildRequestsList(_processedRequests),
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
            'Không thể tải danh sách đơn xin nghỉ',
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
            onPressed: _loadLeaveRequests,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<LeaveRequest> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có đơn xin nghỉ nào',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Danh sách đơn xin nghỉ sẽ hiển thị ở đây',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadLeaveRequests(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest request) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with student info and status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    request.studentName.isNotEmpty
                        ? request.studentName[0].toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.studentName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.studentEmail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    request.statusText,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(
                    request.status,
                  ).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _getStatusColor(request.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Session info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.courseName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.sessionTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
                        DateFormat(
                          'dd/MM/yyyy - HH:mm',
                        ).format(request.sessionDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Request details
            Text(
              'Lý do xin nghỉ:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(request.reason, style: Theme.of(context).textTheme.bodyMedium),

            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Mô tả chi tiết:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                request.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            const SizedBox(height: 12),

            // Request date
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  'Gửi lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(request.requestDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),

            // Lecturer response (if processed)
            if (request.lecturerResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(request.status).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          request.status == LeaveRequestStatus.approved
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 16,
                          color: _getStatusColor(request.status),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Phản hồi của giảng viên:',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(request.status),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.lecturerResponse!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (request.responseDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Phản hồi lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(request.responseDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Action buttons for pending requests
            if (request.isPending && request.canRespond) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondToRequest(
                        request,
                        LeaveRequestStatus.rejected,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _respondToRequest(
                        request,
                        LeaveRequestStatus.approved,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Duyệt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
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

  Color _getStatusColor(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return Colors.orange;
      case LeaveRequestStatus.approved:
        return Colors.green;
      case LeaveRequestStatus.rejected:
        return Colors.red;
    }
  }
}

class _ResponseDialog extends StatefulWidget {
  final LeaveRequest request;
  final bool isApproval;

  const _ResponseDialog({required this.request, required this.isApproval});

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isApproval ? 'Duyệt đơn xin nghỉ' : 'Từ chối đơn xin nghỉ',
        style: TextStyle(color: widget.isApproval ? Colors.green : Colors.red),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sinh viên: ${widget.request.studentName}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Lý do: ${widget.request.reason}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _responseController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Phản hồi của bạn',
              hintText: widget.isApproval
                  ? 'Ghi chú về việc duyệt đơn (không bắt buộc)...'
                  : 'Lý do từ chối...',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop({'response': _responseController.text.trim()});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.isApproval ? 'Duyệt' : 'Từ chối'),
        ),
      ],
    );
  }
}
