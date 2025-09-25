import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class QRGeneratorService {
  /// Generate QR code data for attendance
  static String generateAttendanceQRData({
    required String classId,
    required String sessionId,
    required DateTime timestamp,
  }) {
    // Create a unique QR code with timestamp for security
    final qrData = {
      'type': 'attendance',
      'classId': classId,
      'sessionId': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'signature': _generateSignature(classId, sessionId, timestamp),
    };
    
    return 'attendify://attendance?${_mapToQueryString(qrData)}';
  }
  
  /// Generate QR code data for joining a class
  static String generateJoinClassQRData({
    required String classId,
    required String courseCode,
    required DateTime validUntil,
  }) {
    final qrData = {
      'type': 'join_class',
      'classId': classId,
      'courseCode': courseCode,
      'validUntil': validUntil.millisecondsSinceEpoch,
      'signature': _generateSignature(classId, courseCode, validUntil),
    };
    
    return 'attendify://join?${_mapToQueryString(qrData)}';
  }
  
  /// Generate signature for QR code security
  static String _generateSignature(String id1, String id2, DateTime timestamp) {
    final input = '$id1$id2${timestamp.millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Short signature
  }
  
  /// Convert map to query string
  static String _mapToQueryString(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }
  
  /// Check if QR code is still valid (within time limit)
  static bool isQRCodeValid({
    required int timestamp,
    int validityMinutes = 5,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final qrTime = timestamp;
    final diffMinutes = (now - qrTime) / (1000 * 60);
    
    return diffMinutes <= validityMinutes;
  }
  
  /// Generate dynamic QR data that changes every minute
  static String generateDynamicAttendanceQR({
    required String classId,
    required String sessionId,
  }) {
    // Round to minute to create QR that's valid for 1 minute
    final now = DateTime.now();
    final roundedTime = DateTime(
      now.year, now.month, now.day, 
      now.hour, now.minute
    );
    
    return generateAttendanceQRData(
      classId: classId,
      sessionId: sessionId,
      timestamp: roundedTime,
    );
  }
}