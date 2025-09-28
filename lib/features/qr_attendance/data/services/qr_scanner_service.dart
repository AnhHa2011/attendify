import 'dart:convert';

enum QRType { attendance, joinClass, unknown }

class QRScanResult {
  final bool isValid;
  final QRType type;
  final Map<String, dynamic> data;
  final String? error;

  QRScanResult({
    required this.isValid,
    required this.type,
    required this.data,
    this.error,
  });

  QRScanResult.error(String errorMessage)
    : isValid = false,
      type = QRType.unknown,
      data = {},
      error = errorMessage;
}

class QRScannerService {
  /// Validate and parse attendance QR code
  static QRScanResult parseQRCode(String qrData) {
    try {
      if (!qrData.startsWith('attendify://')) {
        return QRScanResult.error('Invalid QR code format');
      }

      final uri = Uri.parse(qrData);
      final params = uri.queryParameters;

      // Check QR type
      final type = _getQRType(uri.host, params);
      if (type == QRType.unknown) {
        return QRScanResult.error('Unknown QR code type');
      }

      // Validate based on type
      switch (type) {
        case QRType.attendance:
          return _validateAttendanceQR(params);
        case QRType.joinClass:
          return _validateJoinClassQR(params);
        case QRType.unknown:
          return QRScanResult.error('Unknown QR code type');
      }
    } catch (e) {
      return QRScanResult.error('Failed to parse QR code: ${e.toString()}');
    }
  }

  /// Determine QR code type from URI
  static QRType _getQRType(String host, Map<String, String> params) {
    switch (host) {
      case 'attendance':
        return QRType.attendance;
      case 'join':
        return QRType.joinClass;
      default:
        // Fallback to type parameter
        final typeStr = params['type'];
        if (typeStr == 'attendance') return QRType.attendance;
        if (typeStr == 'join_class') return QRType.joinClass;
        return QRType.unknown;
    }
  }

  /// Validate attendance QR code
  static QRScanResult _validateAttendanceQR(Map<String, String> params) {
    final requiredFields = ['classCode', 'sessionId', 'timestamp', 'signature'];

    for (final field in requiredFields) {
      if (!params.containsKey(field) || params[field]!.isEmpty) {
        return QRScanResult.error('Missing required field: $field');
      }
    }

    // Check timestamp validity
    final timestampStr = params['timestamp']!;
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      return QRScanResult.error('Invalid timestamp format');
    }

    // Check if QR is still valid (within 5 minutes)
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMinutes = (now - timestamp) / (1000 * 60);
    if (diffMinutes > 5 || diffMinutes < -1) {
      return QRScanResult.error('QR code has expired or is not yet valid');
    }

    // TODO: Validate signature in production

    return QRScanResult(
      isValid: true,
      type: QRType.attendance,
      data: {
        'classCode': params['classCode']!,
        'sessionId': params['sessionId']!,
        'timestamp': timestamp,
        'signature': params['signature']!,
      },
    );
  }

  /// Validate join class QR code
  static QRScanResult _validateJoinClassQR(Map<String, String> params) {
    final requiredFields = [
      'classCode',
      'courseCode',
      'validUntil',
      'signature',
    ];

    for (final field in requiredFields) {
      if (!params.containsKey(field) || params[field]!.isEmpty) {
        return QRScanResult.error('Missing required field: $field');
      }
    }

    // Check validity period
    final validUntilStr = params['validUntil']!;
    final validUntil = int.tryParse(validUntilStr);
    if (validUntil == null) {
      return QRScanResult.error('Invalid validity format');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > validUntil) {
      return QRScanResult.error('QR code has expired');
    }

    // TODO: Validate signature in production

    return QRScanResult(
      isValid: true,
      type: QRType.joinClass,
      data: {
        'classCode': params['classCode']!,
        'courseCode': params['courseCode']!,
        'validUntil': validUntil,
        'signature': params['signature']!,
      },
    );
  }

  /// Check if QR code is for attendance
  static bool isAttendanceQR(String qrData) {
    try {
      if (!qrData.startsWith('attendify://')) return false;
      final uri = Uri.parse(qrData);
      return uri.host == 'attendance' ||
          uri.queryParameters['type'] == 'attendance';
    } catch (e) {
      return false;
    }
  }

  /// Check if QR code is for joining a class
  static bool isJoinClassQR(String qrData) {
    try {
      if (!qrData.startsWith('attendify://')) return false;
      final uri = Uri.parse(qrData);
      return uri.host == 'join' || uri.queryParameters['type'] == 'join_class';
    } catch (e) {
      return false;
    }
  }
}
