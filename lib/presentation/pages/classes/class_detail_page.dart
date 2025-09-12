import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart'; // Thêm thư viện intl để format ngày tháng

// Import các model và service cần thiết
import '../../../data/models/class_model.dart';
import '../../../data/models/session_model.dart';
import '../../../services/firebase/class_service.dart';
import '../../../services/firebase/session_service.dart';
import '../../../app/providers/auth_provider.dart';

// 1. CHUYỂN THÀNH STATEFULWIDGET
class ClassDetailPage extends StatefulWidget {
  final String classId;
  const ClassDetailPage({super.key, required this.classId});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  bool _isCreatingSession = false;

  // 2. HÀM TẠO BUỔI HỌC VÀ HIỂN THỊ QR
  Future<void> _startNewAttendanceSession(ClassModel c) async {
    setState(() => _isCreatingSession = true);

    try {
      final sessionService = context.read<SessionService>();
      final authProvider = context.read<AuthProvider>();
      final lecturer = authProvider.user!;

      // Tạo buổi học mới trong Firestore
      final String sessionId = await sessionService.createSession(
        classId: c.id,
        className: c.className,
        classCode: c.classCode,
        lecturerId: lecturer.uid,
        lecturerName: c.lecturerName,
        title:
            'Buổi học ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(
          const Duration(minutes: 90),
        ), // QR có hiệu lực 90 phút
        location: 'Tại lớp',
        type: SessionType.lecture,
      );

      // Sinh dữ liệu cho mã QR
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final qrData = '${c.id}|${sessionId}|${lecturer.uid}|${timestamp}';

      if (!mounted) return;

      // Mở cổng điểm danh
      await sessionService.toggleAttendance(sessionId, true);

      // Hiển thị Dialog chứa mã QR
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Điểm danh bằng mã QR'),
          content: SizedBox(
            width: 250,
            height: 250,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await sessionService.toggleAttendance(sessionId, false);
                Navigator.of(context).pop();
              },
              child: const Text('ĐÓNG ĐIỂM DANH'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tạo buổi học: $e')));
    } finally {
      if (mounted) setState(() => _isCreatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classSvc = context.read<ClassService>();
    // Thêm service mới
    final sessionSvc = context.read<SessionService>();

    return StreamBuilder<ClassModel>(
      stream: classSvc.classStream(widget.classId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy lớp')),
          );
        }
        final c = snap.data!;
        return Scaffold(
          appBar: AppBar(title: Text('${c.classCode} - ${c.className}')),
          // 3. THÊM NÚT BẮT ĐẦU ĐIỂM DANH
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isCreatingSession
                ? null
                : () => _startNewAttendanceSession(c),
            label: const Text('Bắt đầu điểm danh'),
            icon: _isCreatingSession
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_scanner),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              80,
            ), // Thêm padding dưới cho FAB
            children: [
              // --- PHẦN THÔNG TIN LỚP VÀ MÃ THAM GIA (GIỮ NGUYÊN) ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Mã tham gia lớp: ${c.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      QrImageView(data: c.joinCode, size: 180),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Tạo mã mới'),
                        onPressed: () async {
                          await classSvc.regenerateJoinCode(c.id);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. THÊM PHẦN HIỂN THỊ DANH SÁCH BUỔI HỌC
              Text(
                'Các buổi học',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<SessionModel>>(
                stream: sessionSvc.sessionsOfClass(widget.classId),
                builder: (context, sessionSnap) {
                  if (sessionSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = sessionSnap.data ?? [];
                  if (sessions.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Chưa có buổi học nào được tạo.'),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.event_available),
                          title: Text(session.title),
                          subtitle: Text(
                            '${DateFormat.yMd().add_Hm().format(session.startTime)} - Trạng thái: ${session.status.name}',
                          ),
                          // Bạn có thể thêm các hành động khác ở đây, ví dụ xem chi tiết điểm danh
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Điều hướng đến trang chi tiết buổi học (nếu có)
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),
              Text(
                'Danh sách sinh viên',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              // --- PHẦN DANH SÁCH SINH VIÊN (GIỮ NGUYÊN) ---
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: classSvc.membersStream(c.id),
                builder: (context, ms) {
                  if (ms.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = ms.data ?? [];
                  if (members.isEmpty) {
                    return const Text('Chưa có sinh viên tham gia');
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = members[i];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(m['displayName'] ?? ''),
                          subtitle: Text(m['email'] ?? ''),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
