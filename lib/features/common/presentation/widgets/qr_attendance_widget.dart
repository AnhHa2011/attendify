import 'package:flutter/material.dart';

class QRAttendanceWidget extends StatelessWidget {
  final String classId;
  const QRAttendanceWidget({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'QR Điểm danh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Tính năng đang được hoàn thiện',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
