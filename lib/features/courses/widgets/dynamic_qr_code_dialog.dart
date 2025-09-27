// lib/presentation/pages/coursees/widgets/dynamic_qr_code_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DynamicQrCodeDialog extends StatefulWidget {
  final String courseCode;
  final String sessionId;
  final String sessionTitle;
  final int refreshInterval; // Thời gian làm mới (giây)

  const DynamicQrCodeDialog({
    super.key,
    required this.courseCode,
    required this.sessionId,
    required this.sessionTitle,
    this.refreshInterval = 60, // Mặc định 60 giây
  });

  @override
  State<DynamicQrCodeDialog> createState() => _DynamicQrCodeDialogState();
}

class _DynamicQrCodeDialogState extends State<DynamicQrCodeDialog> {
  late Timer _qrRefreshTimer;
  late Timer _autoCloseTimer;
  late String _currentQrData;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _generateQrData();
    _startQrRefreshTimer(); // Gọi hàm với tên đã được sửa

    // Bắt đầu timer tự động đóng sau 2 giờ
    _autoCloseTimer = Timer(const Duration(hours: 2), () {
      if (mounted) {
        // Có thể thêm một thông báo nhỏ trước khi đóng
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hết thời gian điểm danh.')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _qrRefreshTimer.cancel();
    _autoCloseTimer.cancel();
    super.dispose();
  }

  // Hàm tạo dữ liệu cho mã QR, bao gồm cả timestamp
  void _generateQrData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentQrData = '${widget.courseCode}|${widget.sessionId}||$timestamp';
  }

  // === SỬA LỖI: ĐỔI TÊN HÀM VÀ BIẾN CHO NHẤT QUÁN ===
  // Hàm bắt đầu bộ đếm thời gian làm mới QR
  void _startQrRefreshTimer() {
    _countdown = widget.refreshInterval;
    // Gán cho đúng biến _qrRefreshTimer
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        // Hết giờ, tạo mã mới và reset bộ đếm
        setState(() {
          _generateQrData();
          _countdown = widget.refreshInterval;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Điểm danh cho: ${widget.sessionTitle}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: QrImageView(data: _currentQrData),
          ),
          const SizedBox(height: 16),
          // Hiển thị bộ đếm ngược
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Mã sẽ làm mới sau: $_countdown giây',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ĐÓNG'),
        ),
      ],
    );
  }
}
