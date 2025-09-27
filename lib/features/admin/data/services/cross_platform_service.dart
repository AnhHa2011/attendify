// lib/features/admin/data/services/cross_platform_service.dart
import '../../../../app_imports.dart';

/// Service xử lý các tính năng cross-platform
/// Đảm bảo tương thích với Web, iOS, Android, macOS
class CrossPlatformService {
  /// Tạo QR Code data cho điểm danh
  /// Returns a JSON string that can be encoded to QR
  static String generateAttendanceQRData({
    required String sessionId,
    required String classCode,
    required String courseCode,
    required DateTime timestamp,
    int validityMinutes = 10,
  }) {
    final expiresAt = timestamp.add(Duration(minutes: validityMinutes));

    final qrData = {
      'type': 'attendance',
      'sessionId': sessionId,
      'classCode': classCode,
      'courseCode': courseCode,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'nonce': _generateNonce(),
    };

    return jsonEncode(qrData);
  }

  /// Kiểm tra tính hợp lệ của QR code
  static bool validateAttendanceQR(String qrData) {
    try {
      final data = jsonDecode(qrData);

      // Kiểm tra type
      if (data['type'] != 'attendance') return false;

      // Kiểm tra expiration
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(data['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) return false;

      // Kiểm tra required fields
      return data['sessionId'] != null &&
          data['classCode'] != null &&
          data['courseCode'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Parse QR data
  static Map<String, dynamic>? parseAttendanceQR(String qrData) {
    try {
      final data = jsonDecode(qrData);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return null;
    }
  }

  /// Tạo mã tham gia môn học
  static String generateJoinCode([int length = 8]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Generate unique identifier
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random.secure().nextInt(99999).toString().padLeft(5, '0');
  }

  /// Tạo nonce để bảo mật
  static String _generateNonce([int length = 16]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Kiểm tra platform hiện tại
  static bool get isWeb => kIsWeb;
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Format file size cho cross-platform
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (bytes == 0) ? 0 : (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Tạo màu ngẫu nhiên
  static int generateRandomColor() {
    final random = Random();
    return 0xFF000000 + random.nextInt(0xFFFFFF);
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate Vietnamese phone number
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^(0|\+84)[3|5|7|8|9][0-9]{8}$').hasMatch(phone);
  }

  /// Safe URL opening (cross-platform compatible)
  static void openUrl(String url) {
    // Implementation will depend on url_launcher package
    // but this ensures we have a centralized place for URL handling
    if (kDebugMode) {
      print('Opening URL: $url');
    }
  }

  /// File extension validation
  static bool isValidFileExtension(
    String filename,
    List<String> allowedExtensions,
  ) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// Create Excel-compatible filename
  static String createExcelFilename(String baseName, [DateTime? timestamp]) {
    final time = timestamp ?? DateTime.now();
    final timeStr =
        '${time.year}${time.month.toString().padLeft(2, '0')}'
        '${time.day.toString().padLeft(2, '0')}_'
        '${time.hour.toString().padLeft(2, '0')}'
        '${time.minute.toString().padLeft(2, '0')}';
    return '${baseName}_$timeStr.xlsx';
  }

  /// Generate secure token
  static String generateSecureToken([int length = 32]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Calculate progress percentage
  static double calculateProgress(int current, int total) {
    if (total == 0) return 0.0;
    return (current / total).clamp(0.0, 1.0);
  }

  /// Format duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  /// Check if current time is within business hours
  static bool isBusinessHours([int startHour = 7, int endHour = 22]) {
    final now = DateTime.now();
    return now.hour >= startHour && now.hour < endHour;
  }

  /// Convert bytes to human readable format
  static String bytesToSize(int bytes) {
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    if (bytes == 0) return '0 B';
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Sanitize filename for cross-platform compatibility
  static String sanitizeFilename(String filename) {
    // Remove or replace invalid characters for file systems
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Generate color from string (consistent colors for same string)
  static int colorFromString(String text) {
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return 0xFF000000 + (hash & 0xFFFFFF);
  }

  /// Check if string is a valid JSON
  static bool isValidJson(String str) {
    try {
      jsonDecode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get device type string for analytics
  static String get deviceType {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  /// Format timestamp for display
  static String formatTimestamp(DateTime dateTime, {bool includeTime = true}) {
    if (includeTime) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatTimestamp(dateTime, includeTime: false);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Generate initials from name
  static String getInitials(String name, [int maxChars = 2]) {
    if (name.isEmpty) return '';

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0]
          .substring(0, min(maxChars, words[0].length))
          .toUpperCase();
    }

    String initials = '';
    for (int i = 0; i < min(words.length, maxChars); i++) {
      if (words[i].isNotEmpty) {
        initials += words[i][0].toUpperCase();
      }
    }

    return initials;
  }

  /// Capitalize first letter of each word
  static String titleCase(String text) {
    return text
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength, [String suffix = '...']) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  /// Remove Vietnamese accents
  static String removeVietnameseAccents(String text) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const english =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    String result = text.toLowerCase();
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], english[i]);
    }

    return result;
  }

  /// Convert string to slug (URL-friendly)
  static String createSlug(String text) {
    return removeVietnameseAccents(text)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Validate strong password
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasDigits = RegExp(r'\d').hasMatch(password);
    final hasSpecialChars = RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password);

    return hasUppercase && hasLowercase && hasDigits && hasSpecialChars;
  }

  /// Generate random password
  static String generateRandomPassword([int length = 12]) {
    const upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    const allChars = upperCase + lowerCase + numbers + specialChars;
    final random = Random.secure();

    // Ensure at least one character from each category
    String password = '';
    password += upperCase[random.nextInt(upperCase.length)];
    password += lowerCase[random.nextInt(lowerCase.length)];
    password += numbers[random.nextInt(numbers.length)];
    password += specialChars[random.nextInt(specialChars.length)];

    // Fill the rest randomly
    for (int i = 4; i < length; i++) {
      password += allChars[random.nextInt(allChars.length)];
    }

    // Shuffle the password
    final chars = password.split('')..shuffle(random);
    return chars.join();
  }

  /// Check if running on specific platform
  static bool isRunningOn(TargetPlatform platform) {
    return !kIsWeb && defaultTargetPlatform == platform;
  }

  /// Get appropriate file picker extensions for platform
  static List<String> getFilePickerExtensions(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'excel':
        return ['xlsx', 'xls'];
      case 'image':
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      case 'document':
        return ['pdf', 'doc', 'docx', 'txt'];
      case 'audio':
        return ['mp3', 'wav', 'aac', 'm4a'];
      case 'video':
        return ['mp4', 'avi', 'mov', 'wmv', 'flv'];
      default:
        return ['*'];
    }
  }

  /// Safe division to avoid divide by zero
  static double safeDivide(
    num numerator,
    num denominator, [
    double fallback = 0.0,
  ]) {
    if (denominator == 0) return fallback;
    return (numerator / denominator).toDouble();
  }

  /// Get week number of year
  static int getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final firstMonday = startOfYear.add(
      Duration(days: (8 - startOfYear.weekday) % 7),
    );

    if (date.isBefore(firstMonday)) {
      return 1;
    }

    return ((date.difference(firstMonday).inDays) / 7).floor() + 2;
  }

  /// Convert 24-hour time to 12-hour format
  static String to12HourFormat(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }
}

/// Extension methods for enhanced functionality
extension CrossPlatformStringExtension on String {
  String get initials => CrossPlatformService.getInitials(this);
  String get titleCase => CrossPlatformService.titleCase(this);
  String get removeAccents =>
      CrossPlatformService.removeVietnameseAccents(this);
  String get slug => CrossPlatformService.createSlug(this);
  bool get isValidEmail => CrossPlatformService.isValidEmail(this);
  bool get isValidPhone => CrossPlatformService.isValidPhoneNumber(this);
  bool get isStrongPassword => CrossPlatformService.isStrongPassword(this);
}

extension CrossPlatformDateTimeExtension on DateTime {
  bool get isToday => CrossPlatformService.isToday(this);
  bool get isThisWeek => CrossPlatformService.isThisWeek(this);
  String get relativeTime => CrossPlatformService.getRelativeTime(this);
  String get formatted => CrossPlatformService.formatTimestamp(this);
  int get weekOfYear => CrossPlatformService.getWeekOfYear(this);
}

extension CrossPlatformListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  List<T> get shuffled {
    final list = List<T>.from(this);
    list.shuffle();
    return list;
  }
}
