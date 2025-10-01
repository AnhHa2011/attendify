// lib/features/student/presentation/pages/qr_scanner_page.dart

import 'package:attendify/core/data/models/session_model.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../app/providers/auth_provider.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  /// IMPORTANT: do NOT autostart; user must tap the button to start.
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  bool _isCameraOn = false; // track whether user has turned on the camera

  @override
  bool get wantKeepAlive => false; // để khi rời tab thì dispose view

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kiểm tra xem widget này có đang hiển thị trong TabBarView không
    final isCurrentlyVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrentlyVisible && _isCameraOn) {
      controller.stop();
      setState(() => _isCameraOn = false);
    }
  }

  // Allow parent to control camera (if needed)
  void stopCamera() {
    if (mounted && _isCameraOn) {
      controller.stop();
      setState(() => _isCameraOn = false);
    }
  }

  void startCamera() {
    if (mounted && !_isProcessing && !_isCameraOn) {
      controller.start();
      setState(() => _isCameraOn = true);
    }
  }

  void _toggleCamera() {
    if (_isCameraOn) {
      controller.stop();
      setState(() => _isCameraOn = false);
    } else {
      controller.start();
      setState(() => _isCameraOn = true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // NOTE: We intentionally do NOT start the camera here.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // Only resume camera if user previously turned it on
        if (_isCameraOn && !_isProcessing) {
          controller.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Always stop while backgrounded
        controller.stop();
        break;
    }
  }

  Future<void> _handleScannedData(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Stop preview while processing
    if (_isCameraOn) {
      await controller.stop();
    }

    try {
      final parts = qrData.split('|');
      if (parts.length != 4) {
        throw Exception("Mã QR không hợp lệ.");
      }

      final sessionId = parts[1];
      final studentId = context.read<AuthProvider>().user!.uid;

      // Check session
      final sessionDoc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception("Session không tồn tại.");
      }

      // SỬ DỤNG SessionModel ĐỂ ĐỌC DỮ LIỆU MỘT CÁCH AN TOÀN
      final session = SessionModel.fromDoc(
        sessionDoc as DocumentSnapshot<Map<String, dynamic>>,
      );

      // Bây giờ, truy cập dữ liệu qua đối tượng 'session'
      if (!session.isOpen) {
        // Dùng session.isOpen
        throw Exception("Session đã đóng. Không thể điểm danh.");
      }

      // Check enrollment
      final enrollmentQuery = await _firestore
          .collection('enrollments')
          // SỬA LỖI: Truy vấn bằng 'courseCode' để khớp với EnrollmentModel
          .where('courseCode', isEqualTo: session.courseCode)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (enrollmentQuery.docs.isEmpty) {
        throw Exception("Bạn không thuộc lớp học này.");
      }

      // Check already attended
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        throw Exception("Bạn đã điểm danh cho buổi học này rồi.");
      }

      // Mark attendance
      await _firestore.collection('attendance').add({
        'sessionId': sessionId,
        'studentId': studentId,
        'status': 'present',
        'timestamp': FieldValue.serverTimestamp(),
        'method': 'qr_code',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm danh thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Small delay before allowing another scan
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Only restart if user still wants camera on
      if (_isCameraOn) {
        controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Quét mã QR điểm danh'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Show preview only if camera is on
          if (_isCameraOn)
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_isProcessing) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _handleScannedData(barcodes.first.rawValue!);
                }
              },
            )
          else
            const Center(
              child: Text(
                'Bấm nút "Bật camera" để bắt đầu quét QR',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),

          // Overlay UI
          if (_isCameraOn)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scanner Frame
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing ? Colors.orange : Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isProcessing
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 30),
                  // Instructions
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isProcessing
                              ? Icons.hourglass_empty
                              : Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isProcessing
                              ? 'Đang xử lý điểm danh...'
                              : 'Đưa camera đến mã QR để điểm danh',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!_isProcessing) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Đảm bảo mã QR nằm trong khung trên',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Corners (only when camera on)
          if (_isCameraOn) ...[
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 140,
              left: MediaQuery.of(context).size.width / 2 - 140,
              child: _buildCorner(isTopLeft: true),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 140,
              right: MediaQuery.of(context).size.width / 2 - 140,
              child: _buildCorner(isTopRight: true),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height / 2 - 140,
              left: MediaQuery.of(context).size.width / 2 - 140,
              child: _buildCorner(isBottomLeft: true),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height / 2 - 140,
              right: MediaQuery.of(context).size.width / 2 - 140,
              child: _buildCorner(isBottomRight: true),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.videocam,
                label: _isCameraOn ? 'Tắt camera' : 'Bật camera',
                onTap: _toggleCamera,
              ),
              _buildActionButton(
                icon: Icons.flash_on,
                label: 'Đèn flash',
                onTap: _isCameraOn ? () => controller.toggleTorch() : null,
              ),
              _buildActionButton(
                icon: Icons.cameraswitch,
                label: 'Đổi camera',
                onTap: _isCameraOn ? () => controller.switchCamera() : null,
              ),
              _buildActionButton(
                icon: Icons.help_outline,
                label: 'Hướng dẫn',
                onTap: _showInstructions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner({
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: (isTopLeft || isTopRight)
              ? const BorderSide(color: Colors.green, width: 4)
              : BorderSide.none,
          left: (isTopLeft || isBottomLeft)
              ? const BorderSide(color: Colors.green, width: 4)
              : BorderSide.none,
          right: (isTopRight || isBottomRight)
              ? const BorderSide(color: Colors.green, width: 4)
              : BorderSide.none,
          bottom: (isBottomLeft || isBottomRight)
              ? const BorderSide(color: Colors.green, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.white24,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white24,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Hướng dẫn điểm danh',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '1. Bấm "Bật camera" để mở máy quét\n'
                '2. Đưa camera đến mã QR do giảng viên cung cấp\n'
                '3. Đảm bảo mã QR nằm trong khung quét\n'
                '4. Khi thành công, bạn sẽ thấy thông báo xanh\n'
                '5. Mỗi session chỉ có thể điểm danh một lần',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
