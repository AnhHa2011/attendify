// lib/features/student/presentation/notifications/notification_settings_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../notifications/local_notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _hourBeforeReminder = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _sessionOpenReminder = false;
  bool _leaveRequestUpdate = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    LocalNotificationService.requestPermissionsIfNeeded();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hourBeforeReminder = prefs.getBool('hour_before_reminder') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _sessionOpenReminder = prefs.getBool('session_open_reminder') ?? false;
      _leaveRequestUpdate = prefs.getBool('leave_request_update') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _testNotification() async {
    try {
      await LocalNotificationService.instance.showNow(
        title: 'Attendify - Thông báo thử',
        body: 'Thông báo hoạt động bình thường! 🎉',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi thông báo thử nghiệm'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi thông báo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await LocalNotificationService.requestPermissionsIfNeeded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã yêu cầu quyền thông báo'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xin quyền: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Cài đặt thông báo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông báo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tùy chỉnh các loại thông báo bạn muốn nhận',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reminder Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nhắc nhở lịch học',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SwitchListTile(
                  title: const Text('Nhắc trước 1 giờ'),
                  subtitle: const Text('Nhận thông báo trước giờ học 1 tiếng'),
                  value: _hourBeforeReminder,
                  onChanged: (value) {
                    setState(() => _hourBeforeReminder = value);
                    _saveSetting('hour_before_reminder', value);
                  },
                ),

                SwitchListTile(
                  title: const Text('Khi mở điểm danh'),
                  subtitle: const Text('Thông báo khi giảng viên mở điểm danh'),
                  value: _sessionOpenReminder,
                  onChanged: (value) {
                    setState(() => _sessionOpenReminder = value);
                    _saveSetting('session_open_reminder', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Leave Request Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Đơn xin nghỉ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SwitchListTile(
                  title: const Text('Cập nhật trạng thái'),
                  subtitle: const Text(
                    'Thông báo khi đơn xin nghỉ được duyệt/từ chối',
                  ),
                  value: _leaveRequestUpdate,
                  onChanged: (value) {
                    setState(() => _leaveRequestUpdate = value);
                    _saveSetting('leave_request_update', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sound & Vibration Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Âm thanh & Rung',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SwitchListTile(
                  title: const Text('Âm thanh'),
                  subtitle: const Text('Phát âm thanh khi có thông báo'),
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _saveSetting('sound_enabled', value);
                  },
                ),

                SwitchListTile(
                  title: const Text('Rung'),
                  subtitle: const Text('Rung thiết bị khi có thông báo'),
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() => _vibrationEnabled = value);
                    _saveSetting('vibration_enabled', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Test & Permissions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kiểm tra & Quyền',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _testNotification,
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Gửi thông báo thử'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.security),
                      label: const Text('Xin quyền thông báo'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Information Card
          Card(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Thông tin',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Để nhận thông báo đúng cách:\n'
                    '• Đảm bảo ứng dụng có quyền thông báo\n'
                    '• Mở ứng dụng ít nhất 1 lần mỗi ngày\n'
                    '• Không tắt thông báo trong cài đặt hệ thống\n'
                    '• Với Android 13+, cần cấp quyền thông báo riêng',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
