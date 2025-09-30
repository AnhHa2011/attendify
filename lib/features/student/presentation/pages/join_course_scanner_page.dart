// lib/presentation/pages/student/join_course_scanner_page.dart

import 'dart:async'; // 👈 để dùng FutureOr
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class JoinCourseScannerPage extends StatefulWidget {
  const JoinCourseScannerPage({super.key});

  @override
  State<JoinCourseScannerPage> createState() => _JoinCourseScannerPageState();
}

class _JoinCourseScannerPageState extends State<JoinCourseScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false, // Không tự bật camera
  );

  bool _isScanCompleted = false;
  bool _cameraOn = false; // trạng thái camera
  bool _processing = false; // chống spam detect

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  // Tắt/bật camera theo vòng đời app (an toàn)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_cameraOn) return;
    if (state == AppLifecycleState.resumed) {
      controller.start();
    } else {
      controller.stop();
    }
  }

  Future<void> _startCamera() async {
    // B1: Gọi setState để Flutter bắt đầu build widget MobileScanner
    if (!mounted) return;
    setState(() {
      _cameraOn = true;
    });

    // B2: Đợi cho frame hiện tại được build xong, sau đó mới thực thi .start()
    // Đây là cách làm an toàn và đảm bảo widget đã được build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await controller.start();
      } catch (e) {
        if (!mounted) return;
        // Nếu có lỗi khi start, tắt cờ camera đi
        setState(() => _cameraOn = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không bật được camera: $e')));
      }
    });
  }

  Future<void> _stopCamera() async {
    try {
      // SỬA LỖI: Chỉ cần kiểm tra biến trạng thái của chính bạn
      if (_cameraOn) {
        await controller.stop();
      }
    } catch (e) {
      // Ghi log lỗi nếu cần, nhưng không cần báo cho người dùng
      debugPrint('Lỗi khi tắt camera: $e');
    } finally {
      // Dù có lỗi hay không, luôn cập nhật UI để ẩn camera đi
      if (mounted) {
        setState(() {
          _cameraOn = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraOn) {
      await _stopCamera();
    } else {
      await _startCamera();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_cameraOn || _processing || _isScanCompleted) return;

    final codes = capture.barcodes;
    final value = codes.isNotEmpty ? codes.first.rawValue : null;
    if (value == null) return;

    _processing = true;
    _isScanCompleted = true;

    try {
      await controller.stop();
      if (!mounted) return;
      Navigator.pop(context, value); // trả mã về trang trước
    } finally {
      _processing = false;
    }
  }

  void _showInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
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
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4), // 👈 đổi from withOpacity
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hướng dẫn quét QR tham gia môn',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '1) Nhấn “Bật camera”\n'
                '2) Đưa camera tới mã QR giảng viên cung cấp\n'
                '3) Đảm bảo mã nằm trọn trong khung\n'
                '4) Giữ máy ổn định cho tới khi có tiếng “tách”\n'
                '5) Kết quả sẽ tự điền về màn trước',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Quét mã QR tham gia môn'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera
          Positioned.fill(
            child: _cameraOn
                ? MobileScanner(controller: controller, onDetect: _onDetect)
                : const ColoredBox(color: Colors.black),
          ),

          // Khung & hướng dẫn ở giữa, width gọn
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _cameraOn ? Colors.white : Colors.white24,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _cameraOn
                        ? 'Đưa mã QR vào trong khung'
                        : 'Bấm nút "Bật camera" để bắt đầu quét QR',
                    style: TextStyle(
                      color: _cameraOn ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Thanh hành động dưới
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: _cameraOn ? Icons.videocam_off : Icons.videocam,
                label: _cameraOn ? 'Tạm dừng' : 'Bật camera',
                onTap: _toggleCamera, // sync/async đều OK
              ),
              _ActionButton(
                icon: Icons.flash_on,
                label: 'Đèn flash',
                // 👇 nếu SDK của bạn trả về void, vẫn hợp lệ
                onTap: _cameraOn ? controller.toggleTorch : null,
                disabled: !_cameraOn,
              ),
              _ActionButton(
                icon: Icons.cameraswitch,
                label: 'Đổi camera',
                onTap: _cameraOn ? controller.switchCamera : null,
                disabled: !_cameraOn,
              ),
              _ActionButton(
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
}

// Nút hành động dưới cùng
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;

  // ✅ CHO PHÉP HÀM sync (void) HOẶC async (Future<void>)
  final FutureOr<void> Function()? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final color = disabled ? Colors.white24 : Colors.white;

    return InkWell(
      onTap: disabled
          ? null
          : () async {
              final fn = onTap;
              if (fn != null) {
                // Gọi đồng bộ hoặc bất đồng bộ đều OK
                await Future.sync(fn);
              }
            },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
