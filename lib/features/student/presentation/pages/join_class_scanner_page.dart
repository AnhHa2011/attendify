// lib/presentation/pages/student/join_class_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class JoinClassScannerPage extends StatefulWidget {
  const JoinClassScannerPage({super.key});

  @override
  State<JoinClassScannerPage> createState() => _JoinClassScannerPageState();
}

class _JoinClassScannerPageState extends State<JoinClassScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanCompleted = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã tham gia lớp')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              // Để tránh quét nhiều lần, ta đặt một cờ kiểm tra
              if (!_isScanCompleted) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  setState(() {
                    _isScanCompleted = true;
                  });
                  // QUAN TRỌNG: Trả kết quả (mã đã quét) về trang trước đó
                  Navigator.pop(context, barcodes.first.rawValue!);
                }
              }
            },
          ),
          // Lớp phủ giao diện để hướng dẫn người dùng
          Column(
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
                'Di chuyển camera đến mã QR của lớp học',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
