// lib/features/student/presentation/pages/qr_scanner_page.dart

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
    with WidgetsBindingObserver {
  late final MobileScannerController controller;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  bool _cameraOn = false; // <-- chỉ bật khi người dùng bấm nút

  // Cho parent (StudentLayout) gọi để tắt camera nếu cần
  void stopCamera() {
    if (mounted && _cameraOn) {
      _toggleCamera(forceOff: true);
    }
  }

  // Cho parent bật lại camera nếu cần (vẫn không tự bật trừ khi gọi)
  void startCamera() {
    if (mounted && !_cameraOn && !_isProcessing) {
      _toggleCamera(forceOn: true);
    }
  }

  @override
  void initState() {
    super.initState();
    // KHÔNG auto start
    controller = MobileScannerController(
      autoStart: false, // <-- quan trọng
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );
    WidgetsBinding.instance.addObserver(this);
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
        // KHÔNG tự bật lại camera.
        // Nếu trước đó người dùng đang bật (_cameraOn == true) và app quay lại,
        // vẫn không tự bật — để đúng yêu cầu “chỉ mở khi bấm nút”.
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Nếu đang bật thì tắt khi rời app
        if (_cameraOn) {
          _toggleCamera(forceOff: true);
        }
        break;
    }
  }

  Future<void> _toggleCamera({bool? forceOn, bool? forceOff}) async {
    try {
      if (forceOn == true) {
        await controller.start();
        setState(() => _cameraOn = true);
        return;
      }
      if (forceOff == true) {
        await controller.stop();
        setState(() => _cameraOn = false);
        return;
      }

      if (_cameraOn) {
        await controller.stop();
        setState(() => _cameraOn = false);
      } else {
        await controller.start();
        setState(() => _cameraOn = true);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handleScannedData(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Tạm dừng camera trong lúc xử lý
    if (_cameraOn) {
      await _toggleCamera(forceOff: true);
    }

    try {
      // QR format kỳ vọng: <prefix>|<sessionId>|<...>|<...>
      final parts = qrData.split('|');
      if (parts.length != 4) {
        throw Exception("Mã QR không hợp lệ.");
      }

      final sessionId = parts[1];
      final auth = context.read<AuthProvider>();
      final studentId = auth.user!.uid;

      // 1) Kiểm tra session tồn tại và đang mở
      final sessionDoc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();
      if (!sessionDoc.exists) {
        throw Exception("Session không tồn tại.");
      }
      final sessionData = sessionDoc.data()!;
      final isOpen = (sessionData['isOpen'] as bool?) ?? false;
      final courseId = sessionData['courseId'] as String?;

      if (courseId == null || courseId.isEmpty) {
        throw Exception("Dữ liệu session không hợp lệ.");
      }
      if (!isOpen) {
        throw Exception("Session đã đóng. Không thể điểm danh.");
      }

      // 2) Kiểm tra sinh viên thuộc lớp không
      final enrollmentQuery = await _firestore
          .collection('enrollments')
          .where('courseId', isEqualTo: courseId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (enrollmentQuery.docs.isEmpty) {
        throw Exception("Bạn không thuộc lớp học này.");
      }

      // 3) Kiểm tra đã điểm danh chưa
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        throw Exception("Bạn đã điểm danh cho buổi học này rồi.");
      }

      // 4) Ghi điểm danh
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
      // Cho phép quét tiếp: bật lại camera sau 2s nhưng CHỈ khi người dùng muốn bật
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _isProcessing = false);
      // KHÔNG tự bật lại — để giữ đúng yêu cầu “chỉ mở khi bấm nút”
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Quét mã QR điểm danh'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: !_cameraOn
                ? null
                : () {
                    controller.toggleTorch();
                  },
            icon: const Icon(Icons.flash_on),
            tooltip: 'Bật/tắt đèn flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Scanner (sẽ hiển thị preview khi _cameraOn == true)
          if (_cameraOn)
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _handleScannedData(barcodes.first.rawValue!);
                }
              },
            )
          else
            // Placeholder khi camera tắt
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white.withOpacity(0.7),
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Camera đang tắt\nBấm "Bật camera" để bắt đầu quét',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Overlay UI (khung ngắm + hướng dẫn)
          if (_cameraOn)
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

          // Corner decorations
          if (_cameraOn) ...[
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
              // Bật/Tắt camera (nút chính)
              _buildActionButton(
                icon: _cameraOn ? Icons.videocam_off : Icons.videocam,
                label: _cameraOn ? 'Tắt camera' : 'Bật camera',
                onTap: () => _toggleCamera(),
              ),
              _buildActionButton(
                icon: Icons.cameraswitch,
                label: 'Đổi camera',
                onTap: _cameraOn ? () => controller.switchCamera() : null,
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
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
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
                '1. Bấm nút "Bật camera" để mở camera\n'
                '2. Đưa camera đến mã QR do giảng viên cung cấp\n'
                '3. Đảm bảo mã QR nằm trong khung quét\n'
                '4. Giữ máy ổn định và đợi quét tự động\n'
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
