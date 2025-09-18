// lib/presentation/pages/student/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/auth_provider.dart';
import '../../../services/firebase/sessions/session_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false; // Cờ để tránh xử lý một mã QR nhiều lần

  // Hàm xử lý chính khi quét được mã
  Future<void> _handleScannedData(String qrData) async {
    // Nếu đang xử lý rồi thì bỏ qua
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    controller.stop(); // Tạm dừng camera

    try {
      // 1. Parse nội dung QR
      final parts = qrData.split('|');
      if (parts.length != 4) {
        throw Exception("Mã QR không hợp lệ.");
      }

      final classId = parts[0];
      final sessionId = parts[1];
      // final lecturerId = parts[2]; // Có thể dùng để kiểm tra thêm
      // final timestamp = int.parse(parts[3]);

      final sessionService = context.read<SessionService>();
      final studentId = context.read<AuthProvider>().user!.uid;

      // 2. Gửi dữ liệu lên Firestore để ghi nhận điểm danh
      await sessionService.markAttendance(
        classId: classId,
        sessionId: sessionId,
        studentId: studentId,
      );

      // 3. Thông báo thành công
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm danh thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      // Có thể pop trang này đi nếu muốn
      // Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // Sau 3 giây, cho phép quét lại để tránh spam
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isProcessing = false);
          controller.start(); // Khởi động lại camera
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
          // Lớp phủ giao diện
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
                // Hiển thị vòng xoay loading khi đang xử lý
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
