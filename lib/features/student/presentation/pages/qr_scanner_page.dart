// lib/presentation/pages/student/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/auth_provider.dart';
import '../../../sessions/presentation/pages/data/services/session_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _handleScannedData(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    controller.stop();

    try {
      final parts = qrData.split('|');
      if (parts.length != 4) {
        throw Exception("Mã QR không hợp lệ.");
      }

      // === THAY ĐỔI: CHỈ CẦN LẤY sessionId ===
      // final classId = parts[0]; // Không cần dùng nữa
      final sessionId = parts[1];

      final sessionService = context.read<SessionService>();
      final studentId = context.read<AuthProvider>().user!.uid;

      // === THAY ĐỔI: GỌI HÀM markAttendance VỚI ĐÚNG THAM SỐ ===
      await sessionService.markAttendance(
        sessionId: sessionId,
        studentId: studentId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm danh thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Sửa lại cách hiển thị lỗi để thân thiện hơn
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isProcessing = false);
          controller.start();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Giao diện không cần thay đổi, giữ nguyên
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _handleScannedData(barcodes.first.rawValue!);
              }
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Di chuyển camera đến mã QR để điểm danh',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 40),
                if (_isProcessing)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
