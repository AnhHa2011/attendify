import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';

import '../../data/services/qr_generator_service.dart';

class QRGeneratorPage extends StatefulWidget {
  final String classCode;
  final String sessionId;
  final String className;
  final VoidCallback? onClose;

  const QRGeneratorPage({
    super.key,
    required this.classCode,
    required this.sessionId,
    required this.className,
    this.onClose,
  });

  @override
  State<QRGeneratorPage> createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  String _qrData = '';
  Timer? _refreshTimer;
  DateTime _lastUpdate = DateTime.now();
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _generateInitialQR();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _generateInitialQR() {
    setState(() {
      _qrData = QRGeneratorService.generateDynamicAttendanceQR(
        classCode: widget.classCode,
        sessionId: widget.sessionId,
      );
      _lastUpdate = DateTime.now();
    });
  }

  void _startDynamicQR() {
    setState(() {
      _isActive = true;
    });

    // Refresh QR code every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _qrData = QRGeneratorService.generateDynamicAttendanceQR(
            classCode: widget.classCode,
            sessionId: widget.sessionId,
          );
          _lastUpdate = DateTime.now();
        });
      }
    });
  }

  void _stopDynamicQR() {
    setState(() {
      _isActive = false;
    });
    _refreshTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('QR Điểm Danh'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _stopDynamicQR();
            widget.onClose?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isActive ? Icons.pause : Icons.play_arrow),
            onPressed: _isActive ? _stopDynamicQR : _startDynamicQR,
            tooltip: _isActive ? 'Tạm dừng' : 'Bắt đầu',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Class info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.className,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Session: ${widget.sessionId}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // QR Code
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _qrData.isNotEmpty
                    ? QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 280,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      )
                    : const SizedBox(
                        width: 280,
                        height: 280,
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),

              const SizedBox(height: 24),

              // Status and controls
              Card(
                color: _isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isActive ? 'Đang hoạt động' : 'Đã tạm dừng',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _isActive
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Cập nhật lần cuối: ${_formatTime(_lastUpdate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isActive
                              ? theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.7)
                              : theme.colorScheme.onSurfaceVariant.withOpacity(
                                  0.7,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hướng dẫn sử dụng',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('1. Nhấn nút phát để bắt đầu điểm danh'),
                      const SizedBox(height: 4),
                      const Text('2. Sinh viên quét mã QR để điểm danh'),
                      const SizedBox(height: 4),
                      const Text('3. Mã QR tự động đổi mỗi phút để bảo mật'),
                      const SizedBox(height: 4),
                      const Text('4. Nhấn nút tạm dừng để kết thúc'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: _isActive
                    ? FilledButton.icon(
                        onPressed: _stopDynamicQR,
                        icon: const Icon(Icons.pause),
                        label: const Text('Tạm dừng điểm danh'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _startDynamicQR,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Bắt đầu điểm danh'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
